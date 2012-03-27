# Introduction

This is example (but working) code for the algorithm for the
transition from CC-BY-SA to ODbL data. At this stage all the methods
are mocked out, but future development will add the ability to run
this against an `apidb` format database, or possibly a live API.

# Requirements

To run this, you'll need Ruby (probably >=1.9.3) and the 'text'
gem. Then you'll be able to run:

 `ruby test.rb`

which will run the full range of unit tests. The test files can also
be individually run to concentrate on some aspects of the suite.

# Test-Driven Development

This code is intended to be read as a test-driven development. It's
very hard to read most code when it implements a complex algorithm,
especially when it is expected to be read by anyone not fluent in the
language of choice (i.e: Ruby). In order to improve the
understandability of the code, this project is intended to be
test-driven, with well-commented tests to define the functionality.
Hopefully these tests *are* quite easy to read, without being a ruby
expert.

Tests can be found in the various files prefixed 'test_'. For example
tests_node.rb contains a set of tests to run just involving nodes,
and this is a good place to start. You'll find tests which describe
nodes being created, moved, and having tags changed by various users
 (license change agreers and disagreers in various combinations).
A test then the gives the expected resulting actions which a bot
should be deciding upon, to put the node in a clean state, and to
redact versions from the editing history.
