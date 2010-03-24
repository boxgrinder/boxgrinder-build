#!/usr/bin/env ruby

# JBoss, Home of Professional Open Source
# Copyright 2009, Red Hat Middleware LLC, and individual contributors
# by the @authors tag. See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

require 'rubygems'

gem 'boxgrinder-core', '>= 0.0.3'
gem 'aws-s3', '>= 0.6.2'
gem 'amazon-ec2', '>= 0.9.6'
gem 'net-sftp', '>= 2.0.4'
gem 'net-ssh', '>= 2.0.20'
gem 'rake', '>= 0.8.7'

require 'boxgrinder-build/helpers/rake-helper'
require 'rake'

task :default do
  puts "Run '#{Rake.application.name} -T' to get list of all available commands."
end

BoxGrinder::RakeHelper.new( :version => "1.0.0.Beta2", :release => "SNAPSHOT" )

Rake.application.init('boxgrinder')
Rake.application.top_level
