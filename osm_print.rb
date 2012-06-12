require './osm'
require './actions'

USERNAME = "Redaction bot"
UID = 0
TIMESTAMP = "2012-04-01T00:00:00Z"

module OSM
  def self.print_osmchange(changeset, db, out = $stdout)
    changes = changeset.group_by {|obj| obj.class}
    edits = (changes.has_key? Edit) ? changes[Edit] : []
    deletes = (changes.has_key? Delete) ? changes[Delete] : []
  
    out << '<osmChange version="0.6" generator="Redaction bot">' << "\n"
    if not edits.empty? then
      out << '  <modify' << "\n"
      edits.each {|edit| self.print(edit.obj, out, 2)}
      out << '  </modify>' << "\n"
    end
    
    if not deletes.empty? then
      out << '  <delete>' << "\n"
      deletes.each {|delete| self.print(self.from_delete(delete, db), out, 2)}
      out << '  </delete>' << "\n"
    end
    
    out << '</osmChange>' << "\n"
  end
  
  def self.from_delete(delete, db)
    t =  if delete.klass == OSM::Node then db.nodes
      elsif delete.klass == OSM::Way then db.ways
      elsif delete.klass == OSM::Relation then db.relations
      end
      
    version = t[delete.element_id].map {|obj| obj.version}.max
    delete.klass.new({:id => delete.element_id, :changeset => -1, :visible => false, :version => version},[],[])
  end
  
  def self.print(obj, out = $stdout, indent = 0)
    attributes = {
      :id => obj.element_id,
      :changeset => obj.changeset_id,
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
      attributes[:lat] = obj.position[0]
      attributes[:lon] = obj.position[1]
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

