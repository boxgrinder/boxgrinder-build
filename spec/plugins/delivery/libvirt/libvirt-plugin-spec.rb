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

require 'boxgrinder-build/plugins/delivery/libvirt/libvirt-plugin'

module BoxGrinder
  describe LibvirtPlugin do

    def prepare_plugin
      @plugin = LibvirtPlugin.new

      @config = Config.new('plugins' => { 'libvirt' => {}})

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade[{:build => 'build/path'}])
      @appliance_config.stub!(:name).and_return('appliance')
      @appliance_config.stub!(:summary).and_return('boxgrinder-rocks')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade[{:name => :fedora, :version => '13'}])
      @appliance_config.stub!(:hardware).and_return(OpenCascade[{:arch => 'x86_64', :memory => 256, :cpu => 5}])

      @previous_plugin_info = OpenCascade[:type => :os, :deliverables => {:disk => "/flo/bble.raw", :metadata => 'metadata.xml'}]
      @libvirt_capabilities = mock('libvirt_capabilities').as_null_object
      @log = mock('logger').as_null_object

      @plugin = RSpecPluginHelper.new(LibvirtPlugin).prepare(@config, @appliance_config,
        :previous_plugin => @previous_plugin_info,
        :plugin_info => {:class => BoxGrinder::LibvirtPlugin, :type => :delivery, :name => :libvirt, :full_name => "libvirt Virtualisation API"}
      ) { |plugin| yield plugin, @config.plugins['libvirt'] if block_given? }

      @plugin.instance_variable_set(:@libvirt_capabilities, @libvirt_capabilities)
      @plugin.instance_variable_set(:@log, @log)
    end

    describe ".execute" do
      it "should upload disk via sftp" do
        prepare_plugin do |p, c|
          c['image_delivery_uri'] = 'sftp://root@example.com/boxgrinder/images'
          p.stub!(:determine_remotely)
          p.stub!(:write_xml)
        end
        @plugin.should_receive(:upload_image)
        @plugin.execute
      end

      it "should copy disk locally when not sftp" do
        prepare_plugin do |p, c|
          c['image_delivery_uri'] = '/bacon/butties'
          p.stub!(:determine_remotely)
          p.stub!(:write_xml)
        end
        FileUtils.should_receive(:cp).with('/flo/bble.raw', '/bacon/butties')
        @plugin.execute
      end

      it "should determine xml locally when xml_only is set" do
        prepare_plugin do |p, c|
          c['image_delivery_uri'] = '/stottie/cake'
          c['xml_only'] = 'true'
          p.stub!(:write_xml)
        end
        FileUtils.should_receive(:cp).with('/flo/bble.raw', '/stottie/cake')
        @plugin.should_receive(:determine_locally).and_return('xml')
        @plugin.execute
      end

      it "should write the xml to file after generating it" do
        prepare_plugin do |p, c|
          c['xml_only'] = 'true'
          FileUtils.stub!(:cp)
          p.stub!(:determine_locally).and_return('xml')
        end
        @plugin.should_receive(:write_xml).with('xml')
        @plugin.execute
      end
    end

    describe ".determine_remotely" do
      before(:each) do
        @conn = mock('conn').as_null_object
        @conn.stub!(:closed?).and_return(false)
        @guest = mock('guest').as_null_object
        @domain = mock('domain').as_null_object
      end

      context "uri handling" do
        it "should handle and connect to the default empty uri" do
          prepare_plugin do |p, c|
            p.stub!(:get_existing_domain).and_return(false)
            p.stub!(:generate_xml)
          end

          Libvirt.should_receive(:open_auth).
              with('',  [Libvirt::CRED_AUTHNAME, Libvirt::CRED_PASSPHRASE]).
              and_return(@conn)

          @plugin.determine_remotely
        end

        it "should remove the password element from the userinfo, as libvirt does not support this" do
          prepare_plugin do |p, c|
            c['connection_uri'] = 'qemu+ssh://user:PASSWORD@example.com/system'
            p.stub!(:get_existing_domain).and_return(false)
            p.stub!(:generate_xml)
          end

          # Note that the password field should have been removed!
          Libvirt.should_receive(:open_auth).
              with('qemu+ssh://user@example.com/system',  [Libvirt::CRED_AUTHNAME, Libvirt::CRED_PASSPHRASE]).
              and_return(@conn)

          @plugin.determine_remotely
        end

        it "should re-construct scheme, userinfo, host, path, query in uri" do
          prepare_plugin do |p, c|
            c['connection_uri'] = 'qemu+ssh://user:pass@example.com/system?some_elem=1&other=2'
            p.stub!(:get_existing_domain).and_return(false)
            p.stub!(:generate_xml)
          end

          Libvirt.should_receive(:open_auth).
              with('qemu+ssh://user@example.com/system?some_elem=1&other=2',  [Libvirt::CRED_AUTHNAME, Libvirt::CRED_PASSPHRASE]).
              and_return(@conn)

          @plugin.determine_remotely
        end
      end

      context "there is an existing domain" do
        it "should raise an error if a domain already exists" do
          prepare_plugin do |p, c|
            p.stub!(:get_existing_domain).and_return(@domain)
            p.stub!(:generate_xml)
            Libvirt.stub!(:open_auth).and_return(@conn)
          end

          lambda{ @plugin.determine_remotely }.should raise_error(RuntimeError)
        end

        it "should undefine the domain if overwrite is set, and domain exists" do
          prepare_plugin do |p, c|
            c['overwrite'] = true
            p.stub!(:get_existing_domain).and_return(@domain)
            p.stub!(:generate_xml)
            Libvirt.stub!(:open_auth).and_return(@conn)
          end

          @plugin.should_receive(:undefine_domain).with(@domain)
          @plugin.determine_remotely
        end
      end

      context "capabilities" do
        let(:capabilities){ mock('capabilities') }
        let(:capability_xml){ mock('capability_xml') }

        it "should determine capabilities" do
          prepare_plugin do |p, c|
            p.stub!(:get_existing_domain).and_return(false)
            p.stub!(:generate_xml)
            Libvirt.stub!(:open_auth).and_return(@conn)
          end
          capabilities.stub!(:nil?).and_return(false)

          @libvirt_capabilities.should_receive(:determine_capabilities).
              with(@conn, {}).and_return(capabilities)
          @plugin.determine_remotely
        end

        it "should request xml using derived capabilities" do
          prepare_plugin do |p, c|
            p.stub!(:get_existing_domain).and_return(false)
            Libvirt.stub!(:open_auth).and_return(@conn)
          end

          @libvirt_capabilities.stub!(:determine_capabilities).
            and_return(capabilities)

          @plugin.should_receive(:generate_xml).with(capabilities)
          @plugin.determine_remotely
        end

        it "should define the domain with capabilities generated xml" do
          prepare_plugin do |p, c|
            p.stub!(:get_existing_domain).and_return(false)
            p.stub!(:generate_xml).and_return(capability_xml)
            Libvirt.stub!(:open_auth).and_return(@conn)
          end

          @libvirt_capabilities.stub!(:determine_capabilities).
            and_return(capabilities)

          @conn.should_receive(:define_domain_xml).with(capability_xml)
          @plugin.determine_remotely
        end
      end
    end

    describe ".determine_locally" do
      let(:domain){ mock('domain') }
      let(:plugin){ mock('plugin').as_null_object }

      it "should look up static capabilities by getting safest ranked domain" do
        prepare_plugin do |p, c|
          @libvirt_capabilities.stub!(:get_plugin).and_return(plugin)
          plugin.stub_chain(:domain_rank, :last).and_return(domain)
          # Values, as would be returned by a domain object
          domain.stub!(:name).and_return('d')
          domain.stub_chain(:virt_rank, :last).and_return('o')
          domain.stub!(:bus).and_return('n')
        end

        @plugin.should_receive(:generate_xml).with(OpenStruct.new({
        :domain_type => 'd',
        :os_type => 'o',
        :bus => 'n'
        }))
        @plugin.determine_locally
      end
    end

    describe ".upload_image" do
      let(:uploader){ mock('sftp_uploader').as_null_object }

      before(:each) do
        SFTPHelper.stub!(:new).and_return(uploader)
      end

      it "should connect to the image delivery uri" do
        prepare_plugin do |p, c|
          c['image_delivery_uri'] = 'sftp://user:pass@example.com/a/directory'
        end

        uploader.should_receive(:connect).
            with('example.com', 'user', :password => 'pass')

        @plugin.upload_image
      end

      it "should upload files to the specified path at the uri" do
        prepare_plugin do |p, c|
          c['image_delivery_uri'] = 'sftp://user:pass@example.com/a/directory'
        end

        uploader.should_receive(:upload_files).
            with('/a/directory', 0770, false, 'bble.raw' => '/flo/bble.raw')

        @plugin.upload_image
      end

      it "should disconnect after finishing" do
        prepare_plugin do |p, c|
          uploader.stub!(:connected).and_return(true)
          c['image_delivery_uri'] = 'sftp://user:pass@example.com/a/directory'
        end

        uploader.should_receive(:disconnect)
        @plugin.upload_image
      end
    end

    # Fuller combinatorial coverage in cucumber required
    describe ".build_xml" do
      # These sometimes fail due to ordering of XML elements, after adding xml 
      # equivalence operators it should be much simpler.
      # it "should build an xml definition from appliance config & user options" do
      #   prepare_plugin do |p, c|
      #   end

      #   @plugin.build_xml(:bus => 'bus', :os_type => :box, :domain_type => :grinder).
      #       should == open("#{File.dirname(__FILE__)}/libvirt_test.xml").read
      # end

      # it "should allow modification of the xml definition via script" do
      #   prepare_plugin do |p, c|
      #     c['script'] = "#{File.dirname(__FILE__)}/libvirt_modify.sh"
      #   end

      #   @plugin.build_xml(:bus => 'bus', :os_type => :box, :domain_type => :grinder).
      #       should == open("#{File.dirname(__FILE__)}/libvirt_modified.xml").read
      # end
    end
  end
end
