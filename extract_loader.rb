#!/usr/bin/env ruby

require 'getoptlong'
require 'pg'
require 'xml/libxml'
require 'mechanize'

SCALE = 10000000
USERS_AGREED = "http://planet.openstreetmap.org/users_agreed/users_agreed.txt"
CHANGESETS_AGREED = "http://planet.openstreetmap.org/users_agreed/anon_changesets_agreed.txt"

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
                      ['--file', '-f', GetoptLong::REQUIRED_ARGUMENT]
                     )

input_file = '-'
users_agreed = USERS_AGREED
changesets_agreed = CHANGESETS_AGREED
user_limit = 286582
verbose = false

agent = Mechanize.new

opts.each do |opt, arg|
  case opt
  when '--help'
    usage
    exit 0

  when '--file'
    input_file = arg
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

@conn = PG.connect( dbname: 'openstreetmap' )
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
  puts "created changeset #{changeset_id}"
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
  puts "created user #{name}"
  @uids.push(uid)
end

def truncate_tables
  @conn.exec("truncate table users cascade")
end

# This relies on the history file being properly ordered by type, id, version
def change_entity(new)
  unless @current_entity.nil?
    unless new[:type] == @current_entity[:type] && new[:id] == @current_entity[:id]
      case @current_entity[:type]
      when :node
        @conn.exec("insert into current_nodes (id, latitude, longitude, tile, changeset_id, visible, timestamp, version)
                  (select node_id, latitude, longitude, tile, changeset_id, visible, timestamp, version from nodes where node_id = $1 and version = $2)",
                  [ @current_entity[:id],
                    @current_entity[:version]
                  ])
        @conn.exec("insert into current_node_tags (node_id, k, v) (select node_id, k, v from node_tags where node_id = $1 and version = $2)",
                  [ @current_entity[:id],
                    @current_entity[:version]
                  ])
      when :way
        @conn.exec("insert into current_ways (id, changeset_id, timestamp, visible, version)
                   (select way_id, changeset_id, timestamp, visible, version from ways where way_id = $1 and version = $2)",
                  [ @current_entity[:id],
                    @current_entity[:version]
                  ])
        @conn.exec("insert into current_way_tags (way_id, k, v) (select way_id, k, v from way_tags where way_id = $1 and version = $2)",
                   [ @current_entity[:id],
                     @current_entity[:version]
                   ])
        @conn.exec("insert into current_way_nodes (way_id, node_id, sequence_id) (select way_id, node_id, sequence_id from way_nodes where way_id = $1 and version = $2)",
                   [ @current_entity[:id],
                     @current_entity[:version]
                   ])
      when :relation
        @conn.exec("insert into current_relations (id, changeset_id, timestamp, visible, version)
                   (select relation_id, changeset_id, timestamp, visible, version from relations where relation_id = $1 and version = $2)",
                   [ @current_entity[:id],
                     @current_entity[:version]
                   ])
        @conn.exec("insert into current_relation_tags (relation_id, k, v) (select relation_id, k, v from relation_tags where relation_id = $1 and version = $2)",
                   [ @current_entity[:id],
                     @current_entity[:version]
                   ])
        @conn.exec("insert into current_relation_members (relation_id, member_type, member_id, member_role, sequence_id)
                   (select relation_id, member_type, member_id, member_role, sequence_id from relation_members where relation_id = $1 and version = $2)",
                   [ @current_entity[:id],
                     @current_entity[:version]
                   ])
      end
    end
  end
  @current_entity = new
end

truncate_tables()

# create two anonymous users, one for any anonymous changesets marked as "agreed", one for the rest.
create_user(ANON_AGREED_UID, 'Anonymous Agreed Users', false)
create_user(ANON_UNKNOWN_UID, 'Anonymous Unknown Users', false)

parser = XML::Reader.io(File.open(input_file, "r"))

@current_entity = nil

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
    @conn.exec("insert into nodes (node_id, latitude, longitude, tile, changeset_id, visible, timestamp, version) values ($1, $2, $3, $4, $5, $6, $7, $8)",
              [ id,
                (lat.to_f*SCALE).to_i,
                (lon.to_f*SCALE).to_i,
                tile,
                parser["changeset"],
                parser["visible"],
                parser["timestamp"],
                parser["version"]
              ])
    change_entity({type: :node, id: id, version: version})

  when "way"
    id = parser["id"]
    changeset_id = parser["changeset"]
    create_changeset(parser) unless @changesets.include? changeset_id
    version = parser["version"]
    @conn.exec("insert into ways (way_id, version, timestamp, changeset_id, visible) values ($1, $2, $3, $4, $5)",
              [ id,
                version,
                parser["timestamp"],
                changeset_id,
                parser["visible"]
              ])
    change_entity({type: :way, id: id, version: version, sequence_id: 1})

  when "nd"
    raise unless @current_entity[:type] == :way
    @conn.exec("insert into way_nodes (way_id, node_id, version, sequence_id) values ($1, $2, $3, $4)",
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
    @conn.exec("insert into relations (relation_id, changeset_id, timestamp, version, visible) values ($1, $2, $3, $4, $5)",
              [ id,
                changeset_id,
                parser["timestamp"],
                version,
                parser["visible"]
              ])
    change_entity({type: :relation, id: id, version: version, sequence_id: 1})

  when "member"
    raise unless @current_entity[:type] == :relation
    @conn.exec("insert into relation_members (relation_id, member_type, member_id, member_role, version, sequence_id) values ($1, $2, $3, $4, $5, $6)",
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
    @conn.exec("insert into #{type}_tags (#{type}_id, version, k, v) values ($1, $2, $3, $4)", [@current_entity[:id], @current_entity[:version], parser['k'], parser['v']])
    puts "added tag"
  end
end

# flush the final entity into the current_tables
change_entity(type: :dummy, id: 0, version: 0)

