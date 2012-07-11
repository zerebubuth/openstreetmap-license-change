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

  WAYS_FOR_NODE_ID_SQL = \
    'SELECT way_id FROM current_way_nodes WHERE node_id = %{id}'

  RELATIONS_FOR_MEMBER_SQL = \
      "SELECT relation_id
        FROM current_relation_members
        WHERE member_id = %{id} AND member_type = '%{type}'"

  def initialize(dbconn)
    @dbconn = dbconn

    # A lookup table of changesets with the agreement status
    # e.g. @changesets[1234] = true
    @changesets = Hash.new

    # A hash of entity arrays - entities to work through
    # e.g. @entities = {node: [1,2,3], way: [2,3,4], relation: [445, 543]}
    @entities = Hash.new

    # An array of blacklisted changesets
    @changeset_blacklist = File.open("changesets_blacklist.txt").map{ |l| l.to_i }.to_set

    # An array of whitelisted changesets
    @changeset_whitelist = File.open("changesets_whitelist.txt").map{ |l| l.to_i }.to_set

    # An array of whitelisted users
    @user_whitelist = File.open("users_whitelist.txt").map{ |l| l.to_i }.to_set

    # An array of blacklisted edits
    @edit_blacklist = File.open("edits_blacklist.txt").read.split("\n").to_set

    # An array of whitelisted edits
    @edit_whitelist = File.open("edits_whitelist.txt").read.split("\n").to_set
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
      {|r| [klass_for_member_type(r['member_type']), r['member_id'].to_i, (r['member_role'] or '')]}
    get_history('relation', id, current) do |r, attribs|
      geom = geoms.fetch(attribs[:version], [])
      OSM::Relation[geom, attribs]
    end
  end
  
  def changeset(id)
    if not @changesets.has_key?(id)
      if @changeset_whitelist.include?(id)
        @changesets[id] = true
      elsif @changeset_blacklist.include?(id)
        @changesets[id] = false
      else
        res = @dbconn.query(CHANGESET_SQL, [id])
        if @user_whitelist.include?(res[0]['user'].to_i)
          @changesets[id] = true
        else
          @changesets[id] = (not res[0]['agreed'].nil?)
        end
      end
    end
    Changeset[User[@changesets[id]]]
  end
  
  def exclude?(klass, i)
    # TODO
    false
  end
  
  def objects_using(klass, elt_id)
    references = Array.new

    if klass == OSM::Node
      res = @dbconn.query(WAYS_FOR_NODE_ID_SQL % {:id => elt_id})
      res.each do |r|
        way = way(r['way_id'], true)[0]
        references << way unless way.visible == false # safeguard against stray way_nodes for deleted ways.
      end
    end

    member_type = if klass == OSM::Node
                    'Node'
                  elsif klass == OSM::Way
                    'Way'
                  elsif klass == OSM::Relation
                    'Relation'
                  end

    res = @dbconn.query(RELATIONS_FOR_MEMBER_SQL % {:id => elt_id, :type => member_type})
    res.each do |r|
      relation = relation(r['relation_id'], true)[0]
      references << relation unless relation.visible == false # safeguard, see above
    end
    references
  end
  
  ['node', 'way', 'relation'].each do |type|
    define_method("each_#{type}") do |&block|
      #res = @dbconn.query(EACH_SQL % {:type => type})
      #res.map {|r| r['id'].to_i}.each &block
      @entities[type.to_sym].each &block
    end
    define_method("current_#{type}") do |id|
      return send(type.to_sym, id, true)[0]
    end
  end

  def set_entities(obj)
    @entities = obj
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

  def klass_for_member_type(s)
    klass = case s
            when "Node" then OSM::Node
            when "Way" then OSM::Way
            when "Relation" then OSM::Relation
            end
  end
end
