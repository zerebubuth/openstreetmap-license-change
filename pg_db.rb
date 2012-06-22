require './user'
require './changeset'
require './osm'

class PG_DB
  WAY_GEOM_SQL = \
    'SELECT way_id AS id, version, sequence_id, node_id 
     FROM way_nodes 
     WHERE way_id = %{id};'
  RELATION_GEOM_SQL = \
    'SELECT relation_id AS id, version, sequence_id, member_type, member_id, member_role 
     FROM relation_members 
     WHERE relation_id = %{id};'

  CHANGESET_SQL = \
    'SELECT changesets.id AS id, users.id AS user, users.terms_agreed AS agreed 
     FROM changesets 
     INNER JOIN users ON changesets.user_id = users.id 
     WHERE changesets.id = $1::int;'

  EACH_SQL = \
    'SELECT %{type}s.%{type}_id AS id 
     FROM %{type}s 
     INNER JOIN changesets ON %{type}s.changeset_id = changesets.id 
     INNER JOIN users ON changesets.user_id = users.id 
     WHERE users.terms_agreed is NULL 
     GROUP BY %{type}s.%{type}_id;'
  TAGS_SQL = \
    'SELECT %{type}_id AS id, version, k, v 
     FROM %{type}_tags
     WHERE %{type}_id = %{id};'
  HISTORY_SQL = \
    'SELECT %{type}s.%{type}_id AS id, %{type}s.version AS version, changeset_id, visible %{fields}
     FROM %{type}s 
     WHERE %{type}s.%{type}_id = %{id}'
  HISTORY_CURRENT_SQL = \
    'SELECT %{type}s.%{type}_id AS id, %{type}s.version AS version, changeset_id, visible %{fields}
     FROM %{type}s 
     WHERE %{type}s.%{type}_id = %{id}
     ORDER BY %{type}s.version DESC
     LIMIT 1;'

  def initialize(dbconn)
    @dbconn = dbconn
    @changesets = Hash.new
  end
  
  def node(id, current = false)
    get_history('node', id, current, ['longitude', 'latitude']) do |r, attribs|
      OSM::Node[[r['longitude'].to_r/10000000, r['latitude'].to_r/10000000], attribs]
    end
  end
  
  def way(id, current = false)
    geoms = get_geom(WAY_GEOM_SQL % {:id => id}) {|r| r['node_id'].to_i}
  
    get_history('way', id, current) do |r, attribs|
      geom = geoms.fetch(attribs[:version], [])
      OSM::Way[geom, attribs]
    end
  end
  
  def relation(id, current = false)
    geoms = get_geom(RELATION_GEOM_SQL % {:id => id}) \
      {|r| [r['member_type'], r['member_id'].to_i, (r['member_role'] or '')]}
    get_history('relation', id, current) do |r, attribs|
      geom = geoms.fetch(attribs[:version], [])
      OSM::Relation[geom, attribs]
    end
  end
  
  def changeset(id)
    @changesets[id] = (not @dbconn.query(CHANGESET_SQL, [id])[0]['agreed'].nil?) if not @changesets.has_key?(id)
    Changeset[User[@changesets[id]]]
  end
  
  def exclude?(klass, i)
    # TODO
    false
  end
  
  def objects_using(klass, elt_id)
    # TODO
    []
  end
  
  ['node', 'way', 'relation'].each do |type|
    define_method("each_#{type}") do |&block|
      res = @dbconn.query(EACH_SQL % {:type => type})
      res.map {|r| r['id'].to_i}.each &block
    end
    define_method("current_#{type}") do |id|
      return send(type.to_sym, id, true)[0]
    end
  end
  
  private
  
  def get_tags(type, id)
    tags = Array.new
    
    res = @dbconn.query(TAGS_SQL % {:type => type, :id => id})
    res.each do |r|
      version = r['version'].to_i
      tags[version] = Hash.new if tags[version].nil?
      tags[version][r['k']] = r['v']
    end
    
    tags.map {|t| t or {}}
  end
  
  def get_attr(r)
    {:id => r['id'].to_i, :changeset => r['changeset_id'].to_i, :version => r['version'].to_i, :visible => (r['visible'] == "t" ? true : false)}
  end
  
  def get_geom(sql)
    geom = Array.new
    
    res = @dbconn.query(sql)
    res.each do |r|
      version = r['version'].to_i
      geom[version] = Array.new if geom[version].nil?
      geom[version][r['sequence_id'].to_i() -1] = yield(r)
    end
    
    geom.map {|t| t or []}
  end
  
  def get_history(type, id, current = false, extra_fields = [])
    tags = get_tags(type, id)
    fields = extra_fields.map {|name| ", " + name}.join
  
    res = @dbconn.query((current ? HISTORY_CURRENT_SQL : HISTORY_SQL) % {:id => id, :type => type, :fields => fields})
    res.map do |r|
      ver = r['version'].to_i
      tag = tags.fetch(ver, {})
      yield r, get_attr(r).merge(tag)
    end
  end
end
