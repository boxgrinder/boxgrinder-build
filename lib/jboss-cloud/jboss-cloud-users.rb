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

require 'rake'
require 'rake/tasklib'
require 'jboss-cloud/exec'
require 'yaml'

module JBossCloud
  class JBossCloudUsers < Rake::TaskLib
    def initialize( config, appliance_config )
      @config           = config
      @appliance_config   = appliance_config

      @jboss_cloud_users_spec_base_file   = "#{@config.dir.base}/specs/gsub/jboss-cloud-users.spec"
      @jboss_cloud_users_spec_file        = "#{@config.dir.top}/#{@config.os_path}/SPECS/jboss-cloud-#{@appliance_config.name}-users.spec"

      @appliance_definition               = YAML.load_file( "#{@config.dir_appliances}/#{@appliance_config.name}/#{@appliance_config.name}.appl" )

      define_tasks
    end

    def define_tasks
      task "rpm:jboss-cloud-#{@appliance_config.name}-users" => [ @jboss_cloud_users_spec_file ]

      file @jboss_cloud_users_spec_file => [ 'rpm:topdir' ] do
        create_jboss_cloud_users_spec_file
      end

      Rake::Task[ @jboss_cloud_users_spec_file ].invoke
    end

    def create_jboss_cloud_users_spec_file
      spec_data = File.open( @jboss_cloud_users_spec_base_file ).read
      users     = ""

      for user in @appliance_definition['users']
        users << "/usr/sbin/groupadd -r #{user['group']} 2>/dev/null || :\n" unless user['group'].nil?
        users <<  "/usr/sbin/useradd"
        users << " -d #{user['home']}" unless user['home'].nil?
        users << " -c \"#{user['comment']}\"" unless user['comment'].nil?
        users << " -g #{user['group']}" unless user['group'].nil?
        users << " #{user['name']}\n"
      end unless @appliance_definition['users'].nil?

      spec_data.gsub!( /#APPLIANCE_NAME#/, @appliance_config.name )
      spec_data.gsub!( /#USERS#/, users )

      File.open( @jboss_cloud_users_spec_file, "w") {|f| f.write( spec_data ) }
    end
  end
end