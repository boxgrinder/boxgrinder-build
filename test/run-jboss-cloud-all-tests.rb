#!/usr/bin/env ruby 

require 'test/unit/ui/console/testrunner'
require 'test/unit'

$: << File.dirname("#{File.dirname( __FILE__ )}/../lib/jboss-cloud")

Dir.chdir( File.dirname( __FILE__ ) )

# tests to run
require 'jboss-cloud/validator/appliance-validator-test'
require 'jboss-cloud/validator/appliance-validator-jboss-cloud-test'
