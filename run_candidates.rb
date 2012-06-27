#!/usr/bin/env ruby
# Generates the list of candidate entities in the tracker database

require 'pg'
require 'yaml'
require 'xml/libxml'

# The candidate entities are any of those touched by a decliner, plus any other
# entities touched by someone who has made a "questionable" agreement, as decided
# by the community. The full logic on which changesets can be excluded from processing etc
# are defined elsewhere - this candidate list is only an optimisation, not a decision-making
# step. Running this with "select osm_id as id from nodes;" should have no impact on results.

auth = YAML.load(File.open('auth.yaml'))

tracker_auth = auth['tracker']
@tracker_conn = PGconn.open( :dbname => tracker_auth['dbname'] )

dbauth = auth['database']
@dbconn = PGconn.open( :dbname => dbauth['dbname'] )

res = @tracker_conn.exec("select 1 from pg_type where typname = 'candidate_status'")
if res.num_tuples == 0
  @tracker_conn.exec("CREATE TYPE candidate_status as enum ('unprocessed', 'processed', 'failed')")
end

res = @tracker_conn.exec("select 1 from pg_type where typname = 'entity_type'")
if res.num_tuples == 0
  @tracker_conn.exec("CREATE TYPE entity_type  as enum ('node', 'way', 'relation')")
end

@tracker_conn.exec("create table if not exists candidates (type entity_type, osm_id bigint, status candidate_status)")
@tracker_conn.exec("truncate table candidates")

parser = XML::Reader.io(File.open('additional_users.xml', "r"))
@additional_uids = []
while parser.read
  next unless ["user"].include? parser.name

  @additional_uids << parser['uid']
end


# For now, use a simple list of non-agreeing users
# TODO: expand with "questionable" agreements

EACH_SQL = \
  'SELECT %{type}s.%{type}_id AS id
    FROM %{type}s
    INNER JOIN changesets ON %{type}s.changeset_id = changesets.id
    INNER JOIN users ON changesets.user_id = users.id
    WHERE users.terms_agreed is NULL
    OR users.id in (%{uid_list})
    GROUP BY %{type}s.%{type}_id;'

out = @tracker_conn.transaction do |tracker_conn|
  tracker_conn.exec("copy candidates FROM STDIN WITH csv")
  ['node', 'way', 'relation'].each do |type|
    res = @dbconn.query(EACH_SQL % {:type => type, :uid_list => @additional_uids.join(",")})
    puts "#{res.num_tuples} #{type}s"
    res.each do |r|
      line = "#{type},#{r['id']},unprocessed\n"
      tracker_conn.put_copy_data(line)
    end
  end
  tracker_conn.put_copy_end
end
