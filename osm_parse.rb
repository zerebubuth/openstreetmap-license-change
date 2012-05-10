require './osm'
require 'xml/libxml'

module OSM
  ATTRIBUTES = { 
    :id => ["id", :to_i],
    :changeset => ["changeset", :to_i],
    :timestamp => ["timestamp", :to_s],
    :visible => ["visible", Proc.new {|a| a == "true"}],
    :version => ["version", :to_i]
  }

  def self.parse(xml)
    doc = XML::Parser.string(xml).parse
    doc.root.children.select {|e| e.element? }.map do |xml_elem|
      tags = Hash[xml_elem.children.
                  select {|ch| ch.element? && ch.name == "tag"}.
                  map {|ch| [ch["k"].to_s, ch["v".to_s]]}]
      
      attrs = Hash[ATTRIBUTES.collect do |k,v| 
                     elt = xml_elem[v[0]]
                     val = (v[1].class == Symbol) ? elt.send(v[1]) : v[1].call(elt)
                     [k, val]
                   end]
      
      case xml_elem.name
      when "node"
        OSM::Node[[xml_elem["lon"].to_f, xml_elem["lat"].to_f],
                  attrs.merge(tags)]
        
      when "way"
        nds = xml_elem.children.
          select {|ch| ch.element? && ch.name == "nd"}.
          map {|ch| ch["ref"].to_i}
        
        OSM::Way[nds, attrs.merge(tags)]
        
      when "relation"
        raise "Unimplemented, yet."

      else
        raise "Element type #{xml_elem.name.inspect} not expected! Was expecting one of 'node', 'way' or 'relation'."
      end
    end
  end

  def self.user_id_from_changeset(xml)
    doc = XML::Parser.string(xml).parse
    cs = doc.root.children.select {|e| e.element? }.first
    uid = cs["uid"]
    uid.nil? ? 0 : uid.to_i
  end
end
