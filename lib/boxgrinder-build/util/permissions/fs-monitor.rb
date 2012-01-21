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

require 'thread'
require 'observer'
require 'pathname'
require 'singleton'

require 'boxgrinder-build/util/concurrent/get_set'

module BoxGrinder
  class FSMonitor
    include Singleton
    include Observable

    def initialize
      @flag = GetSet.new
      @lock_a = Mutex.new
      @lock_b = Mutex.new
      set_hooks
    end

    # Start capturing paths. Providing a block automatically stops the
    # capture process upon termination of the scope.
    #
    # @param Array<#update> Observers to be notified of capture
    #   events. Each observer should expect a hash{} containing a
    #   +:command+, and potentially +:data+.
    #
    # @yield Block that automatically calls #stop at the end of scope
    #   to cease capture.
    def capture(*observers, &block)
      @lock_a.synchronize do
        add_observers(observers)
        _capture(&block)

        if block_given?
          yield
          _stop
        end
      end
    end

    # Explicitly stop capturing paths. This should be utilised if
    # capture was not used with a block. Fires the +:stop_capture+
    # command to indicate that capturing has ceased.
    def stop
      @lock_a.synchronize { _stop }
    end

    # Stop any capturing and delete all observers. Useful for testing.
    # @see #stop
    def reset
      @lock_a.synchronize do
        _stop
        delete_observers
      end
    end

    # Add a path string. Called by the hooked methods when an
    # applicable action is triggered and capturing is enabled. Fires
    # the +:add_path+ command, and includes the full path as +:data+.
    #
    # If no observers have been assigned before a path is added, they
    # will be silently lost.
    #
    # @param [String] path Filesystem path.
    # @return [Boolean] False if no observers were present.
    def add_path(path)
      @lock_b.synchronize do
        changed(true)
        notify_observers(:command => :add_path, :data => realpath(path))
      end
    end

    # Trigger ownership change immediately, but without ceasing. Fires
    # the +:chown+ command on all observers.
    # 
    # @return [boolean] False if no observers were present.
    def trigger
      changed(true)
      notify_observers(:command => :chown)
    end

    private # Not threadsafe

    # The hooks will all use the same get-and-set to determine when to
    # begin/cease capturing paths.
    def _capture
      @flag.get_set(true)
    end
    
    def _stop
      @flag.get_set(false)
      changed(true)
      notify_observers(:command => :stop_capture)
    end

    # Hooks to capture any standard file, link or directory creation. Other
    # methods (e.g. FileUtils#mkdir_p, FileUtils#move), ultimately bottom out
    # into these primitive functions.
    def set_hooks
      # Final splat var captures any other variables we are not interested in,
      # and avoids them being squashed into the final var.
      eigen_capture(File, [:open, :new], @flag) do |klazz, path, mode, *other|
        add_path(path) if klazz == File && mode =~ /^(t|b)?((w|a)[+]?)(t|b)?$/
      end

      eigen_capture(File, [:rename, :symlink, :link], @flag) do |klazz, old, new, *other|
        add_path(new)
      end

      eigen_capture(Dir, :mkdir, @flag) do |klazz, path, *other|
        add_path(root_dir(path))
      end
    end

    # Hooks into class methods by accessing the eigenclass (virtual class).
    def eigen_capture(klazz, m_sym, flag, &blk)
      v_klazz = (class << klazz; self; end)
      instance_capture(v_klazz, m_sym, flag, &blk)
    end

    def instance_capture(klazz, m_sym, flag, &blk)
      Array(m_sym).each{ |sym| alias_and_capture(klazz, sym, flag, &blk) }
    end

    # Cracks open the target class, and injects a wrapper to enable
    # monitoring. By aliasing the original method the wrapper intercepts the
    # call, which it forwards onto the 'real' method before executing the hook.
    #
    # The hook's functionality is provided via a &block, which is passed the
    # caller's +self+ in addition to the wrapped method's parameters.
    #
    # Locking the +flag+ signals the hook to begin capturing.
    def alias_and_capture(klazz, m_sym, flag, &blk)
      alias_m_sym = "__alias_#{m_sym}"

      klazz.class_eval do
        alias_method alias_m_sym, m_sym

        define_method(m_sym) do |*args, &blx|
         response = send(alias_m_sym, *args, &blx)
           blk.call(self, *args) if flag.get_set
         response
        end
      end
    end

    def add_observers(observers)
      observers.each{ |o| add_observer(o) unless o.nil? }
    end

    # Transform relative to absolute path
    def realpath(path)
      Pathname.new(path).realpath.to_s
    end

    # For a path relative such as 'x/y/z' returns 'x'. Useful for #mkdir_p
    # where the entire new path is returned at once.
    def root_dir(relpath)
      r = relpath.match(%r(^[/]?.+?[/$]))
      return relpath if r.nil?
      r[0] || relpath
    end
  end
end
