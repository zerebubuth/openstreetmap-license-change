require './osm'
require './osm_parse'
require './changeset'
require './user'
require './db'
require 'net/http'
require 'nokogiri'
require 'set'

class Server
  def initialize(server)
    @server = server
  end

  def history(elt)
    name = element_name(elt)
    response = api_call_get("#{name}/#{elt.element_id}/history")
    OSM.parse(response.body)
  end

  def changeset_contents(id)
    response = api_call_get("changeset/#{id}/download")
    parse_diff(response.body)
  end
  
  def dependents(elt)
    osm = []
    name = element_name(elt)
    if name == "node"
      osm += OSM.parse(api_call_get("node/#{elt.element_id}/ways").body)
    end
    osm += OSM.parse(api_call_get("#{name}/#{elt.element_id}/relations").body)
    return osm
  end

  private
  def api_call_get(path)
    uri = URI("http://#{@server}/api/0.6/#{path}")
    puts "GET: #{uri}"
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 320

    response = http.request_get(uri.request_uri)
    raise "FAIL: #{uri} => #{response.code}" unless response.code == '200'

    return response
  end

  def element_name(elt)
    case elt
    when OSM::Node then "node"
    when OSM::Way then "way"
    when OSM::Relation then "relation"
    end
  end

  def parse_diff(s)
    doc = Nokogiri::XML(s)
    nodes     = Set[*(doc.xpath("//node")    .map {|x| x["id"].to_i})]
    ways      = Set[*(doc.xpath("//way")     .map {|x| x["id"].to_i})]
    relations = Set[*(doc.xpath("//relation").map {|x| x["id"].to_i})]
    nodes.map {|i| OSM::Node[[0,0], :id => i]} +
      ways.map {|i| OSM::Way[[], :id => i]} +
      relations.map {|i| OSM::Relation[[], :id => i]}
  end
end

server = Server.new("api.openstreetmap.org")
cs_id = ARGV[0].to_i
raise "Nope" if cs_id <= 0

elements = Hash[[OSM::Node, OSM::Way, OSM::Relation].map {|k| [k, Hash.new]}]

server.changeset_contents(cs_id).each do |elt|
  h = server.history(elt)
  dependents = server.dependents(h.last)
  elements[h.last.class][h.last.element_id] = h
  #puts "dependents = #{dependents.inspect}"
  dependents.each do |u|
    #puts "u = #{u.inspect}"
    unless elements[u.class].has_key? u.element_id
      elements[u.class][u.element_id] = [u]
    end
  end
end

cs_ids = Set.new
elements.each do |klass, elts|
  elts.each do |id, vers|
    vers.each do |elt|
      puts elt.inspect
      cs_ids.add(elt.changeset_id)
    end
  end
end

changesets = Hash[cs_ids.map {|id| [id, Changeset[User[id != cs_id]]]}] 

db = DB.new(:changesets => changesets, :nodes => elements[OSM::Node], :ways => elements[OSM::Way], :relations => elements[OSM::Relation])
puts elements.inspect
