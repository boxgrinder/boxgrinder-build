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

require 'boxgrinder-build/plugins/base-plugin'
require 'boxgrinder-build/plugins/delivery/libvirt/libvirt-capabilities'
require 'boxgrinder-build/helpers/sftp-helper'

require 'libvirt'
require 'net/sftp'
require 'fileutils'
require 'uri'
require 'etc'
require 'builder'
require 'ostruct'

module BoxGrinder

  # @plugin_config [String] connection_uri Libvirt endpoint address. If you are
  #   using authenticated transport such as +ssh+ you should register your keys with
  #   an ssh agent. See: {http://libvirt.org/uri.html Libvirt Connection URIs}.
  #   * Default: +empty string+
  #   * Examples: <tt>qemu+ssh://user@example.com/system</tt>
  #   * +qemu:///system+
  #
  # @plugin_config [String] image_delivery_uri Where to deliver the image to. This must be a
  #   local path or an SFTP address. The local ssh-agent is used for keys if available.
  #   * Default: +/var/lib/libvirt/images+
  #   * Examples: +sftp\://user@example.com/some/path+
  #   * +sftp\://user:pass@example.com/some/path+ It is advisable to use keys with ssh-agent.
  #
  # @plugin_config [String] libvirt_image_uri Where the image will be on the Libvirt machine.
  #   * Default: +image_delivery_uri+ _path_ element.
  #   * Example: +/var/lib/libvirt/images+
  #
  # @plugin_config [Int] default_permissions Permissions of delivered image. Examples:
  #   * Default: +0770+
  #   * Examples: +0755+, +0775+
  #
  # @plugin_config [Int] overwrite Overwrite any identically named file at the delivery path.
  #   Also undefines any existing domain of the same name.
  #   * Default: +false+
  #
  # @plugin_config [String] script Path to user provided script to modify XML before registration
  #   with Libvirt. Plugin passes the raw XML, and consumes stdout to use as revised XML document.
  #
  # @plugin_config [Bool] remote_no_verify Disable certificate verification procedures
  #   * Default: +true+
  #
  # @plugin_config [Bool] xml_only Do not connect to the Libvirt hypervisor, just assume sensible
  #   defaults where no user values are provided, and produce the XML domain.
  #   * Default: +false+
  #
  # @plugin_config [String] appliance_name Name for the appliance to be registered as in Libvirt.
  #   At present the user can only specify literal strings.
  #   * Default: +name-version-release-os_name-os_version-arch-platform+
  #   * Example: +boxgrinder-f16-rocks+
  #
  # @plugin_config [String] domain_type Libvirt domain type.
  #   * Default is a calculated value. Unless you are using +xml_only+ the remote instance will
  #     be contacted and an attempt to determine the best value will be made. If +xml_only+
  #     is set then a safe pre-determined default is used. User-set values take precedence.
  #     See _type_: {http://libvirt.org/formatdomain.html#elements Domain format}
  #   * Examples: +qemu+, +kvm+, +xen+
  #
  # @plugin_config [String] virt_type Libvirt virt type.
  #   * Default is a calculated value. Where available paravirtual is preferred.
  #     See _type_: {http://libvirt.org/formatdomain.html#elementsOSBIOS BIOS bootloader}.
  #   * Examples: +hvm+, +xen+, +linux+
  #
  # @plugin_config [String] bus Disk bus.
  #   * Default is a pre-determined value depending on the domain type. User-set values take
  #     precedence
  #   * Examples: +virtio+, +ide+
  #
  # @plugin_config [String] network Network name. If you require a more complex setup
  #   than a simple network name, then you should create and set a +script+.
  #   * Default: +default+
  class LibvirtPlugin < BasePlugin

    plugin :type => :delivery, :name => :libvirt, :full_name => "libvirt Virtualisation API"

    def set_defaults
      set_default_config_value('connection_uri', '')
      set_default_config_value('script', false)
      set_default_config_value('image_delivery_uri', '/var/lib/libvirt/images')
      set_default_config_value('libvirt_image_uri', false)
      set_default_config_value('remote_no_verify', true)
      set_default_config_value('overwrite', false)
      set_default_config_value('default_permissions', 0770)
      set_default_config_value('xml_only', false)
      # Manual overrides
      set_default_config_value('appliance_name', [@appliance_config.name, @appliance_config.version, @appliance_config.release,
                                                  @appliance_config.os.name, @appliance_config.os.version, @appliance_config.hardware.arch,
                                                  current_platform].join("-"))
      set_default_config_value('domain_type', false)
      set_default_config_value('virt_type', false)
      set_default_config_value('bus', false)
      set_default_config_value('network', 'default')
      set_default_config_value('mac', false)
      set_default_config_value('noautoconsole', false)

      libvirt_code_patch
    end

    def validate
      set_defaults

      ['connection_uri', 'xml_only', 'network', 'domain_type', 'virt_type', 'script',
       'bus', 'appliance_name', 'default_permissions', 'overwrite', 'noautoconsole',
      'mac'].each do |v|
        self.instance_variable_set(:"@#{v}", @plugin_config[v])
      end

      @libvirt_capabilities = LibvirtCapabilities.new(:log => @log)
      @image_delivery_uri = URI.parse(@plugin_config['image_delivery_uri'])
      @libvirt_image_uri = (@plugin_config['libvirt_image_uri'] || @image_delivery_uri.path)

      @remote_no_verify = @plugin_config['remote_no_verify'] ? 1 : 0

      (@connection_uri.include?('?') ? '&' : '?') + "no_verify=#{@remote_no_verify}"
      @connection_uri = URI.parse(@plugin_config['connection_uri'])
    end

    def execute
      if @image_delivery_uri.scheme =~ /sftp/
        @log.info("Transferring file via SFTP...")
        upload_image
      else
        @log.info("Copying disk #{@previous_deliverables.disk} to: #{@image_delivery_uri.path}...")
        FileUtils.cp(@previous_deliverables.disk, @image_delivery_uri.path)
      end

      if @xml_only
        @log.info("Determining locally only.")
        xml = determine_locally
      else
        @log.info("Determining remotely.")
        xml = determine_remotely
      end
      write_xml(xml)
    end

    # Interact with a libvirtd, attempt to determine optimal settings where possible.
    # Register the appliance as a new domain.
    def determine_remotely
      # Remove password field from URI, as libvirt doesn't support it directly. We can use it for passphrase if needed.
      lv_uri = URI::Generic.build(:scheme => @connection_uri.scheme, :userinfo => @connection_uri.user,
                                  :host => @connection_uri.host, :path => @connection_uri.path,
                                  :query => @connection_uri.query)

      # The authentication only pertains to libvirtd itself and _not_ the transport (e.g. SSH).
      conn = Libvirt::open_auth(lv_uri.to_s, [Libvirt::CRED_AUTHNAME, Libvirt::CRED_PASSPHRASE]) do |cred|
        case cred["type"]
          when Libvirt::CRED_AUTHNAME
            @connection_uri.user
          when Libvirt::CRED_PASSPHRASE
            @connection_uri.password
        end
      end

      if dom = get_existing_domain(conn, @appliance_name)
        unless @overwrite
          @log.fatal("A domain already exists with the name #{@appliance_name}. Set overwrite:true to automatically destroy and undefine it.")
          raise RuntimeError, "Domain '#{@appliance_name}' already exists"  #Make better specific exception
        end
        @log.info("Undefining existing domain #{@appliance_name}")
        undefine_domain(dom)
      end

      guest = @libvirt_capabilities.determine_capabilities(conn, @previous_plugin_info)

      raise "Remote libvirt machine offered no viable guests!" if guest.nil?

      xml = generate_xml(guest)
      @log.info("Defining domain #{@appliance_name}")
      conn.define_domain_xml(xml)
      xml
    ensure
      if conn
        conn.close unless conn.closed?
      end
    end

    # Make no external connections, just dump a basic XML skeleton and provide sensible defaults
    # where user provided values are not given.
    def determine_locally
      domain = @libvirt_capabilities.get_plugin(@previous_plugin_info).domain_rank.last
      generate_xml(OpenStruct.new({
        :domain_type => domain.name,
        :os_type => domain.virt_rank.last,
        :bus => domain.bus
      }))
    end

    # Upload an image via SFTP
    def upload_image
      uploader = SFTPHelper.new(:log => @log)

      #SFTP library automagically uses keys registered with the OS first before trying a password.
      uploader.connect(@image_delivery_uri.host,
      (@image_delivery_uri.user || Etc.getlogin),
      :password => @image_delivery_uri.password)

      uploader.upload_files(@image_delivery_uri.path,
                            @default_permissions,
                            @overwrite,
                            File.basename(@previous_deliverables.disk) => @previous_deliverables.disk)
    ensure
      uploader.disconnect if uploader.connected?
    end

    # Preferentially choose user settings
    def generate_xml(guest)
      build_xml(:domain_type => (@domain_type || guest.domain_type),
                :os_type => (@virt_type || guest.os_type),
                :bus => (@bus || guest.bus))
    end

    # Build the XML domain definition. If the user provides a script, it will be called after
    # the basic definition has been constructed with the XML as the sole parameter. The output
    # from stdout of the script will be used as the new domain definition.
    def build_xml(opts = {})
      opts = {:bus => @bus, :os_type => :hvm}.merge!(opts)

      builder = Builder::XmlMarkup.new(:indent => 2)

      xml = builder.domain(:type => opts[:domain_type].to_s) do |domain|
        domain.name(@appliance_name)
        domain.description(@appliance_config.summary)
        domain.memory(@appliance_config.hardware.memory * 1024) #KB
        domain.vcpu(@appliance_config.hardware.cpus)
        domain.os do |os|
          os.type(opts[:os_type].to_s, :arch => @appliance_config.hardware.arch)
          os.boot(:dev => 'hd')
        end
        domain.devices do |devices|
          devices.disk(:type => 'file', :device => 'disk') do |disk|
            disk.source(:file => "#{@libvirt_image_uri}/#{File.basename(@previous_deliverables.disk)}")
            disk.target(:dev => 'hda', :bus => opts[:bus].to_s)
          end
          devices.interface(:type => 'network') do |interface|
            interface.source(:network => @network)
            interface.mac(:address => @mac) if @mac
          end
          devices.console(:type => 'pty') unless @noautoconsole
          devices.graphics(:type => 'vnc', :port => -1) unless @novnc
        end
        domain.features do |features|
          features.pae if @appliance_config.os.pae
        end
      end
      @log.debug xml

      # Let the user modify the XML specification to their requirements
      if @script
        @log.info "Attempting to run user provided script for modifying libVirt XML..."
        xml = IO::popen("#{@script} --domain '#{xml}'").read
        @log.debug "Response was: #{xml}"
      end
      xml
    end

    private

    # Look up a domain by name
    def get_existing_domain(conn, name)
      return conn.lookup_domain_by_name(name)
    rescue Libvirt::Error => e
      return nil if e.libvirt_code == 42 # If domain not defined
      raise # Otherwise reraise
    end

    # Undefine a domain. The domain will be destroyed first if required.
    def undefine_domain(dom)
      case dom.info.state
        when Libvirt::Domain::RUNNING, Libvirt::Domain::PAUSED, Libvirt::Domain::BLOCKED
          dom.destroy
      end
      dom.undefine
    end

    # Libvirt library in older version of Fedora provides no way of getting the
    # libvirt_code for errors, this patches it in.
    def libvirt_code_patch
      return if Libvirt::Error.respond_to?(:libvirt_code, false)
      Libvirt::Error.module_eval do
        def libvirt_code; @libvirt_code end
      end
    end

    # Write domain XML to file
    def write_xml(xml)
      fname = "#{@appliance_name}.xml"
      File.open("#{@dir.tmp}/#{fname}", 'w'){|f| f.write(xml)}
      register_deliverable(:xml => fname)
    end
  end
end