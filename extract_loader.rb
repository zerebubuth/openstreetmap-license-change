#!/usr/bin/env ruby

require 'getoptlong'
require 'pg'
require 'xml/libxml'

SCALE = 10000000

def usage
  puts <<-EOF
extract_loader.rb [OPTIONS...] [elements]

-h, --help:
  Show help
-f, --file:
  osh file to load into database
EOF
end

opts = GetoptLong.new(['--help', '-h', GetoptLong::NO_ARGUMENT ],
                      ['--file', '-f', GetoptLong::REQUIRED_ARGUMENT])

input_file = '-'

opts.each do |opt, arg|
  case opt
  when '--help'
    usage
    exit 0

  when '--file'
    input_file = arg
  end
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
@anon_id = 1



def create_changeset(parser)
  uid = parser["uid"] ? parser["uid"] : @anon_id
  changeset_id = parser["changeset"]

  unless @uids.include?(uid)
    create_user(uid, parser["user"])
  end

  result = @conn.exec("insert into changesets (id, user_id, created_at, closed_at) values ($1, $2, $3, $4)", [ changeset_id, uid, @time, @time ])
  puts "created changeset #{changeset_id}"
  @changesets.push(changeset_id)
end

def create_user(uid, name)
  result = @conn.exec("insert into users (id, email, pass_crypt, creation_time, display_name) values ($1, $2, $3, $4, $5)",
                      [uid, "user_#{uid}@example.net", 'foobarbaz', @time, name])
  puts "created user #{name}"
  @uids.push(uid)
end

def truncate_tables
  @conn.exec("truncate table users cascade")
end

truncate_tables()
create_user(1, 'Anonymous Users')

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
    @current_entity = {type: :node, id: id, version: version}
  when "way"
    id = parser["id"]
    changeset_id = parser["changeset"]
    create_changeset(parser) unless @changesets.include? changeset_id
    @conn.exec("insert into ways (way_id, version, timestamp, changeset, visible) values ($1, $2, $3, $4, $5)",
              [ id,
                parser["version"],
                parser["timestamp"],
                changeset_id,
                parser["visible"]
              ])
    @current_entity = {type: :way, id: id, version: version, sequence_id: 0}
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
    @current_entity = {type: :relation, id: id, version: version, sequence_id: 0}

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

  