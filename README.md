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
language of choice (i.e: Ruby).

In order to improve the understandability of the code, this project is
intended to be test-driven, with well-commented tests to define the
functionality.
