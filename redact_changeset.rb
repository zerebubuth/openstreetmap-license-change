require './osm'
require './osm_parse'
require './osm_print'
require './changeset'
require './user'
require './db'
require './change_bot'
require 'net/http'
require 'nokogiri'
require 'set'
require 'oauth'
require 'yaml'
require 'optparse'

MAX_CHANGESET_ELEMENTS = 1000

class Server
  def initialize(file)
    auth = YAML.load(File.open(file))
    oauth = auth['oauth']
    @server = oauth['site']
    @consumer=OAuth::Consumer.new(oauth['consumer_key'],
                                  oauth['consumer_secret'],
                                  {:site=>oauth['site']})

    @consumer.http.read_timeout = 320

    # Create the access_token for all traffic
    @access_token = OAuth::AccessToken.new(@consumer, oauth['token'], oauth['token_secret'])
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

  def create_changeset(comment)
    changeset_request = <<EOF
<osm>
  <changeset>
    <tag k="created_by" v="Redaction bot"/>
    <tag k="bot" v="yes"/>
    <tag k="comment" v="#{comment}"/>
  </changeset>
</osm>
EOF
    response = @access_token.put('/api/0.6/changeset/create', changeset_request, {'Content-Type' => 'text/xml' })
    unless response.code == '200'
      raise "Failed to open changeset"
    end
    
    changeset_id = response.body.to_i

    return changeset_id
  end

  def upload(change_doc, changeset_id)
    response = @access_token.post("/api/0.6/changeset/#{changeset_id}/upload", change_doc, {'Content-Type' => 'text/xml' })
    unless response.code == '200'
      # It's quite likely for a changeset to fail, if someone else is editing in the area being processed
      raise "Changeset failed to apply"
    end
  end

  def redact(klass, elt_id, version, red_id)
    name = case klass.name
           when "OSM::Node" then 'node'
           when "OSM::Way" then 'way'
           when "OSM::Relation" then 'relation'
           end
    
    response = @access_token.post("/api/0.6/#{name}/#{elt_id}/#{version}/redact?redaction=#{red_id}")
    unless response.code == '200'
      raise "Failed to redact element"
    end
  end

  private
  def api_call_get(path)
    uri = URI("#{@server}/api/0.6/#{path}")
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

def process_redactions(bot, server, redaction_id)
  bot.redactions.each do |redaction|
    server.redact(redaction.klass, redaction.element_id, redaction.version, redaction_id)
  end
end

def process_changeset(changesets, db, server, comment)
  change_doc = ""
  cs_id = server.create_changeset(comment)
  OSM::print_osmchange(changesets, db, change_doc, cs_id)
  server.upload(change_doc, cs_id)
end

options = { :config => 'auth.yaml' }
oparser = OptionParser.new do |opts|
  opts.on("-c", "--config CONFIG", "YAML config file to use.") do |c|
    options[:config] = c
  end

  opts.on("-r", "--redaction ID", Integer, "Redaction ID to use.") do |r|
    options[:redaction_id] = r
  end

  opts.on("-m", "--message MESSAGE", "Commit message to use.") do |m|
    options[:comment] = m
  end
end
oparser.parse!

server = Server.new(options[:config])
if options.has_key? :comment
  comment = options[:comment]
else
  puts "You must give a comment for the changeset."
  puts
  puts oparser
  exit(1)
end
if options.has_key? :redaction_id
  redaction_id = options[:redaction_id]
else
  puts "You must give a redaction ID to use."
  puts
  puts oparser
  exit(1)
end

elements = Hash[[OSM::Node, OSM::Way, OSM::Relation].map {|k| [k, Hash.new]}]

input_changesets = ARGV.map {|x| x.to_i}

input_changesets.each do |arg|
  cs_id = arg.to_i
  next if cs_id <= 0
  
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
end

cs_ids = Set.new
elements.each do |klass, elts|
  elts.each do |id, vers|
    vers.each do |elt|
      #puts elt.inspect
      cs_ids.add(elt.changeset_id)
    end
  end
end

changesets = Hash.new
cs_ids.each do |id| 
  ok = !(input_changesets.include?(id))
  changesets[id] = Changeset[User[ok]]
end

db = DB.new(:changesets => changesets, :nodes => elements[OSM::Node], :ways => elements[OSM::Way], :relations => elements[OSM::Relation])
bot = ChangeBot.new(db)

puts('Processing all nodes')
bot.process_nodes!
puts('Processing all ways')
bot.process_ways!
puts('Processing all relations')
bot.process_relations!

changeset = bot.as_changeset

if changeset.empty?
  puts "No changeset to apply"
  process_redactions(bot, server, redaction_id)

else
  begin
    changeset.each_slice(MAX_CHANGESET_ELEMENTS) do |slice|
      process_changeset(slice, db, server, comment)
    end

  rescue Exception => e
    puts "Failed to upload a changeset: #{e}"

  else
    process_redactions(bot, server, redaction_id)
  end
end

