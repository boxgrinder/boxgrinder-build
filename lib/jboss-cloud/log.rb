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

module JBossCloud
  class Log
    def initialize
      treshold = ENV['JBOSS_CLOUD_LOG_THRESHOLD']

      unless treshold.nil?
        case treshold
          when "fatal"
            treshold = Logger::FATAL
          when "debug"
            treshold = Logger::DEBUG
          when "error"
            treshold = Logger::ERROR
          when "warn"
            treshold = Logger::WARN
          when "info"
            treshold = Logger::INFO
        end
      end

      @stdout_log         = Logger.new(STDOUT)
      @stdout_log.level   = treshold || Logger::INFO

      @file_log           = Logger.new('jboss-cloud.log', 10, 1024000)
      @file_log.level     = Logger::DEBUG
    end

    def debug( msg )
      @stdout_log.debug( msg )
      @file_log.debug( msg )
    end

    def info( msg )
      @stdout_log.info( msg )
      @file_log.info( msg )
    end

    def warn( msg )
      @stdout_log.warn( msg )
      @file_log.warn( msg )
    end

    def error( msg )
      @stdout_log.error( msg )
      @file_log.error( msg )
    end

    def fatal( msg )
      @stdout_log.fatal( msg )
      @file_log.fatal( msg )
    end

    def raise( error, msg )

    end

  end
end