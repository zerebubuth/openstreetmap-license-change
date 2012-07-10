# Testing against an API

As well as testing the functionality of the core bot, you can now test behaviour against an API.

The primary script for doing so it run_bot.py, but before that we'll need a few setup steps.

# auth.yml

Copy example.auth.yaml to auth.yaml . It contains three sections, representing the three resources needed by the script.

In the database section, provide postgres access credentials to the API database. This can be a read-only connection, if you like, since it's only used for fetching data.
In the tracker section, provide postgres access credentials to a tracking database. It can just be an empty database, on a different machine, and we'll set it up later
In the oauth section, provide the URL to the API server. We'll fill in the rest later.

# Filling the API database

If your rails_port is empty, you can fill it from a .osh history extract file using extract_loader.rb

# Setting up the tracker database

We use a tracker database to coordinate bot instances, and keep track of what entities we need to process. We set this up in two stages

## Setting up the regions

Run run_regions.rb . It parses bounds.xml and populates the table with 64,000 regions in the order we want to process them. When a region is marked as "processing" other bots will keep clear, to minimise conflicts.

## Setting up the candidate

Technically we can run the bot over every entity in the database, but that's pointless for almost every entity. Run run_candidates.rb to examine the database and record which entities may need examining when the bot actually runs. This will contain about 18 million rows for the real database, less if you're using an extract. You can tweak the source to just select all the entities in the database, if you wish.

# Getting API credentials (OAuth)

In order to run the bot, you need credentials for a *moderator* account on your rails API. When you have this set up, register a new OAuth application on the site, and then run get_auth.rb and follow the instructions. This will add the application and access tokens to auth.yaml

# Running the bot

With all the above set up, you should be able to run the bot.

./run_bot.rb -v

It will pick the first region off of the list, and run it. That region might have no data if your extract doesn't cover that area. Use the -i flag to ignore the regions, which is needed in the "second pass" in order to process floating relations and some super-relations not returned in map calls. Note that with the -i flag, it will only process a certain number of candidates at a time

To complete a large extract, you'll need to run the bot multiple times, or multiple copies in parallel.