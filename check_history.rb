#!/usr/bin/env ruby

require './osm'
require './osm_parse'
require './osm_print'
require './db'
require './changeset'
require './user'
require './change_bot'
require 'open-uri'
require 'getoptlong'
require 'mechanize'
require 'set'

@enable_bzip2 = false
begin
  require 'bzip2-ruby'
  @enable_bzip2 = true
rescue LoadError
  puts 'Compression with bzip2 disabled enable by installing bzip2-ruby'
end

USERS_AGREED = "http://planet.openstreetmap.org/users_agreed/users_agreed.txt"
CHANGESETS_AGREED = "http://planet.openstreetmap.org/users_agreed/anon_changesets_agreed.txt"

def usage
  puts <<-EOF
check_history.rb [OPTIONS...] [elements]

-h, --help:
   Show help

-s --server domain:
   Use server s for API calls. Defaults to the test API.

-v --verbose:
   Output information about the actions being taken.

-f --file:
   Take a list of history files as input.

-o --output file:
   Prints the resulting osmChange to the output file.

-u --users-agreed file:
   A URL or file with a list of user IDs of those who have agreed.
   If this is not specified then it is assumed all users have agreed.

-c --changesets-agreed file:
   A URL or file with a list of changesets which have been agreed.
   This is used only where the owner of the changeset is anonymous.
   If this is not specified then it is assumed all anonymous users have 
   agreed.

-l --user-agreed-limit int:
   The user ID below which users may not have agreed. For example,
   on the main API this number is 286582 and user IDs >= this are
   guaranteed to have agreed.

The elements should be specified with their type and ID separated
by an underscore. For example, nodes 1234 and 4321 could be checked 
using the command line:
  ruby check_history.rb node_1234 node_4321
EOF
end

def get_url_lines(agent, verbose, url)
  if url.start_with? "http://" then
    puts "Downloading #{url}..." if verbose
    agent.get(url).content
  else
    File.open(url, "r")
  end.lines.
    select {|l| not l.match(/^ *#/) }.
    map {|l| l.to_i }
end

@start_time = nil

def print_time(verbose, name = nil)
  now_time = Time.now
  print "(#{now_time - @start_time} s)\n" if verbose and not @start_time.nil?
  @start_time = now_time
  
  print "#{name}..." if verbose and not name.nil?
end

class AgreedFile
  def initialize(agent, verbose, url, limit = nil)
    @ids = get_url_lines(agent, verbose, url)
    @limit = limit
  end

  def call(i)
    return true if @limit and (i >= @limit)
    @ids.include? i
  end
end

opts = GetoptLong.new(['--help', '-h', GetoptLong::NO_ARGUMENT ],
                      ['--server', '-s', GetoptLong::REQUIRED_ARGUMENT ],
                      ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
                      ['--file', '-f', GetoptLong::NO_ARGUMENT],
                      ['--output', '-o', GetoptLong::REQUIRED_ARGUMENT ],
                      ['--users-agreed', '-u', GetoptLong::REQUIRED_ARGUMENT],
                      ['--changesets-agreed', '-c', GetoptLong::REQUIRED_ARGUMENT],
                      ['--user-agreed-limit', '-l', GetoptLong::REQUIRED_ARGUMENT])

verbose = false
read_from_file = false
server = "api.openstreetmap.org"
users_agreed = USERS_AGREED
changesets_agreed = CHANGESETS_AGREED
user_limit = 286582
output_file = '-'

agent = Mechanize.new

opts.each do |opt, arg|
  case opt
  when '--help'
    usage
    exit 0

  when '--server'
    server = arg

  when '--verbose'
    verbose = true

  when '--file'
    read_from_file = true
  
  when '--output'
    output_file = arg

  when '--users-agreed'
    users_agreed = arg

  when '--changesets-agreed'
    changesets_agreed = arg

  when '--user-agreed-limit'
    user_limit = arg.to_i
  end
end

if ARGV.empty?
  puts "No arguments found!"
  usage
  exit 0
end

if users_agreed.class == String
  users_agreed = AgreedFile.new(agent, verbose, users_agreed, user_limit)
end
if changesets_agreed.class == String
  changesets_agreed = AgreedFile.new(agent, verbose, changesets_agreed)
end

elements = {
  :changesets => Hash.new,
  :nodes => Hash.new,
  :ways => Hash.new,
  :relations => Hash.new
}

ARGV.each do |arg|
  # Get the history file for the element
  print_time(verbose, "Get the content of #{arg}")
  content =
  if read_from_file then
    if @enable_bzip2 and arg.end_with? '.bz2' then
      Bzip2::Reader.new File.open(arg, "r")
    else
      File.open(arg, "r")
    end.read()
  else
    type, id = arg.split("_")
    id = id.to_i

    url = "http://#{server}/api/0.6/#{type}/#{id}/history"
    puts "Downloading #{url}..." if verbose
    agent.get(url).content
  end
  
  # Parse the file into elements
  print_time(verbose, "Parse the content of #{arg}")
  history = OSM::parse(content)
  history.each do |e|
    t =  if e.class == OSM::Node then :nodes
      elsif e.class == OSM::Way then :ways
      elsif e.class == OSM::Relation then :relations
    end
    if elements[t].has_key? e.element_id then
      elements[t][e.element_id] = elements[t][e.element_id] << e
    else
      elements[t][e.element_id] = [e]
    end
  end
  
  # Get the status of each changeset
  print_time(verbose, "Get the status of each changeset in #{arg}")
  history.each do |e|
    cs_id = e.changeset_id
    unless elements[:changesets].has_key? cs_id
      uid = if e.uid.nil? then
        url = "http://#{server}/api/0.6/changeset/#{cs_id}"
        puts "Downloading #{url}..." if verbose
        OSM::user_id_from_changeset(agent.get(url).content)
      else
        e.uid
      end
      agreed = if uid == 0
                 changesets_agreed.call(cs_id)
               else
                 users_agreed.call(uid)
               end
      elements[:changesets][cs_id] = Changeset[User[agreed]]
    end
  end
end

db = DB.new(elements)

bot = ChangeBot.new(db)
print_time(verbose, "Process all nodes")
bot.process_nodes!
print_time(verbose, "Process all ways")
bot.process_ways!
print_time(verbose, "Process all relations")
bot.process_relations!

print_time(verbose, "Delete empty objects")
changeset = bot.as_changeset

print_time(verbose, "Output the changeset")
if output_file == '-'
  fp = $stdout
elsif @enable_bzip2 and output_file.end_with? '.bz2'
  fp = Bzip2::Writer.new File.open(output_file, "w")
else
  fp = File.open(output_file, "w")
end
OSM::print_osmchange(changeset, db, out = fp)

print_time(verbose)

