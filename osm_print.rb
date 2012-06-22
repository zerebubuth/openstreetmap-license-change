require './osm'
require './actions'

USERNAME = "Redaction bot"
UID = 0
TIMESTAMP = "2012-04-01T00:00:00Z"

def compare(a, b)
  aklass, bklass = nil, nil
  aid, bid = 0, 0
  
  if a.class == Delete then
    aklass = a.klass
    aid = a.element_id
  else
    aklass = a.obj.class
    aid = a.obj.element_id
  end
  if b.class == Delete then
    bklass = b.klass
    bid = b.element_id
  else
    bklass = b.obj.class
    bid = b.obj.element_id
  end
  
  ai = if aklass == OSM::Node then 0 elsif aklass == OSM::Way then 1 else 2 end
  bi = if bklass == OSM::Node then 0 elsif bklass == OSM::Way then 1 else 2 end
  return ai <=> bi if ai != bi
  
  aid <=> bid
end

module OSM
  def self.print_osmchange(changeset, db, out = $stdout, changeset_id = -1)
    changeset.sort! {|a, b| compare(a, b)}
  
    out << '<osmChange version="0.6" generator="Redaction bot">' << "\n"
    changeset.each do |o|
      if o.class == Edit then
        out << '  <modify>' << "\n"
        self.print(o.obj, out, 2, changeset_id)
        out << '  </modify>' << "\n"
      elsif o.class == Delete then
        out << '  <delete>' << "\n"
        self.print(self.from_delete(o, db, changeset_id), out, 2, changeset_id)
        out << '  </delete>' << "\n"
      end
    end
    
    out << '</osmChange>' << "\n"
  end
  
  def self.from_delete(delete, db, changeset_id)
    t =  if delete.klass == OSM::Node then db.current_node(delete.element_id)
      elsif delete.klass == OSM::Way then db.current_way(delete.element_id)
      elsif delete.klass == OSM::Relation then db.current_relation(delete.element_id)
      end
    
    geom = delete.klass == OSM::Node ? t.geom : []
    delete.klass.new({:id => delete.element_id, :changeset => changeset_id, :visible => false, :version => t.version},geom,[])
  end
  
  def self.print(obj, out = $stdout, indent = 0, changeset_id = -1)
    attributes = {
      :id => obj.element_id,
      :changeset => changeset_id,
      :user => USERNAME,
      :uid => UID,
      :visible => obj.visible,
      :timestamp => TIMESTAMP,
      :version => obj.version,
      }
    tags = obj.tags
    child_name = nil
    children = []
    
    if obj.class == OSM::Node
      name = "node"
      attributes[:lat] = obj.position.size == 2 ? obj.position[0].to_f : 0
      attributes[:lon] = obj.position.size == 2 ? obj.position[1].to_f : 0
    elsif obj.class == OSM::Way
      name = "way"
      child_name = "nd"
      children = obj.nodes.map {|id| {:ref => id}}
    elsif obj.class == OSM::Relation
      name = "relation"
      child_name = "member"
      children = obj.members.map {|member| {
        :type => (if member.type == OSM::Node then "node" 
               elsif member.type == OSM::Way then "way"
               else "relation" end),
        :ref => member.ref,
        :role => member.role}}
    end
    
    out << '  '*indent << '<' << name
    attributes.each {|k, v| out << " #{k}=\"#{v}\""}
    
    if tags.empty? and children.empty? then
      out << "/>\n"
      return
    end
    out << ">\n"
    
    if not tags.empty?
      tags.each do |k, v|
        out << '  '*(indent+1) << "<tag k=\"#{k}\" v=\"#{v}\"/>\n"
      end
    end
    
    if not children.empty?
      children.each do |attribs|
       out << '  '*(indent+1) << '<' << child_name
       attribs.each {|k, v| out << " #{k}=\"#{v}\""}
       out << "/>\n"
      end
    end
    
    out << '  '*indent << '</' << name << ">\n"
  end
end

