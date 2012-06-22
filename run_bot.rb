#!/usr/bin/env ruby
# Runs the redaction bot on a live database.

require './pg_db'
require './change_bot'
require './osm_print'

require 'pg'
require 'getoptlong'
require 'oauth'
require 'yaml'

def usage
  puts <<-EOF
usage: run_bot.rb [OPTIONS...]

Run the redaction bot on a standard rails port database.

-h, --help:
   Show help

--host domain:
   Database hostname (localhost)

--database name
   Database to import into. (osm)
  
--user name
   Username of the database. (openstreetmap)
  
--password pass
   Password for that user. (openstreetmap)

-v --verbose:
   Output information about the actions being taken.

-n --no-action
   Send all the commands to the database, but do not commit them.
EOF
end

opts = GetoptLong.new(['--help', '-h', GetoptLong::NO_ARGUMENT ],
                      ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
                      ['--no-action', '-n', GetoptLong::NO_ARGUMENT],
                      ['--host', GetoptLong::REQUIRED_ARGUMENT],
                      ['--database', GetoptLong::REQUIRED_ARGUMENT],
                      ['--user', GetoptLong::REQUIRED_ARGUMENT],
                      ['--password', GetoptLong::REQUIRED_ARGUMENT])

@start_time = nil

def print_time(verbose, name = nil)
  now_time = Time.now
  print "(#{now_time - @start_time} s)\n" if verbose and not @start_time.nil?
  @start_time = now_time
  
  print "#{name}..." if verbose and not name.nil?
end

verbose = false
no_action = false
dbhost = 'localhost'
dbname = 'osm'
dbuser = 'openstreetmap'
dbpass = 'openstreetmap'

opts.each do |opt, arg|
  case opt
  when '--help'
    usage
    exit 0
  when '--verbose'
    verbose = true
  when '--no-action'
    no_action = true
  when '--host'
    dbhost = arg
  when '--database'
    dbname = arg
  when '--user'
    dbuser = arg
  when '--password'
    dbpass = arg
  end
end

if not ARGV.empty?
  puts "Unexpected argument #{ARGV[0]}"
  usage
  exit 0
end

print_time(verbose, 'Connecting to the database')
PGconn.open(:host => dbhost, :dbname => dbname, :user => dbuser, :password => dbpass).transaction do |dbconn|
  db = PG_DB.new(dbconn)
  bot = ChangeBot.new(db)
  
  print_time(verbose, 'Processing all nodes')
  bot.process_nodes!
  print_time(verbose, 'Processing all ways')
  bot.process_ways!
  print_time(verbose, 'Processing all relations')
  bot.process_relations!
  
  print_time(verbose, 'Delete empty objects')
  changeset = bot.as_changeset
  
  print_time(verbose)

  # Format of auth.yml:
  # consumer_key: (from osm.org)
  # consumer_secret: (from osm.org)
  # token: (use oauth setup flow to get this)
  # token_secret: (use oauth setup flow to get this)
  auth = YAML.load(File.open('auth.yaml'))

  # The consumer key and consumer secret are the identifiers for this particular application, and are
  # issued when the application is registered with the site. Use your own.
  @consumer=OAuth::Consumer.new auth['consumer_key'],
                                auth['consumer_secret'],
                                {:site=>"http://localhost:3000"}

  # Create the access_token for all traffic
  @access_token = OAuth::AccessToken.new(@consumer, auth['token'], auth['token_secret'])

  # Use the access token for various commands. Although these take plain strings, other API methods
  # will take XML documents.

  changeset_request = '<osm><changeset><tag k="created_by" v="Redaction bot"/></changeset></osm>'
  response = @access_token.put('/api/0.6/changeset/create', changeset_request, {'Content-Type' => 'text/xml' })
  changeset_id = response.body

  change_doc = ""
  OSM::print_osmchange(changeset, db, change_doc, changeset_id)

  puts "changeset created: #{changeset_id}"
  foo = @access_token.post("/api/0.6/changeset/#{changeset_id}/upload", change_doc, {'Content-Type' => 'text/xml' })
  puts foo.response
  #OSM::print_osmchange(changeset, db)

  puts "redactions"
  redaction_id = 1 # is there an api for creating them?

  bot.redactions.each do |redaction|
    klass = case redaction.klass.name
            when "OSM::Node" then 'node'
            when "OSM::Way" then 'way'
            when "OSM::Relation" then 'relation'
            else raise "invalid klass #{redaction.klass}"
            end
    response = @access_token.post("/api/0.6/#{klass}/#{redaction.element_id}/#{redaction.version}/redact?redaction=#{redaction_id}")
    puts response.body
  end
  raise "No actions commited" if no_action
end
