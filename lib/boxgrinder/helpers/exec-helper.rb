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

module BoxGrinder
  class ExecHelper
    def initialize( options = {} )
      @log = options[:log] || Logger.new(STDOUT)
    end

    def execute( command, file = nil )
      @log.debug "Executing command: '#{command}'"

      out = `#{command} 2>&1`

      formatted_output = "Command return:\r\n+++++\r\n#{out}+++++"

      if $?.to_i != 0
        @log.error formatted_output
        raise "An error occurred executing command: '#{command}'"
      else
        @log.debug formatted_output unless out.strip.length == 0
        @log.debug "Command '#{command}' executed successfully"
        return out
      end
    end
  end
end