#!/usr/bin/ruby

# Get all the auth details you need
# You wouldn't actually do it this way, but hey.
# Normally you'd distribute the consumer stuff with your
# application, and each user gets the access_token stuff
# But hey, this is just a demo.

require 'rubygems'
require 'oauth'
require 'yaml'

y = YAML.load(File.open('auth.yaml'))

# Format of auth.yml:
# consumer_key: (from osm.org)
# consumer_secret: (from osm.org)
# token: (use oauth setup flow to get this)
# token_secret: (use oauth setup flow to get this)

puts "First, go register a new application at "
puts y["oauth"]["site"]
puts "Tick the appropriate boxes"
puts "Enter the consumer key you are assigned:"
y["oauth"]["consumer_key"] = gets.strip
puts "Enter the consumer secret you are assigned:"
y["oauth"]["consumer_secret"] = gets.strip
puts "Your application is now set up, but you need to register"
puts "this instance of it with your user account."

@consumer=OAuth::Consumer.new y["oauth"]["consumer_key"],
                              y["oauth"]["consumer_secret"],
                              {:site=>y["oauth"]["site"]}

@request_token = @consumer.get_request_token

puts "Visit the following URL, log in if you need to, and authorize the app"
puts @request_token.authorize_url
puts "When you've authorized that token, enter the verifier code you are assigned:"
verifier = gets.strip
puts "Converting request token into access token..."
@access_token=@request_token.get_access_token(:oauth_verifier => verifier)

y["oauth"]["token"] = @access_token.token
y["oauth"]["token_secret"] = @access_token.secret

File.open('auth.yaml', 'w') {|f| YAML.dump(y, f)}

puts "Done. Have a look at auth.yaml to see what's there."
