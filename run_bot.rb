#!/usr/bin/env ruby
# Runs the redaction bot on a live database.

require './pg_db'
require './change_bot'
require './osm_print'

require 'pg'
require 'getoptlong'
require 'oauth'
require 'yaml'
require 'xml/libxml'

def usage
  puts <<-EOF
usage: run_bot.rb [OPTIONS...]

Run the redaction bot on a standard rails port database.

-h, --help:
   Show help

-v --verbose:
   Output information about the actions being taken.

-r --redaction
   Use the given redaction id

-n --no-action
   Send all the commands to the database, but do not commit them.
EOF
end

opts = GetoptLong.new(['--help', '-h', GetoptLong::NO_ARGUMENT ],
                      ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
                      ['--redaction', '-r', GetoptLong::REQUIRED_ARGUMENT ],
                      ['--no-action', '-n', GetoptLong::NO_ARGUMENT],
                     )

@start_time = nil

def print_time(name = nil)
  now_time = Time.now
  print "(#{now_time - @start_time} s)\n" if @verbose and not @start_time.nil?
  @start_time = now_time
  
  print "#{name}..." if @verbose and not name.nil?
end

def get_next_region()
  # for now just grab next region from list
  # TODO don't grab regions adjacent to in-progress regions
  # TODO ensure transaction so that parrallel instances don't both grab same region
  res = @tracker_conn.exec("select id, lat, lon from regions where status = 'unprocessed' order by id limit 1")
  if res.num_tuples == 0
    false
  else
    region = {id: res[0]['id'], lat: res[0]['lat'].to_f, lon: res[0]['lon'].to_f}
    @tracker_conn.exec("update regions set status = 'processing' where id = $1", [region[:id]]) unless @no_action
    region
  end
end

def mark_region_complete(region)
  # don't mark it as complete if it was marked as failed already
  @tracker_conn.exec("update regions set status = 'complete' where id = $1 and status != 'failed'", [region[:id]]) unless @no_action
end

def mark_region_failed(region)
  puts "region failed"
  @tracker_conn.exec("update regions set status = 'failed' where id = $1", [region[:id]]) unless @no_action
end

def mark_entities_succeeded(nodes, ways, relations)
  @tracker_conn.exec("update candidates set status = 'complete' where type = 'node' and id in ($1)", [nodes.join(",")]) unless @no_action
  @tracker_conn.exec("update candidates set status = 'complete' where type = 'way' and id in ($1)", [ways.join(",")]) unless @no_action
  @tracker_conn.exec("update candidates set status = 'complete' where type = 'relation' and id in ($1)", [relations.join(",")]) unless @no_action
end

def mark_entities_failed(nodes, ways, relations)
  @tracker_conn.exec("update candidates set status = 'failed' where type = 'node' and id in ($1)", [nodes.join(",")]) unless @no_action
  @tracker_conn.exec("update candidates set status = 'failed' where type = 'way' and id in ($1)", [ways.join(",")]) unless @no_action
  @tracker_conn.exec("update candidates set status = 'failed' where type = 'relation' and id in ($1)", [relations.join(",")]) unless @no_action
end

def size_of_area(a)
  (a[:maxlat] - a[:minlat]) * (a[:maxlon] - a[:minlon])
end

# split an area into two areas, and add them to the list
# divide along the longest edge
def split_area(a, list)
  a1 = a.clone
  a2 = a.clone
  lat_range = a[:maxlat] - a[:minlat]
  lon_range = a[:maxlon] - a[:minlon]
  if lat_range > lon_range
    a1[:maxlat] = a[:minlat] + lat_range/2
    a2[:minlat] = a[:minlat] + lat_range/2
  else
    a1[:maxlon] = a[:minlon] + lon_range/2
    a2[:minlon] = a[:minlon] + lon_range/2
  end

  list.push(a1).push(a2)
end

def process_changeset(changeset)
  print_time('Opening changeset')

  #puts changeset
  changeset_request = '<osm><changeset><tag k="created_by" v="Redaction bot"/></changeset></osm>'
  response = @access_token.put('/api/0.6/changeset/create', changeset_request, {'Content-Type' => 'text/xml' })
  changeset_id = response.body

  print_time('Generating changeset')
  change_doc = ""
  OSM::print_osmchange(changeset, @db, change_doc, changeset_id)

  puts change_doc
  print_time('Uploading changeset')
  unless @no_action
    response = @access_token.post("/api/0.6/changeset/#{changeset_id}/upload", change_doc, {'Content-Type' => 'text/xml' })
    unless response.code == '200'
      raise "Changeset failed to apply"
    end
  end
end

def process_entities(nodes, ways, relations, region = false)
  # Fresh bot for each batch of entities
  bot = ChangeBot.new(@db)

  @db.set_entities({node: nodes, way: ways, relation: relations})

  print_time('Processing all nodes')
  bot.process_nodes!
  print_time('Processing all ways')
  bot.process_ways!
  print_time('Processing all relations')
  bot.process_relations!

  print_time('Processing Changeset')
  changeset = bot.as_changeset

  if changeset.empty?
    puts "No changeset to apply" if @verbose
  else
    begin
      changeset.each_slice(MAX_CHANGESET_ELEMENTS) do |slice|
        process_changeset(slice)
      end
    rescue
      # couldn't apply changeset for an area, so
      # - fail the whole region
      # - mark the entities for this area as failed
      # - keep processing other areas
      mark_region_failed(region) if region
      mark_entities_failed(nodes, ways, relations)
    else
      # All changesets for area applied
      print_time('Creating redactions')

      bot.redactions.each do |redaction|
        klass = case redaction.klass.name
                when "OSM::Node" then 'node'
                when "OSM::Way" then 'way'
                when "OSM::Relation" then 'relation'
                else raise "invalid klass #{redaction.klass}"
                end
        response = @access_token.post("/api/0.6/#{klass}/#{redaction.element_id}/#{redaction.version}/redact?redaction=#{redaction_id}") if not @no_action
        # TODO handle failures in redacting?
      end
      mark_entities_succeeded(nodes, ways, relations)
    end
  end
end

def process_map_call(s, region)
  parser = XML::Reader.string(s)
  while parser.read
    next unless ["node", "way", "relation"].include? parser.name
    id = parser['id'].to_i
    case parser.name
    when "node"
      @nodes << id if @candidate_nodes.include? id
    when "way"
      @ways << id if @candidate_ways.include? id
    when "relation"
      @relations << id if @candidate_relations.include? id
    end
  end
  process_entities(@nodes, @ways, @relations, region)
end

def map_call(area, attempt = 1)
  if attempt > 10
    raise "too much throttling - giving up"
  else
    response = Net::HTTP.get_response(URI(@api_site + "/api/0.6/map?bbox=#{area[:minlon]},#{area[:minlat]},#{area[:maxlon]},#{area[:maxlat]}"))
    if response.code == '509'
      puts "Darn, throttled on attempt #{attempt}. Sleeping..."
      sleep( 60 * attempt )
      response = map_call(area, attempt + 1)
    end
    return response
  end
end

@verbose = false
@no_action = false
@redaction_id = 1

MAX_REQUEST_AREA = 0.25
# MAX_CHANGESET_ELEMENTS = 50000
MAX_CHANGESET_ELEMENTS = 5

auth = YAML.load(File.open('auth.yaml'))
oauth = auth['oauth']
dbauth = auth['database']
trackerauth = auth['tracker']

@api_site = oauth['site']

@tracker_conn = PGconn.open( :dbname => trackerauth['dbname'] )

# The consumer key and consumer secret are the identifiers for this particular application, and are
# issued when the application is registered with the site. Use your own.
@consumer=OAuth::Consumer.new oauth['consumer_key'],
                              oauth['consumer_secret'],
                              {:site=>oauth['site']}

# Create the access_token for all traffic
@access_token = OAuth::AccessToken.new(@consumer, oauth['token'], oauth['token_secret'])

opts.each do |opt, arg|
  case opt
  when '--help'
    usage
    exit 0
  when '--verbose'
    @verbose = true
  when '--redaction'
    @redaction_id = arg
  when '--no-action'
    @no_action = true
  end
end

if not ARGV.empty?
  puts "Unexpected argument #{ARGV[0]}"
  usage
  exit 0
end

@nodes = []
@ways = []
@relations = []

@candidate_nodes = []
@candidate_ways = []
@candidate_relations = []

res = @tracker_conn.exec("select osm_id from candidates where type = 'node' and status = 'unprocessed'")
res.each do |r|
  @candidate_nodes << r['osm_id'].to_i
end

res = @tracker_conn.exec("select osm_id from candidates where type = 'way' and status = 'unprocessed'")
res.each do |r|
  @candidate_ways << r['osm_id'].to_i
end

res = @tracker_conn.exec("select osm_id from candidates where type = 'relation' and status = 'unprocessed'")
res.each do |r|
  @candidate_relations << r['osm_id'].to_i
end

print_time('Connecting to the database')
PGconn.open( :host => dbauth['host'], :port => dbauth['port'], :dbname => dbauth['dbname'] ).transaction do |dbconn|
  @db = PG_DB.new(dbconn)

  region = get_next_region()

  raise "no region to process" unless region

  areas = [{minlat: region[:lat], maxlat: (region[:lat] + 1), minlon: region[:lon], maxlon: (region[:lon] + 1)}]

  begin
    while areas.length > 0
      puts "#{areas.length} areas remaining" if @verbose
      area = areas.pop
      if size_of_area(area) > MAX_REQUEST_AREA
        split_area(area, areas)
        next
      else
        puts "processing #{area}" if @verbose
        map = map_call(area)
        case map.code
        when '509'
          raise "throttling should have been handled"
        when '400' # too many entities
          split_area(area, areas)
          next
        when '200'
          process_map_call(map.body, region)
        else
          raise "Unhandled response code #{map.code}"
        end
      end
    end
  rescue Exception => e
    #log(e.message)
    mark_region_failed(region)
    exit(1)
  else
    mark_region_complete(region)
  end

  raise "No actions commited" if @no_action
end
