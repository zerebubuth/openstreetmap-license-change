#!/usr/bin/env ruby
# Import the stuff that osmosis can not import yet, like user statuses.

require 'pg'
require 'getoptlong'
require 'mechanize'

#default values
USERS_AGREED = "http://planet.openstreetmap.org/users_agreed/users_agreed.txt"
CHANGESETS_AGREED = "http://planet.openstreetmap.org/users_agreed/anon_changesets_agreed.txt"
USER_LIMIT = 286582

def get_url_lines(agent, verbose, url)
  if url.start_with? "http://" then
    puts "Downloading #{url}..." if verbose
    agent.get(url).content
  else
    File.open(url, "r")
  end.lines.
    select {|l| not l.match(/^ *(#|$)/) }.
    map {|l| l.to_i }
end

def usage
  puts <<-EOF
usage: dbimport.rb [OPTIONS...]

Imports important parts of the database for the redaction bot.
This is the bits that osmosis does not import like agreed users
and changesets.

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

-u --users-agreed file:
   A URL or file with a list of user IDs of those who have agreed.
   If this is not specified then it will download the list from osm.org.

-c --changesets-agreed file:
   A URL or file with a list of changesets which have been agreed.
   This is used only where the owner of the changeset is anonymous.
   If this is not specified then it will download the list from osm.org.

-l --user-agreed-limit int:
   The user ID below which users may not have agreed. For example,
   on the main API this number is 286582 and user IDs >= this are
EOF
end

opts = GetoptLong.new(['--help', '-h', GetoptLong::NO_ARGUMENT ],
                      ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
                      ['--no-action', '-n', GetoptLong::NO_ARGUMENT],
                      ['--users-agreed', '-u', GetoptLong::REQUIRED_ARGUMENT],
                      ['--changesets-agreed', '-c', GetoptLong::REQUIRED_ARGUMENT],
                      ['--user-agreed-limit', '-l', GetoptLong::REQUIRED_ARGUMENT],
                      ['--host', GetoptLong::REQUIRED_ARGUMENT],
                      ['--database', GetoptLong::REQUIRED_ARGUMENT],
                      ['--user', GetoptLong::REQUIRED_ARGUMENT],
                      ['--password', GetoptLong::REQUIRED_ARGUMENT])

verbose = false
no_action = false
users_agreed = USERS_AGREED
changesets_agreed = CHANGESETS_AGREED
user_limit = USER_LIMIT
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
  when '--users-agreed'
    users_agreed = arg
  when '--changesets-agreed'
    changesets_agreed = arg
  when '--user-agreed-limit'
    user_limit = arg.to_i
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

agent = Mechanize.new

PGconn.open(:host => dbhost, :dbname => dbname, :user => dbuser, :password => dbpass).transaction do |dbconn|
  # Set all agreed users to agreed
  get_url_lines(agent, verbose, users_agreed).each_slice(100) do |user_ids|
    sql = "UPDATE users SET terms_seen = true, terms_agreed = \'2012-04-10 00:00:00\' WHERE " \
      + user_ids.map {|id| "id = #{id} or "}.join + "false;"
    dbconn.exec(sql)
  end
  
  # Set all users with an id over the limit to agreed
  dbconn.exec("UPDATE users SET terms_seen = true, terms_agreed = \'2012-04-10 00:00:00\' WHERE id >= #{user_limit};")

  # Insert an anonymous agreeing user as a dummy
  dbconn.exec("INSERT INTO users (email, id, pass_crypt, creation_time, display_name, data_public, terms_seen, terms_agreed) VALUES ('anon_user@example.com', -2, 00000000000000000000000000000000, now(), 'Anonymous agreeing user', false, true, '2012-04-10 00:00:00');")

  # Set all agreed anonymous changesets to agreed user
  get_url_lines(agent, verbose, changesets_agreed).each_slice(100) do |changeset_ids|
    sql = "UPDATE changesets SET user_id = -2 WHERE " \
      + changeset_ids.map {|id| "id = #{id} or "}.join + "false;"
    dbconn.exec(sql)
  end

  raise "No actions commited" if no_action
end


