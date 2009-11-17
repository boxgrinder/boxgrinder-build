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

require 'open4/open4'

def execute_command( cmd )
  return execute( cmd )
end

def execute(cmd, print_to_stdout = true, file_name = nil)
  old_trap = trap("INT") do
    puts "caught SIGINT, shutting down"
  end

  unless file_name.nil?

    if !File.exists?(File.dirname( file_name )) && !File.directory?(File.dirname( file_name ))
      FileUtils.mkdir_p File.dirname( file_name )
    end

    File.open(file_name, 'w') do |f|
      @exit_status = print_open4( cmd, print_to_stdout, f )
      f.flush
    end
  else
    @exit_status = print_open4( cmd, print_to_stdout )
  end

  trap("INT", old_trap )

  puts "\r\nCommand '#{cmd}' failed with exit status #{@exit_status.exitstatus}" unless @exit_status.success? if print_to_stdout
  
  return @exit_status.success?
end

def print_open4( cmd, print_to_stdout, f = nil )
  Open4.popen4( cmd ) do |pid, stdin, stdout, stderr|
    #stdin.close
    threads = []
    i = 0
    threads << Thread.new(stdout) do |input_str|
      while ( ( l = input_str.gets ) != nil )
        (i = print_to_file( f, l, i+1)) unless f == nil
        puts l if print_to_stdout
      end
    end
    threads << Thread.new(stderr) do |input_str|
      while ( ( l = input_str.gets ) != nil )
        (i = print_to_file( f, l, i+1)) unless f == nil
        puts l if print_to_stdout
      end
    end
    threads.each{|t|t.join}
  end
end

def print_to_file( f, l, i)
  # buffering - we will flush when the buffer has 10 lines
  lines_to_flush = 10

  unless f.nil?
    f.write l
    i += 1

    if i > lines_to_flush
      f.flush
      i = 0
    end
  end
  i
end