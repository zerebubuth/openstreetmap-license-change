#!/usr/bin/env ruby
# Redacts our favourite mega relation

require 'oauth'
require 'yaml'
require 'logger'

# There is one massive relation where every version is by a decliner and
# it's already deleted. However, the expected runtime of the bot is something
# north of a week.

# So lets special-case it somewhat.

ENTITY_ID = 78907
HIGHEST_VERSION = 720
@redaction_id_hidden = 1

auth = YAML.load(File.open('auth.yaml'))
oauth = auth['oauth']

@api_site = oauth['site']

# The consumer key and consumer secret are the identifiers for this particular application, and are
# issued when the application is registered with the site. Use your own.
@consumer=OAuth::Consumer.new oauth['consumer_key'],
                              oauth['consumer_secret'],
                              {:site=>oauth['site']}

@consumer.http.read_timeout = 320

# Create the access_token for all traffic
@access_token = OAuth::AccessToken.new(@consumer, oauth['token'], oauth['token_secret'])

LOG_DIR = 'logs'
log_name = "#{Time.now.strftime('%Y%m%dT%H%M%S')}-#{$$}.log"


 puts "Special mega-relation redaction."

# Don't include the highest version
(205...HIGHEST_VERSION).each do |version|
  puts "Redaction for relation #{ENTITY_ID} v#{version} hidden"
  response = @access_token.post("/api/0.6/relation/#{ENTITY_ID}/#{version}/redact?redaction=#{@redaction_id_hidden}")
  unless response.code == '200'
    puts "Failed to redact element - response: #{response.code} \n #{response.body}"
    raise "Failed to redact element"
  end
end
