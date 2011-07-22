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

require 'rubygems'
require 'rspec'
require 'hashery/opencascade'
require 'boxgrinder-build/plugins/delivery/elastichosts/elastichosts-plugin'

module BoxGrinder
  describe ElasticHostsPlugin do

    def prepare(options = {})
      @config = Config.new(
          'plugins' => {
              'elastichosts' => {
                  'username' => '12345',
                  'password' => 'secret_access_key',
                  'endpoint' => 'one.endpoint.somewhere.com'
              }
          })

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('appliance')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:cpus).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => :fedora, :version => '13'}))
      @appliance_config.stub!(:hardware).and_return(OpenCascade.new(:cpus => 1, :arch => 'x86_64', :partitions => {'/' => {'size' => 1}, '/home' => {'size' => 2}}, :memory => 512))

      options = {:log => LogHelper.new(:level => :trace, :type => :stdout), :previous_plugin => OpenCascade.new(:plugin_info => {:type => :os})}.merge(options)

      @plugin = ElasticHostsPlugin.new.init(@config, @appliance_config,
                                            {:class => BoxGrinder::ElasticHostsPlugin, :type => :delivery, :name => :elastichosts, :full_name => "ElasticHosts"},
                                            options

      )

      @plugin_config = @config.plugins['elastichosts']
      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @log = @plugin.instance_variable_get(:@log)
      @dir = @plugin.instance_variable_get(:@dir)
    end

    context "validation" do
      describe ".validate" do
        it "should fail because we try to upload a non-base appliance" do
          lambda {
            prepare(:previous_plugin => OpenCascade.new(:plugin_info => {:type => :platform}))
          }.should raise_error(PluginValidationError, 'You can use ElasticHosts plugin with base appliances (appliances created with operating system plugins) only, see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#ElasticHosts_Delivery_Plugin.')
        end
      end
    end

    context "after validation" do
      before(:each) do
        prepare
        @plugin.validate
      end

      describe ".elastichosts_api_url" do
        it "should return valid url for default schema" do
          @plugin.api_url('/drive/1').should == 'http://12345:secret_access_key@one.endpoint.somewhere.com/drive/1'
        end

        it "should return valid url for SSL" do
          @plugin_config.merge!('ssl' => true)
          @plugin.api_url('/drive/1').should == 'https://12345:secret_access_key@one.endpoint.somewhere.com/drive/1'
        end
      end

      it "should return valid disk_size" do
        @plugin.disk_size.should == 3
      end


      describe ".execute" do
        it "should upload the appliance" do
          @plugin.should_receive(:upload)
          @plugin.should_receive(:create_server)
          @plugin.execute
        end
      end

      it "should convert hash to request" do
        @plugin.hash_to_request('abc' => 'def', 'one' => 1234).should == "abc def\none 1234\n"
      end

      describe ".create_remote_disk" do
        it "should create remote disk with default name" do
          @plugin.should_receive(:hash_to_request).with('size' => 3221225472, 'name' => 'appliance').and_return("json")

          RestClient.should_receive(:post).with("http://12345:secret_access_key@one.endpoint.somewhere.com/drives/create",
                                                "json").and_return("drive abc-1234567890-abc\n")
          @plugin.create_remote_disk.should == 'abc-1234567890-abc'
        end

        it "should create remote disk with custom name" do
          @plugin_config.merge!('drive_name' => 'thisisadrivename')

          @plugin.should_receive(:hash_to_request).with('size' => 3221225472, 'name' => 'thisisadrivename').and_return("json")

          RestClient.should_receive(:post).with("http://12345:secret_access_key@one.endpoint.somewhere.com/drives/create",
                                                "json").and_return("drive abc-1234567890-abc\n")
          @plugin.create_remote_disk.should == 'abc-1234567890-abc'
        end

        it "should catch remote disk creation error" do
          @plugin.should_receive(:hash_to_request).with('size' => 3221225472, 'name' => 'appliance').and_return("json")

          RestClient.should_receive(:post).with("http://12345:secret_access_key@one.endpoint.somewhere.com/drives/create",
                                                "json").and_raise('boom')

          lambda {
            @plugin.create_remote_disk
          }.should raise_error(PluginError, 'An error occured while creating the drive, boom. See logs for more info.')
        end
      end

      describe ".upload" do
        it "create the disk and upload" do
          @plugin.should_receive(:create_remote_disk)
          @plugin.should_receive(:upload_chunks)
          @plugin.upload
        end

        it "upload using existing disk" do
          @plugin_config.merge!('drive_uuid' => 'thisisadrivename')

          @plugin.should_not_receive(:create_remote_disk)
          @plugin.should_receive(:upload_chunks)
          @plugin.upload
        end
      end

      it "should compress data chunk" do
        stringio = mock(StringIO)
        stringio.should_receive(:string).and_return("compressed_data")
        stringio.should_receive(:size).and_return(2048)

        gzipwriter = mock(Zlib::GzipWriter)
        gzipwriter.should_receive(:write).with("data")
        gzipwriter.should_receive(:close)

        StringIO.should_receive(:new).and_return(stringio)
        Zlib::GzipWriter.should_receive(:new).with(stringio, Zlib::DEFAULT_COMPRESSION, Zlib::FINISH).and_return(gzipwriter)

        @plugin.compress("data").should == "compressed_data"
      end

      describe ".upload_chunks" do
        it "should upload chunks in 2 parts" do
          @plugin.instance_variable_set(:@previous_deliverables, OpenCascade.new({:disk => 'a/disk'}))

          f = mock(File)
          f.should_receive(:eof?).ordered.and_return(false)
          f.should_receive(:seek).ordered.with(0, File::SEEK_SET)
          f.should_receive(:read).ordered.with(67108864).and_return("data")

          @plugin.should_receive(:compress).ordered.with("data").and_return("compressed_data")
          @plugin.should_receive(:upload_chunk).ordered.with("compressed_data", 0)

          f.should_receive(:eof?).ordered.and_return(false)
          f.should_receive(:seek).ordered.with(67108864, File::SEEK_SET)
          f.should_receive(:read).ordered.with(67108864).and_return("data")

          @plugin.should_receive(:compress).ordered.with("data").and_return("compressed_data")
          @plugin.should_receive(:upload_chunk).ordered.with("compressed_data", 1)

          f.should_receive(:eof?).ordered.and_return(true)

          File.should_receive(:open).with('a/disk', 'rb').and_yield(f)
          @plugin.upload_chunks
        end

        it "should upload 1 chunk with custom chunk size" do
          @plugin_config.merge!('chunk' => 128)
          @plugin.instance_variable_set(:@previous_deliverables, OpenCascade.new({:disk => 'a/disk'}))

          f = mock(File)
          f.should_receive(:eof?).ordered.and_return(false)
          f.should_receive(:seek).ordered.with(0, File::SEEK_SET)
          f.should_receive(:read).ordered.with(134217728).and_return("data")

          @plugin.should_receive(:compress).ordered.with("data").and_return("compressed_data")
          @plugin.should_receive(:upload_chunk).ordered.with("compressed_data", 0)

          f.should_receive(:eof?).ordered.and_return(true)

          File.should_receive(:open).with('a/disk', 'rb').and_yield(f)
          @plugin.upload_chunks
        end

        it "should not compress the data before uploading the chunks if we use CloudSigma" do
          @plugin_config.merge!('endpoint' => 'api.cloudsigma.com')
          @plugin.instance_variable_set(:@previous_deliverables, OpenCascade.new({:disk => 'a/disk'}))

          f = mock(File)
          f.should_receive(:eof?).ordered.and_return(false)
          f.should_receive(:seek).ordered.with(0, File::SEEK_SET)
          f.should_receive(:read).ordered.with(67108864).and_return("data")
          f.should_receive(:eof?).ordered.and_return(true)

          @plugin.should_not_receive(:compress)
          @plugin.should_receive(:upload_chunk).ordered.with("data", 0)

          File.should_receive(:open).with('a/disk', 'rb').and_yield(f)
          @plugin.upload_chunks
        end
      end

      describe ".upload_chunk" do
        before :each do
          @plugin_config.merge!('drive_uuid' => 'drive-uuid')
          @plugin.instance_variable_set(:@step, 134217728)
        end

        it "should upload a chunk of data" do
          @plugin.should_receive(:api_url).with('/drives/drive-uuid/write/134217728').and_return('url')
          RestClient.should_receive(:post).with('url', 'data', :content_type=>"application/octet-stream", "Content-Encoding"=>"gzip")
          @plugin.upload_chunk("data", 1)
        end

        it "should upload a chunk of data and be succesful after 1 retry" do
          @plugin.should_receive(:api_url).with('/drives/drive-uuid/write/0').and_return('url')
          RestClient.should_receive(:post).with('url', 'data', :content_type=>"application/octet-stream", "Content-Encoding"=>"gzip").and_raise('boom')
          @plugin.should_receive(:sleep).with(5)
          RestClient.should_receive(:post).with('url', 'data', :content_type=>"application/octet-stream", "Content-Encoding"=>"gzip")

          @plugin.upload_chunk("data", 0)
        end

        it "should fail the upload after 3 retries" do
          @plugin.should_receive(:api_url).with('/drives/drive-uuid/write/0').and_return('url')
          RestClient.should_receive(:post).exactly(3).times.with('url', 'data', :content_type=>"application/octet-stream", "Content-Encoding"=>"gzip").and_raise('boom')
          @plugin.should_receive(:sleep).exactly(2).times.with(5)

          lambda {
            @plugin.upload_chunk("data", 0)
          }.should raise_error(PluginError, "Couldn't upload appliance, boom.")
        end

        it "should fail the upload after custom sleep time and retry count" do
          @plugin_config.merge!('retry' => 5, 'wait' => 30)

          @plugin.should_receive(:api_url).with('/drives/drive-uuid/write/0').and_return('url')
          RestClient.should_receive(:post).exactly(5).times.with('url', 'data', :content_type=>"application/octet-stream", "Content-Encoding"=>"gzip").and_raise('boom')
          @plugin.should_receive(:sleep).exactly(4).times.with(30)

          lambda {
            @plugin.upload_chunk("data", 0)
          }.should raise_error(PluginError, "Couldn't upload appliance, boom.")
        end

        it "should not specify add content-encoding header if uplaoding to cloudsigma" do
          @plugin_config.merge!('endpoint' => 'api.cloudsigma.com')

          @plugin.should_receive(:api_url).with('/drives/drive-uuid/write/0').and_return('url')
          RestClient.should_receive(:post).with('url', 'data', :content_type=>"application/octet-stream")

          @plugin.upload_chunk("data", 0)
        end
      end

      describe ".create_server" do
        before(:each) do
          @plugin_config.merge!('drive_uuid' => '12345-asdf')

          @plugin.should_receive(:hash_to_request).with(
              'name' => "appliance-1.0",
              'cpu' => 1000,
              'smp' => 'auto',
              'mem' => 512,
              'persistent' => 'true',
              'ide:0:0' => '12345-asdf',
              'boot' => 'ide:0:0',
              'nic:0:model' => 'e1000',
              'nic:0:dhcp' => 'auto',
              'vnc:ip' => 'auto',
              'vnc:password' => an_instance_of(String)
          ).and_return("json")
        end

        it "should create the server without issues" do
          RestClient.should_receive(:post).with("http://12345:secret_access_key@one.endpoint.somewhere.com/servers/create/stopped",
                                                "json").and_return("server abc-1234567890-abc\nname appliance-1.0\n")

          @plugin.create_server
        end

        it "should create the server with 512 MB of ram for instances to be uploaded to cloudsigma" do
          @plugin_config.merge!('endpoint' => 'api.cloudsigma.com')

          @appliance_config.stub!(:hardware).and_return(OpenCascade.new(:cpus => 1, :arch => 'x86_64', :partitions => {'/' => {'size' => 1}, '/home' => {'size' => 2}}, :memory => 256))

          RestClient.should_receive(:post).with("http://12345:secret_access_key@api.cloudsigma.com/servers/create",
                                                "json").and_return("server abc-1234567890-abc\nname appliance-1.0\n")

          @plugin.create_server
        end

        it "should create the server without issues for cloudsigma cloud" do
          @plugin_config.merge!('endpoint' => 'api.cloudsigma.com')

          RestClient.should_receive(:post).with("http://12345:secret_access_key@api.cloudsigma.com/servers/create",
                                                "json").and_return("server abc-1234567890-abc\nname appliance-1.0\n")

          @plugin.create_server
        end

        it "should catch remote disk creation error" do
          RestClient.should_receive(:post).with("http://12345:secret_access_key@one.endpoint.somewhere.com/servers/create/stopped",
                                                "json").and_raise('boom')

          lambda {
            @plugin.create_server
          }.should raise_error(PluginError, 'An error occured while creating the server, boom. See logs for more info.')
        end
      end

      describe ".is_cloudsigma?" do
        it "should return true if we're talking to cloudsigma endpoint" do
          @plugin_config.merge!('endpoint' => 'api.cloudsigma.com')
          @plugin.is_cloudsigma?.should == true
        end

        it "should return false if we're NOT talking to cloudsigma endpoint" do
          @plugin.is_cloudsigma?.should == false
        end
      end
    end
  end
end

