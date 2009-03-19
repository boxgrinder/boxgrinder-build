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

require 'net/ssh'
require 'net/sftp'

module JBossCloud
  def compare_file_and_upload( sftp, file, remote_file )
    puts "File #{File.basename( file )}"
    
    begin
      rstat = sftp.stat!( remote_file )
    rescue Net::SFTP::StatusException => e
      raise unless e.code == 2
      upload_file( sftp, file, remote_file )
      rstat = sftp.stat!( remote_file )
    end
    
    if File.stat(file).mtime > Time.at(rstat.mtime) or File.size(file) != rstat.size
      upload_file( sftp, file, remote_file )
    else
      puts "File exists and is same as local, skipping..."
    end
  end
  
  def upload_file( sftp, local, remote )
    puts "Uploading file #{File.basename( local )} (#{File.size( local ) / 1024}kB)..."
    sftp.upload!(local, remote)
    sftp.setstat(remote, :permissions => 0644)
  end
  
  def create_directory_if_not_exists( sftp, ssh, path )
    begin
      sftp.stat!( path )
    rescue Net::SFTP::StatusException => e
      raise unless e.code == 2
      ssh.exec!( "mkdir -p #{path}" )
    end
  end
end