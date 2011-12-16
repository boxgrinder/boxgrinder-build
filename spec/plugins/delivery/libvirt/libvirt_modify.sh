#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'optparse'

options = {}
OptionParser.new do |opts|

  opts.on("-d", "--domain STRING", String, :required, "Domain XML") do |v|
    options[:domain] = v
  end

end.parse!

doc = Nokogiri::XML(options[:domain])
doc.xpath('//devices/interface/@type').first.value = "br"
STDOUT.puts doc.to_s