#
# Copyright 2012 Red Hat, Inc.
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

require 'fileutils'
require 'set'

module BoxGrinder
  class FSObserver
    attr_accessor :path_set
    attr_accessor :filter_set

    # @param [Integer] user The uid to switch from root to
    # @param [Integer] group The gid to switch from root to
    # @param [Hash] opts The options to create a observer with
    # @option opts [Array<String>] :paths Additional paths to change
    #   ownership of.
    # @option opts [String] :paths Additional path to to change
    # ownership of
    def initialize(user, group, opts={})
      @path_set = Set.new(Array(opts[:paths]))
      # Filter some default directories, plus any subdirectories of
      # paths we discover at runtime
      @filter_set = Set.new([%r(^/(etc|dev|sys|bin|sbin|etc|lib|lib64|boot|run|proc|selinux|tmp)(/|$))])
      @user = user
      @group = group
    end

    # Receives updates from FSMonitor#add_path
    #
    # @param [Hash] opts The options to update the observer
    # @option opts [:symbol] :command The command to instruct the
    #   observer to execute.
    #   * +:add_path+ Indicates the +:data+ field contains a path.
    #   * +:stop_capture+ indicates that capturing has ceased. The
    #       observer will change ownership of the files, and switch
    #       to the user specified at #initialize.
    # @option opts [String] :data Contains a resource path when the 
    #   * +:add_path+ Command is called, otherwise ignored.  
    def update(update={})
      case update[:command]
        when :add_path
          unless match_filter?(update[:data])
            @path_set.add(update[:data])
            @filter_set.merge(subdirectory_regex(update[:data]))
          end
        when :stop_capture, :chown
          do_chown
      end
    end

    private

    def do_chown
      @path_set.each do |p| 
        FileUtils.chown_R(@user, @group, p, :force => true) if File.exist?(p)
      end
    end

    def match_filter?(path)
      @filter_set.inject(false){ |accum, filter| accum || !!(path =~ filter) }
    end

    def subdirectory_regex(paths)
      Array(paths).collect{ |p| Regexp.new("^#{p}/") }
    end
  end
end
