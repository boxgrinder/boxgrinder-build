#
# Copyright 2010 Red Hat, Inc.
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

require 'libvirt'
require 'enumerator'
require 'nokogiri'
require 'ostruct'

module BoxGrinder
  class LibvirtCapabilities

    class Domain
     include Comparable
     attr_accessor :name, :bus, :virt_rank, :virt_map
     def initialize(name, bus, virt_rank)
       @name = name
       @bus = bus
       @virt_rank = virt_rank.freeze
       @virt_map = virt_rank.enum_for(:each_with_index).inject({}) do |accum, (virt, rank)|
         accum.merge(virt => rank)
       end
     end

     def <=>(other)
       self.name <=> other.name
     end
    end

    class Plugin
      include Comparable
      attr_accessor :name, :domain_rank, :domain_map
      def initialize(name, domain_rank)
        @name = name
        @domain_map = domain_rank.enum_for(:each_with_index).inject({}) do |accum, (domain, rank)|
          accum.merge(domain.name => {:domain => domain, :rank => rank})
        end
        @domain_map.freeze
        @domain_rank = domain_rank.freeze
      end

      def <=>(other)
       self.name <=> other.name
      end
    end

    # Arrays are populated in order of precedence. Best first.
    DEFAULT_DOMAIN_MAPPINGS = {
      :xen =>  { :bus => :xen, :virt_rank => [:xen, :linux, :hvm] },
      :kqemu => { :bus => :virtio, :virt_rank => [:hvm] },
      :kvm => { :bus => :virtio, :virt_rank => [:xen, :linux, :hvm] },
      :qemu => { :bus => :ide, :virt_rank => [:xen, :linux, :hvm] },
      :vbox => { :bus => :virtio, :virt_rank => [:hvm] },
      :vmware => { :bus => :ide, :virt_rank => [:hvm] }
    }

    PLUGIN_MAPPINGS = {
      :default => { :domain_rank => [:kvm, :xen, :kqemu, :qemu] },
      :virtualbox => { :domain_rank => [:vbox] },
      :xen => { :domain_rank => [:xen] },
      :citrix => { :domain_rank => [:xen] },
      :kvm => { :domain_rank => [:kvm] },
      :vmware => { :domain_rank => [:vmware] },
      :ec2 => { :domain_rank => [:xen, :qemu] }
    }

    DOMAINS = DEFAULT_DOMAIN_MAPPINGS.inject({}) do |accum, mapping|
      accum.merge(mapping.first => Domain.new(mapping.first, mapping.last[:bus], mapping.last[:virt_rank]))
    end

    PLUGINS = PLUGIN_MAPPINGS.inject({}) do |accum, mapping|
      d_refs = mapping.last[:domain_rank].collect{|d| DOMAINS[d]}
      accum.merge(mapping.first => Plugin.new(mapping.first, d_refs))
    end

    def initialize(opts={})
      @log = opts[:log] || LogHelper.new
    end

    # Connect to the remote machine and determine the best available settings
    def determine_capabilities(conn, previous_plugin_info)
      plugin = get_plugin(previous_plugin_info)
      root = Nokogiri::XML.parse(conn.capabilities)
      guests = root.xpath("//guest/arch[@name='x86_64']/..")

      guests = guests.sort do |a, b|
        dom_maps = [a,b].map { |x| plugin.domain_map[xpath_first_intern(x, './/domain/@type')] }

        # Handle unknown mappings
        next resolve_unknowns(dom_maps) if dom_maps.include?(nil)

        # Compare according to domain ranking
        dom_rank = dom_maps.map { |m| m[:rank]}.reduce(:<=>)

        # Compare according to virtualisation ranking
        virt_rank = [a,b].enum_for(:each_with_index).map do |x, i|
          dom_maps[i][:domain].virt_map[xpath_first_intern(x, './/os_type')]
        end

        # Handle unknown mappings
        next resolve_unknowns(virt_rank) if virt_rank.include?(nil)

        # Domain rank first
        next dom_rank unless dom_rank == 0

        # OS type rank second
        virt_rank.reduce(:<=>)
      end
      # Favourite!
      build_guest(guests.first)
    end

    def resolve_unknowns(pair)
      return 0 if pair.first.nil? and pair.last.nil?
      return 1 if pair.first.nil?
      -1 if pair.last.nil?
    end

    def build_guest(xml)
      dom = DOMAINS[xpath_first_intern(xml, ".//domain/@type")]
      bus = 'ide'
      bus = dom.bus if dom

      OpenStruct.new({
        :domain_type => xpath_first_intern(xml, ".//domain/@type"),
        :os_type => xpath_first_intern(xml, './/os_type'),
        :bus => bus
      })
    end

    def xpath_first_intern(xml, path)
      xml.xpath(path).first.text.intern
    end

    # At present we don't have enough meta-data to work with to easily generalise,
    # so we have to assume defaults often. This is something to improve later.
    def get_plugin(previous_plugin_info)
      if previous_plugin_info[:type] == :platform
        if PLUGINS.has_key?(previous_plugin_info[:name])
          @log.debug("Using #{previous_plugin_info[:name]} mapping")
          return PLUGINS[previous_plugin_info[:name]]
        else
          @log.debug("This plugin does not know what mappings to choose, so will assume default values where user values are not provided.")
        end
      end
      @log.debug("Using default domain mappings.")
      PLUGINS[:default]
    end
  end
end