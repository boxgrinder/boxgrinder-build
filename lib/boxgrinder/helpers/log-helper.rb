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

require 'logger'

module BoxGrinder
  class LogHelper
    THRESHOLDS = {
            :fatal  => Logger::FATAL,
            :debug  => Logger::DEBUG,
            :error  => Logger::ERROR,
            :warn   => Logger::WARN,
            :info   => Logger::INFO
    }

    def initialize
      threshold = ENV['BG_LOG_THRESHOLD']
      threshold = THRESHOLDS[threshold.to_sym] unless threshold.nil?

      @stdout_log         = Logger.new(STDOUT)
      @stdout_log.level   = threshold || Logger::INFO

      @file_log           = Logger.new('boxgrinder.log') # , 10, 1024000
      @file_log.level     = Logger::DEBUG
    end

    def method_missing( method_name, *args )
      if THRESHOLDS.keys.include?( method_name )
        @stdout_log.send( method_name, args )
        @file_log.send( method_name, args )
      else
        raise NoMethodError
      end
    end
  end
end