#!/usr/bin/env ruby
# Generates the ordered region list in the tracker database

require 'pg'
require 'yaml'
require 'xml/libxml'

# Lat+lon are for the Bottom Left of the cell

@regions = {}

parser = XML::Reader.io(File.open('bounds.xml', "r"))

dbauth = YAML.load(File.open('auth.yaml'))['tracker']

@conn = PGconn.open( :dbname => dbauth['dbname'] )

res = @conn.exec("select 1 from pg_type where typname = 'region_status'")
if res.num_tuples == 0
  @conn.exec("CREATE TYPE region_status as enum ('unprocessed', 'processing', 'failed', 'complete')")
end

@conn.exec("create table if not exists regions (id serial, lat integer, lon integer, status region_status, bot_id integer)")
@conn.exec("truncate table regions")

def add_region(lat, lon)
  @conn.exec("insert into regions (lat, lon) values ($1, $2)", [lat, lon])
  @regions[[lat, lon]] = true
end

@conn.transaction do
  while parser.read do
    next unless ["bounds"].include? parser.name

    # you want to floor the maxes too, or do (ceil - 1)
    min_lat = parser["minlat"].to_f.floor
    max_lat = parser["maxlat"].to_f.floor
    min_lon = parser["minlon"].to_f.floor
    max_lon = parser["maxlon"].to_f.floor

    (min_lat..max_lat).each do |lat|
      (min_lon..max_lon).each do |lon|
        add_region(lat, lon)
      end
    end
  end

  # Add remaining regions that weren't covered by the bounds
  (-180..179).each do |lon|
    (-90..89).each do |lat|
      unless @regions.key?([lat, lon])
        add_region(lat, lon)
      end
    end
  end
end

