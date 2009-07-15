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
require 'test/unit/ui/console/testrunner'
require 'test/unit'

$: << File.dirname("#{File.dirname( __FILE__ )}/../lib/jboss-cloud")

Dir.chdir( File.dirname( __FILE__ ) )

additional_libs = [ "amazon-ec2", "aws-s3", "net-ssh", "net-sftp", "highline", "htauth" ]

additional_libs.each do |lib|
  $LOAD_PATH.unshift( "../lib/#{lib}/lib" )
end

`chmod 600 src/aws/*`

require 'jboss-cloud/mock/log-mock'
require 'jboss-cloud/mock/exec-helper-mock'

require 'jboss-cloud/test-helpers/config-helper'

# tests to run
require 'jboss-cloud/validator/appliance-validator-test'
require 'jboss-cloud/validator/appliance-dependency-validator-test'
require 'jboss-cloud/validator/config-validator-test'

require 'jboss-cloud/config-test'
require 'jboss-cloud/appliance-config-test'

require 'jboss-cloud/appliance-vmware-image-test'
require 'jboss-cloud/appliance-kickstart-test'
require 'jboss-cloud/appliance-image-customize-test'
require 'jboss-cloud/appliance-image-test'

require 'jboss-cloud/aws/aws-support-test'
