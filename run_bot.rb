#!/usr/bin/env ruby
# Runs the redaction bot on a live database.

require './pg_db'
require './change_bot'
require './osm_print'

require 'pg'
require 'getoptlong'

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
  #OSM::print_osmchange(changeset, db)
  
  raise "No actions commited" if no_action
end
