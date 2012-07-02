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
require 'logger'

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

-i --ignore-regions
  Ignore the list of regions, and just process the candidates directly

-n --no-action
   Send all the commands to the database, but do not commit them.
EOF
end

def print_time(name = nil)
  now_time = Time.now
  print "(#{now_time - @start_time} s)\n" if @verbose and not @start_time.nil?
  @start_time = now_time
  
  print "#{name}..." if @verbose and not name.nil?
end

NEXT_REGION_SQL = \
    "UPDATE regions SET STATUS = 'processing'
     WHERE id = ( SELECT id
                  FROM regions
                  WHERE status = 'unprocessed'
                  AND id not in (
                      SELECT n.id as id
                      FROM regions as n,
                      ( SELECT id, lat, lon FROM regions WHERE status = 'processing' ) as bad
                      WHERE ((abs(bad.lat - n.lat) < 2) and (abs(bad.lon - n.lon) < 2))
                  )
                  ORDER BY id
                  LIMIT 1
                )
     RETURNING id, lat, lon;"

def get_next_region()
  res = @tracker_conn.exec(NEXT_REGION_SQL)
  if res.num_tuples == 0
    false
  else
    {id: res[0]['id'], lat: res[0]['lat'].to_f, lon: res[0]['lon'].to_f}
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
  unless @no_action
    @tracker_conn.exec("update candidates set status = 'processed' where type = 'node' and osm_id in (%{list})" % {list: nodes.join(", ")}) unless nodes.empty?
    @tracker_conn.exec("update candidates set status = 'processed' where type = 'way' and osm_id in (%{list})" % {list: ways.join(",")}) unless ways.empty?
    @tracker_conn.exec("update candidates set status = 'processed' where type = 'relation' and osm_id in (%{list})" % {list: relations.join(",")}) unless relations.empty?
  end
end

def mark_entities_failed(nodes, ways, relations)
  unless @no_action
    @tracker_conn.exec("update candidates set status = 'failed' where type = 'node' and osm_id in (%{list})" % {list: nodes.join(",")}) unless nodes.empty?
    @tracker_conn.exec("update candidates set status = 'failed' where type = 'way' and osm_id in (%{list})" % {list: ways.join(",")}) unless ways.empty?
    @tracker_conn.exec("update candidates set status = 'failed' where type = 'relation' and osm_id in (%{list})" % {list: relations.join(",")}) unless relations.empty?
  end
end

def size_of_area(a)
  (a[:maxlat] - a[:minlat]) * (a[:maxlon] - a[:minlon])
end

# split an area into two areas, and add them to the list
# divide along the longest edge
def split_area(a, list)
  if size_of_area(a) < TOO_SMALL_TO_SPLIT
    @log.error("area too small to split: #{a}")
    raise "area too small to split"
  end
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

  changeset_request = '<osm><changeset><tag k="created_by" v="Redaction bot"/></changeset></osm>'
  response = @access_token.put('/api/0.6/changeset/create', changeset_request, {'Content-Type' => 'text/xml' })
  raise "Failed to open changeset" unless response.code == '200'
  changeset_id = response.body

  print_time('Generating changeset')
  change_doc = ""
  OSM::print_osmchange(changeset, @db, change_doc, changeset_id)

  @log.debug( "Changeset:\n" + change_doc )
  #puts change_doc
  print_time('Uploading changeset')
  unless @no_action
    response = @access_token.post("/api/0.6/changeset/#{changeset_id}/upload", change_doc, {'Content-Type' => 'text/xml' })
    unless response.code == '200'
      # It's quite likely for a changeset to fail, if someone else is editing in the area being processed
      raise "Changeset failed to apply"
    end
    @log.info("Uploaded changeset #{changeset_id}")
  end
end

def process_entities(nodes, ways, relations, region = false)
  @log.debug("Processing Entities: #{nodes.length} / #{ways.length} / #{relations.length}")
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
    @log.debug("No changeset to apply")
    puts "No changeset to apply" if @verbose
    process_redactions(bot)
    mark_entities_succeeded(nodes, ways, relations)
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
      process_redactions(bot)
      mark_entities_succeeded(nodes, ways, relations)
    end
  end
end

def process_redactions(bot)
  print_time('Creating redactions')

  bot.redactions.each do |redaction|
    klass = case redaction.klass.name
            when "OSM::Node" then 'node'
            when "OSM::Way" then 'way'
            when "OSM::Relation" then 'relation'
            else raise "invalid klass #{redaction.klass}"
            end

    @log.info("Redaction for #{klass} #{redaction.element_id} v#{redaction.version}")
    unless @no_action
      response = @access_token.post("/api/0.6/#{klass}/#{redaction.element_id}/#{redaction.version}/redact?redaction=#{@redaction_id}") if not @no_action
      unless response.code == '200'
        @log.error("Failed to redact element")
        raise "Failed to redact element"
      end
    end
  end
end

def process_map_call(s, region)
  @log.debug("Processing map call")
  parser = XML::Reader.string(s)
  # These are what we want to send to the bot for processing
  nodes = []
  ways = []
  relations = []
  # These are just debugging aids
  debug_nodes = []
  debug_ways = []
  debug_relations = []
  candidate_nodes = get_candidate_list('node')
  candidate_ways = get_candidate_list('way')
  candidate_relations = get_candidate_list('relation')
  @log.debug("Candidates: #{candidate_nodes.length} / #{candidate_ways.length} / #{candidate_relations.length}")
  while parser.read
    next unless ["node", "way", "relation"].include? parser.name
    id = parser['id'].to_i
    case parser.name
    when "node"
      debug_nodes << id
      nodes << id if candidate_nodes.include? id
    when "way"
      debug_ways << id
      ways << id if candidate_ways.include? id
    when "relation"
      debug_relations << id
      relations << id if candidate_relations.include? id
    end
  end
  @log.debug("Received: #{debug_nodes.length} / #{debug_ways.length} / #{debug_relations.length}")
  process_entities(nodes, ways, relations, region)
end

def map_call(area, attempt = 1)
  if attempt > 10
    raise "too much throttling - giving up"
  else
    url = @api_site + "/api/0.6/map?bbox=#{area[:minlon]},#{area[:minlat]},#{area[:maxlon]},#{area[:maxlat]}"
    @log.debug("Making map call to #{url}")

    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 320 # api timeout is 300
    response = http.request_get(uri.request_uri)

    if response.code == '509'
      puts "Darn, throttled on attempt #{attempt}. Sleeping..."
      sleep( 60 * attempt )
      response = map_call(area, attempt + 1)
    end
    return response
  end
end

def get_candidate_list(type)
  c = []
  res = @tracker_conn.exec("select osm_id from candidates where type = $1 and status = 'unprocessed'", [type])
  res.each do |r|
    c << r['osm_id'].to_i
  end
  c
end

opts = GetoptLong.new(['--help', '-h', GetoptLong::NO_ARGUMENT ],
                      ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
                      ['--ignore-regions', '-i', GetoptLong::NO_ARGUMENT],
                      ['--redaction', '-r', GetoptLong::REQUIRED_ARGUMENT ],
                      ['--no-action', '-n', GetoptLong::NO_ARGUMENT],
                     )

@start_time = nil
@verbose = false
@no_action = false
@redaction_id = 1
@ignore_regions = false

MAX_REQUEST_AREA = 0.25
TOO_SMALL_TO_SPLIT = 0.000001 # roughly 10cm at the equator

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
  when '--ignore-regions'
    @ignore_regions = true
  when '--no-action'
    @no_action = true
  end
end

if not ARGV.empty?
  puts "Unexpected argument #{ARGV[0]}"
  usage
  exit 0
end

unless Dir.exists?('logs')
  Dir.mkdir('logs')
end
log_name = "logs/#{Time.now.strftime('%Y%m%dT%H%M%S')}.log"

print_time("Logging to #{log_name}") if @verbose
@log = Logger.new(log_name)
@log.level = Logger::DEBUG

if @no_action
  @log.info("No actions will be taken")
end

print_time('Connecting to the database')
PGconn.open( :host => dbauth['host'], :port => dbauth['port'], :dbname => dbauth['dbname'] ).transaction do |dbconn|
  @db = PG_DB.new(dbconn)

  unless @no_action
    res = dbconn.exec("select id from redactions where id = $1", [@redaction_id])
    unless res.num_tuples == 1
      @log.error("invalid redaction id: #{@redaction_id}")
      raise "invalid redaction id"
    end
  end

  if @ignore_regions
    # only process 1000 at a time to minimise conflicts with mappers
    puts "Ignoring the regions" if @verbose
    nodes = get_candidate_list('node').take(1000)
    ways = get_candidate_list('way').take(1000)
    relations = get_candidate_list('relation').take(1000)

    if nodes.empty? && ways.empty? && relations.empty?
      raise "No entities to process"
    else
      process_entities(nodes,ways,relations)
    end
  else
    region = get_next_region()

    raise "No region to process" unless region

    @log.info("Processing region #{region}")

    areas = [{minlat: region[:lat], maxlat: (region[:lat] + 1), minlon: region[:lon], maxlon: (region[:lon] + 1)}]

    begin
      while areas.length > 0
        @log.debug("#{areas.length} areas remaining")
        area = areas.pop
        if size_of_area(area) > MAX_REQUEST_AREA
          split_area(area, areas)
          next
        else
          @log.info("Processing #{area}")
          map = map_call(area)
          case map.code
          when '509'
            raise "throttling should have been handled"
          when '400' # too many entities
            # There's actually more than one way to trigger a 400 response. We might need to analyse the response
            # message to make sure splitting is actually the correct thing to do.
            @log.debug("too many entities, splitting")
            split_area(area, areas)
            next
          when '200'
            process_map_call(map.body, region)
          else
            @log.error("Unhandled reponse code #{map.code}\n#{map.body}")
            raise "Unhandled response code #{map.code}"
          end
        end
      end
    rescue Exception => e
      @log.error(e.message)
      puts e.message
      mark_region_failed(region)
      exit(1)
    else
      mark_region_complete(region)
    end
  end

  raise "No actions commited" if @no_action
end
