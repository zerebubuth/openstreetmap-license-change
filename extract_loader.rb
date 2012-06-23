#!/usr/bin/env ruby

require 'getoptlong'
require 'pg'
require 'yaml'
require 'xml/libxml'
require 'mechanize'

SCALE = 10000000
USERS_AGREED = "http://planet.openstreetmap.org/users_agreed/users_agreed.txt"
CHANGESETS_AGREED = "http://planet.openstreetmap.org/users_agreed/anon_changesets_agreed.txt"

@enable_bzip2 = false
begin
  require 'bzip2-ruby'
  @enable_bzip2 = true
rescue LoadError
  puts 'Compression with bzip2 disabled enable by installing bzip2-ruby'
end

def usage
  puts <<-EOF
extract_loader.rb [OPTIONS...] [elements]

-h, --help:
  Show help

-f, --file:
  osh file to load into database

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
                      ['--users-agreed', '-u', GetoptLong::REQUIRED_ARGUMENT],
                      ['--changesets-agreed', '-c', GetoptLong::REQUIRED_ARGUMENT],
                      ['--user-agreed-limit', '-l', GetoptLong::REQUIRED_ARGUMENT],
                      ['--file', '-f', GetoptLong::REQUIRED_ARGUMENT],
                      ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
                     )

input_file = '-'
users_agreed = USERS_AGREED
changesets_agreed = CHANGESETS_AGREED
user_limit = 286582
verbose = false

dbauth = YAML.load(File.open('auth.yaml'))['database']

agent = Mechanize.new

opts.each do |opt, arg|
  case opt
  when '--help'
    usage
    exit 0

  when '--file'
    input_file = arg

  when '--verbose'
    verbose = true
  end
end

if users_agreed.class == String
  @users_agreed = AgreedFile.new(agent, verbose, users_agreed, user_limit)
end
if changesets_agreed.class == String
  @changesets_agreed = AgreedFile.new(agent, verbose, changesets_agreed)
end

# taken from rails_port/lib/quad_tile.rb
def tile_for_point(lat, lon)
  x = ((lon.to_f + 180) * 65535 / 360).round
  y = ((lat.to_f + 90) * 65535 / 180).round

  return tile_for_xy(x, y)
end

# taken from rails_port/lib/quad_tile.rb
def tile_for_xy(x, y)
  t = 0

  16.times do
    t = t << 1
    t = t | 1 unless (x & 0x8000).zero?
    x <<= 1
    t = t << 1
    t = t | 1 unless (y & 0x8000).zero?
    y <<= 1
  end

  return t
end

@conn = PGconn.open( :host => dbauth['host'], :port => dbauth['port'], :dbname => dbauth['dbname'], :user => dbauth['user'], :password => dbauth['password'] )
@changesets = []
@uids = []
@time = Time.now.strftime('%FT%T')

# hopefully we'll be finished before these uids are in use...
ANON_AGREED_UID = 100_000_000
ANON_UNKNOWN_UID = 200_000_000

def create_changeset(parser)
  changeset_id = parser["changeset"]

  if parser["uid"]
    uid = parser["uid"].to_i
  else
    uid = @changesets_agreed.call(changeset_id.to_i) ? ANON_AGREED_UID : ANON_UNKNOWN_UID
  end

  unless @uids.include?(uid)
    create_user(uid, parser["user"])
  end

  result = @conn.exec("insert into changesets (id, user_id, created_at, closed_at) values ($1, $2, $3, $4)", [ changeset_id, uid, @time, @time ])
  @changesets.push(changeset_id)
end

def create_user(uid, name, data_public = true)
  agreed_time = case uid
                when ANON_AGREED_UID then @time
                when ANON_UNKNOWN_UID then nil
                else
                  @users_agreed.call(uid) ? @time : nil
                end
  result = @conn.exec("insert into users (id, email, pass_crypt, creation_time, display_name, data_public, terms_agreed) values ($1, $2, $3, $4, $5, $6, $7)",
                      [uid, "user_#{uid}@example.net", 'foobarbaz', @time, name, data_public, agreed_time])
  @uids.push(uid)
end

def truncate_tables
  @conn.exec("truncate table users cascade")
end

puts "Deleting all relevant tables" if verbose
truncate_tables()

# create two anonymous users, one for any anonymous changesets marked as "agreed", one for the rest.
create_user(ANON_AGREED_UID, 'Anonymous Agreed Users', false)
create_user(ANON_UNKNOWN_UID, 'Anonymous Unknown Users', false)

file_io = \
if @enable_bzip2 and input_file.end_with? '.bz2' then
  Bzip2::Reader.new File.open(input_file, "r")
else
  File.open(input_file, "r")
end

parser = XML::Reader.io(file_io)

puts "Loading xml file to the database" if verbose
@current_entity = nil
@conn.transaction do |conn|
  while parser.read do
    next unless ["node", "way", "relation", "tag", "nd", "member"].include? parser.name
    next if parser.node_type == XML::Reader::TYPE_END_ELEMENT
    case parser.name
    when "node"
      id = parser["id"]
      lat = parser["lat"]
      lon = parser["lon"]
      tile = tile_for_point(lat,lon)
      create_changeset(parser) unless @changesets.include? parser["changeset"]
      version = parser["version"]
      conn.exec("insert into nodes (node_id, latitude, longitude, tile, changeset_id, visible, timestamp, version) values ($1, $2, $3, $4, $5, $6, $7, $8)",
                [ id,
                  (lat.to_f*SCALE).to_i,
                  (lon.to_f*SCALE).to_i,
                  tile,
                  parser["changeset"],
                  parser["visible"],
                  parser["timestamp"],
                  parser["version"]
                ])
      @current_entity = {type: :node, id: id, version: version}

    when "way"
      id = parser["id"]
      changeset_id = parser["changeset"]
      create_changeset(parser) unless @changesets.include? changeset_id
      version = parser["version"]
      conn.exec("insert into ways (way_id, version, timestamp, changeset_id, visible) values ($1, $2, $3, $4, $5)",
                [ id,
                  version,
                  parser["timestamp"],
                  changeset_id,
                  parser["visible"]
                ])
      @current_entity = {type: :way, id: id, version: version, sequence_id: 1}

    when "nd"
      raise unless @current_entity[:type] == :way
      conn.exec("insert into way_nodes (way_id, node_id, version, sequence_id) values ($1, $2, $3, $4)",
                [ @current_entity[:id],
                  parser["ref"],
                  @current_entity[:version],
                  @current_entity[:sequence_id]
                ])
      @current_entity[:sequence_id] += 1

    when "relation"
      id = parser["id"]
      changeset_id = parser["changeset"]
      create_changeset(parser) unless @changesets.include? changeset_id
      version = parser["version"]
      conn.exec("insert into relations (relation_id, changeset_id, timestamp, version, visible) values ($1, $2, $3, $4, $5)",
                [ id,
                  changeset_id,
                  parser["timestamp"],
                  version,
                  parser["visible"]
                ])
      @current_entity = {type: :relation, id: id, version: version, sequence_id: 1}

    when "member"
      raise unless @current_entity[:type] == :relation
      conn.exec("insert into relation_members (relation_id, member_type, member_id, member_role, version, sequence_id) values ($1, $2, $3, $4, $5, $6)",
                 [ @current_entity[:id],
                   parser["type"].capitalize,
                   parser["ref"],
                   parser["role"],
                   @current_entity[:version],
                   @current_entity[:sequence_id]
                 ])
      @current_entity[:sequence_id] += 1

    when "tag"
      type = @current_entity[:type].to_s
      conn.exec("insert into #{type}_tags (#{type}_id, version, k, v) values ($1, $2, $3, $4)", [@current_entity[:id], @current_entity[:version], parser['k'], parser['v']])
    end
  end

  # remove data that is not following the contraints of the database
  puts "Sanitizing the data" if verbose
  conn.exec('WITH missing_nodes AS (
               SELECT way_id FROM way_nodes 
               WHERE NOT node_id IN (SELECT node_id FROM nodes) 
               GROUP BY way_id) 
             DELETE FROM way_tags 
             USING missing_nodes 
             WHERE way_tags.way_id = missing_nodes.way_id;')
  conn.exec('WITH missing_nodes AS (
               SELECT way_id FROM way_nodes 
               WHERE NOT node_id IN (SELECT node_id FROM nodes) 
               GROUP BY way_id) 
             DELETE from way_nodes 
             USING missing_nodes 
             WHERE way_nodes.way_id = missing_nodes.way_id;')
  conn.exec('DELETE from ways
             WHERE NOT way_id IN (SELECT way_id FROM way_nodes);')

  # populate the current tables
  puts "Populate the current_* tables" if verbose
  # nodes
  conn.exec('INSERT INTO current_nodes
             SELECT DISTINCT ON (node_id)
             node_id AS id, latitude, longitude, changeset_id, visible, timestamp, tile, version
             FROM nodes
             ORDER BY node_id, version DESC;')
  conn.exec('INSERT INTO current_node_tags
             SELECT DISTINCT ON (node_id, k)
             node_id, k, v
             FROM node_tags
             ORDER BY node_id, k, version DESC;')
  # ways
  conn.exec('INSERT INTO current_ways
             SELECT DISTINCT ON (way_id)
             way_id AS id, changeset_id, timestamp, visible, version
             FROM ways
             ORDER BY way_id, version DESC;')
  conn.exec('INSERT INTO current_way_nodes
             SELECT DISTINCT ON (way_id, sequence_id)
             way_id, node_id, sequence_id
             FROM way_nodes
             ORDER BY way_id, sequence_id, version DESC;')
  conn.exec('INSERT INTO current_way_tags
             SELECT DISTINCT ON (way_id, k)
             way_id, k, v
             FROM way_tags
             ORDER BY way_id, k, version DESC;')
  # relations
  conn.exec('INSERT INTO current_relations
             SELECT DISTINCT ON (relation_id)
             relation_id AS id, changeset_id, timestamp, visible, version
             FROM relations
             ORDER BY relation_id, version DESC;')
  conn.exec('INSERT INTO current_relation_members
             SELECT DISTINCT ON (relation_id, sequence_id)
             relation_id, member_type, member_id, member_role, sequence_id
             FROM relation_members
             ORDER BY relation_id, sequence_id, version DESC;')
  conn.exec('INSERT INTO current_relation_tags
             SELECT DISTINCT ON (relation_id, k)
             relation_id, k, v
             FROM relation_tags
             ORDER BY relation_id, k, version DESC;')

  # reset sequences
  puts "Reseting sequences" if verbose
  ['changesets', 'current_nodes', 'current_relations', 'current_ways', 'users'].each do |table|
    @conn.exec("select setval('#{table}_id_seq', (select max(id) from #{table}));")
  end
end
