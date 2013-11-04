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
require 'typhoeus'

MAX_CHANGESET_ELEMENTS = 1000

class Server
  def initialize(file, dry_run)
    auth = YAML.load(File.open(file))
    oauth = auth['oauth']
    @server = oauth['site']
    @dry_run = dry_run

    unless @dry_run
      @consumer=OAuth::Consumer.new(oauth['consumer_key'],
                                    oauth['consumer_secret'],
                                    {:site=>oauth['site']})
      
      @consumer.http.read_timeout = 320
      
      # Create the access_token for all traffic
      @access_token = OAuth::AccessToken.new(@consumer, oauth['token'], oauth['token_secret'])
    end

    @max_retries = 3
  end

  def history(elt)
    name = element_name(elt)
    "#{@server}/api/0.6/#{name}/#{elt.element_id}/history"
  end

  def element(name, id)
    "#{@server}/api/0.6/#{name}/#{id}"
  end

  def changeset_contents(id)
    response = api_call_get("changeset/#{id}/download")
    parse_diff(response.body)
  end
  
  def dependents(elt)
    requests = []
    name = element_name(elt)
    if name == "node" 
      requests << "#{@server}/api/0.6/node/#{elt.element_id}/ways"
    end
    requests << "#{@server}/api/0.6/#{name}/#{elt.element_id}/relations"
    return requests
  end

  def create_changeset(comment, input_changesets)
    changeset_request = <<EOF
<osm>
  <changeset>
    <tag k="created_by" v="Redaction bot"/>
    <tag k="bot" v="yes"/>
    <tag k="comment" v="#{comment}"/>
    <tag k="redacted_changesets" v="#{input_changesets.join(",")}"/>
  </changeset>
</osm>
EOF
    tries = 0
    response = nil
    if @dry_run
      puts "Pretending to create changeset:\n#{changeset_request}"
      return 1

    else
      loop do
        response = @access_token.put('/api/0.6/changeset/create', changeset_request, {'Content-Type' => 'text/xml' })
        break if response.code == '200'
        tries += 1
        if tries >= @max_retries
          raise "Failed to open changeset. Most recent response code: #{response.code}:\n#{response.body}"
        end
      end
      
      changeset_id = response.body.to_i
      
      return changeset_id
    end
  end

  def upload(change_doc, changeset_id)
    if @dry_run
      puts "Pretending to upload changeset:\n#{change_doc}"

    else
      tries = 0
      loop do
        response = @access_token.post("/api/0.6/changeset/#{changeset_id}/upload", change_doc, {'Content-Type' => 'text/xml' })
        break if response.code == '200'
        tries += 1
        if tries >= @max_retries
          # It's quite likely for a changeset to fail, if someone else is editing in the area being processed
          raise "Changeset failed to apply. Most recent response code: #{response.code}:\n#{response.body}"
        end
      end
    end
  end

  def redact(klass, elt_id, version, red_id)
    name = case klass.name
           when "OSM::Node" then 'node'
           when "OSM::Way" then 'way'
           when "OSM::Relation" then 'relation'
           end
    
    if @dry_run
      puts "Pretending to redact #{name}/#{elt_id}/#{version} with redaction id=#{red_id}"

    else
      tries = 0
      loop do
        response = @access_token.post("/api/0.6/#{name}/#{elt_id}/#{version}/redact?redaction=#{red_id}")
        break if response.code == '200'
        tries += 1
        if tries >= @max_retries
          raise "Failed to redact element. Most recent response code: #{response.code} (#{response.body})"
        end
      end
    end
  end

  private
  def api_call_get(path)
    tries = 0
    loop do
      begin
        uri = URI("#{@server}/api/0.6/#{path}")
        puts "GET: #{uri}"
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 320
        
        response = http.request_get(uri.request_uri)
        raise "FAIL: #{uri} => #{response.code}:\n#{response.body}" unless response.code == '200'
        
        return response
      rescue Exception => ex
        if tries > @max_retries
          raise
        else
          puts "Got exception: #{ex}, retrying."
        end
      end
      
      tries += 1
    end
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

class ServerDB < DB
  def initialize(server, options)
    super(options)
    @server = server

    [:nodes, :ways, :relations].each do |opt|
      non_plural_name = opt[0..-2]
      instance_name = "@#{opt}"

      metaclass.send(:define_method, 'current_' + non_plural_name) do |elt_id|
        if self.instance_variable_get(instance_name)[elt_id].nil?
          get_obj(@server.element(non_plural_name, elt_id)).last
        else
          self.instance_variable_get(instance_name)[elt_id].last
        end
      end
    end
  end

  def objects_using(klass, elt_id)
    elt = if klass == OSM::Node
            klass[[0,0], :id => elt_id]
          elsif klass == OSM::Way
            klass[[], :id => elt_id]
          else
            klass[[], :id => elt_id]
          end
    dep_urls = @server.dependents(elt)
    dep_urls.collect_concat do |url| 
      get_obj(url)
    end
  end

  private
  def get_obj(url)
    tries = 0
    obj = nil
    while obj.nil?
      puts "DEP GET: #{url}"
      response = Typhoeus::Request.get(url, :timeout => 300000)
      # TODO: handle 410 here?
      if response.success?
        obj = OSM.parse(response.body)
      end
      tries += 1
      if obj.nil? and tries >= 3
        raise "Failed to get object dependency from #{url}: #{response.body}"
      end
    end
    obj
  end
end

def process_redactions(bot, server, redaction_id)
  bot.redactions.each do |redaction|
    server.redact(redaction.klass, redaction.element_id, redaction.version, redaction_id)
  end
end

def process_changeset(changesets, db, server, comment, input_changesets)
  change_doc = ""
  cs_id = server.create_changeset(comment, input_changesets)
  OSM::print_osmchange(changesets, db, change_doc, cs_id)
  server.upload(change_doc, cs_id)
end

def parse_osc_file(file)
  changesets = Set.new
  elements = nil

  File.open(file, "r") do |fh|
    doc = Nokogiri::XML(fh)
    nodes     = Set[*(doc.xpath("//node")    .map {|x| changesets.add(x["changeset"].to_i); x["id"].to_i})]
    ways      = Set[*(doc.xpath("//way")     .map {|x| changesets.add(x["changeset"].to_i); x["id"].to_i})]
    relations = Set[*(doc.xpath("//relation").map {|x| changesets.add(x["changeset"].to_i); x["id"].to_i})]
    elements = nodes.map {|i| OSM::Node[[0,0], :id => i]} +
      ways.map {|i| OSM::Way[[], :id => i]} +
      relations.map {|i| OSM::Relation[[], :id => i]}
  end

  if changesets.size != 1
    raise "Was expecting one file = one changeset, but didn't get a single changeset ID."
  end

  return [changesets.first, elements]
end

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
  
  ai = if aklass == OSM::Node then 2 elsif aklass == OSM::Way then 1 else 0 end
  bi = if bklass == OSM::Node then 2 elsif bklass == OSM::Way then 1 else 0 end
  return ai <=> bi if ai != bi
  
  aid <=> bid
end

options = { :config => 'auth.yaml', :threads => 4, :dry_run => false }
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

  opts.on("-t", "--threads N", Integer, "Number of threads to use getting data from the API.") do |t|
    options[:threads] = t
  end

  opts.on("-n", "--dry_run", "Don't perform actions, instead log them to disk.") do |n|
    options[:dry_run] = true
  end

  opts.on("-e", "--edits_blacklist FILE", "edits blacklist file to redact") do |e|
    options[:edits_blacklist] = e
  end
end
oparser.parse!

server = Server.new(options[:config], options[:dry_run])
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
input_changesets = []

hydra = Typhoeus::Hydra.new(:max_concurrency => options[:threads])
hydra.disable_memoization

to_redact = []
ARGV.each do |arg|
  # if the argument is a file on disk, then use that. otherwise, go to 
  # the API and fetch it from there.
  contents = nil
  cs_id = nil

  if File.exists?(arg)
    cs_id, contents = parse_osc_file(arg)

  else
    cs_id = arg.to_i
    if cs_id > 0
      contents = server.changeset_contents(cs_id)
    end
  end

  if contents.nil? or cs_id.nil?
    puts "Didn't understand argument #{arg.inspect} as a changeset ID or file to load from disk."
    next
  end

  input_changesets << cs_id

  to_redact += contents
end

if options.has_key? :edits_blacklist then
  to_redact += File.open(options[:edits_blacklist], "r").read.split("\n").map do |line|
    type = line[0]
    t = line[1..-1].split('v')
    id = t[0].to_i
    version = t[1].to_i
    case type
      when "n" then OSM::Node[[0,0], :id => id]
      when "w" then OSM::Way[[], :id => id]
      when "r" then OSM::Relation[[], :id => id]
    end
  end
end
  
puts "Threads: #{options[:threads].inspect} (changesets = #{input_changesets})"
#puts to_redact.inspect

requests = to_redact.map do |elt|
  urls = [server.history(elt)]
  #urls += server.dependents(elt)

  urls.map do |url| 
    #puts "REQ: #{url.inspect}"
    req = Typhoeus::Request.new(url)
    hydra.queue(req)
    req
  end
end

loop do
  hydra.disable_memoization
  hydra.run
  hydra.disable_memoization

  failed_requests = 0
  requests.map! do |rqs|
    rqs.map do |rq|
      if rq.response.success?
        rq
      else
        #puts "Retrying #{rq.url.inspect}"
        new_rq = Typhoeus::Request.new(rq.url)
        hydra.queue(new_rq)
        failed_requests += 1
        new_rq
      end
    end
  end

  break if failed_requests == 0
  puts "Retrying #{failed_requests} failed requests."
end

results = []
requests.each do |rqs|
  h_rq, *dep_rq = rqs
  h = OSM.parse(h_rq.response.body)
  dependents = dep_rq.collect_concat {|rq| OSM.parse(rq.response.body)}
  results << [h, dependents]
end

results.each do |h, dependents|
  elements[h.last.class][h.last.element_id] = h
  dependents.each do |u|
    unless elements[u.class].has_key? u.element_id
      elements[u.class][u.element_id] = [u]
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

db = ServerDB.new(server, {:changesets => changesets, :nodes => elements[OSM::Node], :ways => elements[OSM::Way], :relations => elements[OSM::Relation]})
db.edit_blacklist = File.open(options[:edits_blacklist], "r").read.split("\n").to_set if options.has_key? :edits_blacklist
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
    changeset.sort! {|a, b| compare(a, b)}
    changeset.each_slice(MAX_CHANGESET_ELEMENTS) do |slice|
      puts "Uploading #{slice.size} elements of #{changeset.size} total"
      process_changeset(slice, db, server, comment, input_changesets)
    end

  rescue Exception => e
    puts "Failed to upload a changeset: #{e}\n#{e.backtrace}"

  else
    process_redactions(bot, server, redaction_id)
  end
end

