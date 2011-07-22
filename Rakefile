#
# Copyright 2010 Red Hat, Inc.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
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
require 'rspec/core/rake_task'
require 'echoe'

Echoe.new("boxgrinder-build") do |p|
  p.project = "BoxGrinder Build"
  p.author = "Marek Goldmann"
  p.summary = "A tool for creating appliances from simple plain text files for various virtual environments."
  p.url = "http://boxgrinder.org/"
  p.email = "info@boxgrinder.org"
  p.runtime_dependencies = [
      "boxgrinder-core ~>0.3.0",
      'aws-sdk', # EBS and S3
      'net-sftp', 'net-ssh', 'progressbar', # SFTP
      'rest-client' # ElasticHosts
  ]
end

desc "Run all integration tests"
RSpec::Core::RakeTask.new('integ') do |t|
  t.rcov = false
  t.pattern = "integ/**/*-spec.rb"
  t.rspec_opts = ['--colour', '--format', 'doc', '-b']
  t.verbose = true
end

desc "Run all tests"
RSpec::Core::RakeTask.new('spec') do |t|
  t.ruby_opts = "-I ../boxgrinder-core/lib"
  t.rcov = false
  t.pattern = "spec/**/*-spec.rb"
  t.rspec_opts = ['--colour', '--format', 'doc', '-b']
  t.verbose = true
end

desc "Run all tests and generate code coverage report"
RSpec::Core::RakeTask.new('spec:coverage') do |t|
  t.ruby_opts = "-I ../boxgrinder-core/lib"
  t.pattern = "spec/**/*-spec.rb"
  t.rspec_opts = ['--colour', '--format', 'html', '--out', 'pkg/rspec_report.html', '-b']
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec,teamcity/*,/usr/lib/ruby/,.gem/ruby,/boxgrinder-core/,/gems/']
  t.verbose = true
end
