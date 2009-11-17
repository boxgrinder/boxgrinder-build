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

require 'boxgrinder/validator/errors'

module BoxGrinder
  class ReleaseHelper
    def initialize( config, options = {} )
      @config = config

      @log          = options[:log]         || LOG
      @exec_helper  = options[:exec_helper] || EXEC_HELPER

      define_tasks
    end

    def define_tasks
      task "appliance:upload:release" do
        validate_config
        build_and_upload_release
      end
    end

    def validate_config
      raise ValidationError, "No appliances selected for a release, see release/appliances section in your config file and/or appliance definition files." if @config.release.appliances.size == 0
    end

    def build_and_upload_release
      release_thread_group = ThreadGroup.new

      for appliance in @config.release.appliances
        Rake::Task[ "appliance:#{appliance}:package" ].invoke
        release_thread_group.add Thread.new { upload_release( appliance ) }
      end

      for thread in release_thread_group.list
        thread.join
      end
    end

    def upload_release( appliance )
      case @config.release.default_type
        when "ssh"
          Rake::Task[ "appliance:#{appliance}:upload:ssh" ].invoke
        when "cloudfront"
          Rake::Task[ "appliance:#{appliance}:upload:cloudfront" ].invoke
      end
    end
  end
end