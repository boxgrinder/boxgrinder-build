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

require 'boxgrinder-build/plugins/delivery/s3/s3-plugin'
require 'boxgrinder-core/astruct'
require 'boxgrinder-core/models/config'
require 'set'

module BoxGrinder
  describe S3Plugin do

    before(:each) do
      @config = Config.new(
          'plugins' => {
              's3' => {
                  'access_key' => 'access_key',
                  'secret_access_key' => 'secret_access_key',
                  'bucket' => 'bucket',
                  'account_number' => '0000-0000-0000',
                  'cert_file' => '/path/to/cert/file',
                  'key_file' => '/path/to/key/file',
                  'path' => '/'
              }
          })

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('appliance')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '14'}))
      @appliance_config.stub!(:hardware).and_return(OpenCascade.new({:arch => 'x86_64', :base_arch => 'x86_64'}))

      @plugin = RSpecPluginHelper.new(S3Plugin).prepare(@config, @appliance_config,
        :previous_plugin => OpenCascade.new(:type => :os, :deliverables => {:disk => "a_disk.raw", :metadata => 'metadata.xml'}),
        :plugin_info => {:class => BoxGrinder::S3Plugin, :type => :delivery, :name => :s3, :full_name => "Amazon Simple Storage Service (Amazon S3)", :types => [:s3, :cloudfront, :ami]}
      ) { |plugin| plugin.stub!(:asset_bucket) }

      #Set convenient dummies
      @ec2 = mock(AWS::EC2)
      @s3 = mock(AWS::S3)
      @s3helper = S3Helper.new(@ec2, @s3, :log => LogHelper.new(:level => :trace, :type => :stdout))
      @ec2helper = EC2Helper.new(@ec2, :log => LogHelper.new(:level => :trace, :type => :stdout))
      @bucket = mock(AWS::S3::Bucket)

      @plugin.instance_variable_set(:@ec2, @ec2)
      @plugin.instance_variable_set(:@s3, @s3)
      @plugin.instance_variable_set(:@ec2helper, @ec2helper)
      @plugin.instance_variable_set(:@s3helper, @s3helper)
      @plugin.instance_variable_set(:@bucket, @bucket)

      @appliance_config = @plugin.instance_variable_get(:@appliance_config)
      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @log = @plugin.instance_variable_get(:@log)
      @dir = @plugin.instance_variable_get(:@dir)
    end

    describe ".ami_key" do

      before(:each) do
        @key1 = mock('AWS::S3::S3Object-1')
        @key2 = mock('AWS::S3::S3Object-2')    
      end

      it "should generate valid ami_key" do
        @plugin.ami_key("name", "this/is/a/path").should == "this/is/a/path/name/fedora/14/1.0/x86_64"
      end

      it "should generate valid ami_key with mixed slashes" do
        @plugin.ami_key("name", "//this/").should == "this/name/fedora/14/1.0/x86_64"
      end

      it "should generate valid ami_key with root path" do
        @plugin.ami_key("name", "/").should == "name/fedora/14/1.0/x86_64"
      end

      it "should generate valid ami_key with snapshot number two" do
        @config.plugins['s3'].merge!('snapshot' => true)

        @key1.should_receive(:exists?).and_return(true)
        @key2.should_receive(:exists?).and_return(false)

        @s3helper.should_receive(:stub_s3obj).with(@bucket, 'name/fedora/14/1.0-snapshot-1/x86_64/').and_return(@key1)
        @s3helper.should_receive(:stub_s3obj).with(@bucket, 'name/fedora/14/1.0-snapshot-2/x86_64/').and_return(@key2)

        @plugin.ami_key("name", "/").should == "name/fedora/14/1.0-snapshot-2/x86_64"
      end

      it "should return valid ami_key with snapshot and overwrite enabled" do
        @config.plugins['s3'].merge!('snapshot' => true, 'overwrite' => true)

        @key1.should_receive(:exists?).and_return(true)
        @key2.should_receive(:exists?).and_return(false)

        @s3helper.should_receive(:stub_s3obj).with(@bucket, 'name/fedora/14/1.0-snapshot-1/x86_64/').and_return(@key1)
        @s3helper.should_receive(:stub_s3obj).with(@bucket, 'name/fedora/14/1.0-snapshot-2/x86_64/').and_return(@key2)

        @plugin.ami_key("name", "/").should == "name/fedora/14/1.0-snapshot-1/x86_64"
      end
    end

    describe ".upload_to_bucket" do

      before(:each) do
        @package_helper = mock(PackageHelper)
        @s3obj = mock(AWS::S3::S3Object)

        PackageHelper.should_receive(:new).with(@config, @appliance_config, :log => @log, :exec_helper => @exec_helper).and_return(@package_helper)
        @package_helper.should_receive(:package).with(".", "build/path/s3-plugin/tmp/appliance-1.0-fedora-14-x86_64-raw.tgz").and_return("a_built_package.zip")

        File.should_receive(:size).with("build/path/s3-plugin/tmp/appliance-1.0-fedora-14-x86_64-raw.tgz").and_return(23234566)
        @s3helper.should_receive(:stub_s3obj).and_return(@s3obj)
      end

      it "should upload to an S3 bucket" do
        @s3obj.stub!(:exists?).and_return(false)

        @s3obj.should_receive(:write).with(:file => "build/path/s3-plugin/tmp/appliance-1.0-fedora-14-x86_64-raw.tgz", :acl => :private)

        @plugin.upload_to_bucket(:disk => "adisk")
      end

      it "should NOT upload to an S3 bucket when the file already exists" do
        @s3obj.stub!(:exists?).and_return(true)

        @s3obj.should_not_receive(:write)

        @plugin.upload_to_bucket(:disk => "adisk")
      end
    end

    it "should bundle the image" do
      File.should_receive(:exists?).with('build/path/s3-plugin/ami').and_return(false)
      FileUtils.stub!(:mkdir_p)
      @exec_helper.should_receive(:execute).with(/euca-bundle-image --ec2cert (.*)src\/cert-ec2\.pem -i a\/path\/to\/disk\.ec2 --kernel aki-427d952b -c \/path\/to\/cert\/file -k \/path\/to\/key\/file -u 000000000000 -r x86_64 -d build\/path\/s3-plugin\/ami/, :redacted=>["000000000000", "/path/to/key/file", "/path/to/cert/file"])
      @plugin.bundle_image(:disk => "a/path/to/disk.ec2")
    end

    it "should bundle the image for centos 5 and choose right kernel and ramdisk" do
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'centos', :version => '5'}))
      @plugin.instance_variable_get(:@plugin_config).merge!({'region' => 'us-west-1'})

      File.should_receive(:exists?).with('build/path/s3-plugin/ami').and_return(false)
      FileUtils.stub!(:mkdir_p)
      @exec_helper.should_receive(:execute).with(/euca-bundle-image --ec2cert (.*)src\/cert-ec2\.pem -i a\/path\/to\/disk\.ec2 --kernel aki-9ba0f1de -c \/path\/to\/cert\/file -k \/path\/to\/key\/file -u 000000000000 -r x86_64 -d build\/path\/s3-plugin\/ami/, :redacted=>["000000000000", "/path/to/key/file", "/path/to/cert/file"])
      @plugin.bundle_image(:disk => "a/path/to/disk.ec2")
    end

    it "should bundle image with user-selected ramdisk and kernel when set" do
      @config.plugins['s3'].merge!('ramdisk' => '101010101', 'kernel' => '2020202')
      File.should_receive(:exists?).with('build/path/s3-plugin/ami').and_return(false)
      FileUtils.stub!(:mkdir_p)
      @exec_helper.should_receive(:execute).with(/euca-bundle-image --ec2cert (.*)src\/cert-ec2\.pem -i a\/path\/to\/disk\.ec2 --kernel 2020202 -c \/path\/to\/cert\/file -k \/path\/to\/key\/file -u 000000000000 -r x86_64 -d build\/path\/s3-plugin\/ami --ramdisk 101010101/, :redacted=>["000000000000", "/path/to/key/file", "/path/to/cert/file"])
      @plugin.bundle_image(:disk => "a/path/to/disk.ec2")
    end

    describe ".execute" do
      before(:each) do
        @s3obj = mock(AWS::S3::S3Object)
        FileUtils.stub!(:mkdir_p)
      end

      context "AMI" do
        before(:each) do
          @plugin.instance_variable_set(:@previous_deliverables, {:disk => 'a/disk'})
          @s3helper.should_receive(:stub_s3obj).with(@bucket, "ami/key/appliance.ec2.manifest.xml").and_return(@s3obj)
          @plugin.should_receive(:ami_key).with("appliance", "/").and_return('ami/key')
          @plugin.instance_variable_set(:@type, :ami)
        end

        it "should create an AMI" do

          @s3obj.should_receive(:exists?).twice.and_return(false)
          @plugin.should_receive(:bundle_image).with(:disk => 'a/disk')
          @plugin.should_receive(:upload_image)
          @plugin.should_receive(:register_image)

          @plugin.execute
        end

        it "should not upload an AMI because it's already there" do

          @s3obj.should_receive(:exists?).twice.and_return(true)
          @plugin.should_not_receive(:upload_image)
          @plugin.should_receive(:register_image)

          @plugin.execute
        end

        it "should upload an AMI even if one is already present in order to perform a snapshot" do
          @config.plugins['s3'].merge!('snapshot' => true)

          @s3obj.should_receive(:exists?).twice.and_return(false)
          @plugin.should_receive(:bundle_image).with(:disk => 'a/disk')
          @plugin.should_receive(:upload_image)
          @plugin.should_receive(:register_image)

          @plugin.execute
        end
      end

      context "s3" do
        it "should upload image to s3" do
          @plugin.instance_variable_set(:@type, :s3)
          @plugin.instance_variable_set(:@previous_deliverables, :disk => 'a/disk')
          @plugin.should_receive(:upload_to_bucket).with({:disk => 'a/disk'})
          @plugin.execute
        end
      end

      context "cloudfront" do
        it "should upload image to cloudfront" do
          @plugin.instance_variable_set(:@type, :cloudfront)
          @plugin.instance_variable_set(:@previous_deliverables, {:disk => 'a/disk'})
          @plugin.should_receive(:upload_to_bucket).with({:disk => 'a/disk'}, :public_read)
          @plugin.execute
        end
      end
    end

    describe ".validate" do
      before(:each) do
        @plugin.stub(:asset_bucket).and_return(@bucket)
      end

      context "bucket is not already in existence" do
        before(:each) do
          @plugin.stub(:set_default_config_value).and_return(true)
        end

        it "should validate only basic params" do

          @plugin.should_receive(:validate_plugin_config).with(['bucket', 'access_key', 'secret_access_key'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin')

          @plugin.validate
        end

        it "should validate basic and additional ami params" do
          @plugin.instance_variable_set(:@type, :ami)

          @plugin.should_receive(:set_default_config_value).with('overwrite', false)
          @plugin.should_receive(:set_default_config_value).with('path', '/')
          @plugin.should_receive(:set_default_config_value).with('block_device_mappings', {})
          @plugin.should_receive(:set_default_config_value).with('region', 'us-east-1')
          @plugin.should_receive(:set_default_config_value).with('ramdisk', false)
          @plugin.should_receive(:set_default_config_value).with('kernel', false)

          @plugin.should_receive(:set_default_config_value).with('snapshot', false)

          @plugin.should_receive(:validate_plugin_config).with(['bucket', 'access_key', 'secret_access_key'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin')
          @plugin.should_receive(:validate_plugin_config).with(["cert_file", "key_file", "account_number"], "http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin")

          File.stub(:expand_path)
          File.stub(:exists?)
          File.should_receive(:expand_path).with('/path/to/cert/file').and_return('path1')
          File.should_receive(:exists?).with('path1').and_return(true)
          File.should_receive(:expand_path).with('/path/to/key/file').and_return('path2')
          File.should_receive(:exists?).with('path2').and_return(true)

          @plugin.should_receive(:asset_bucket).with(false).and_return(nil)
          @plugin.should_receive(:asset_bucket).with(true).and_return(@bucket)

          @plugin.validate
        end

        it "should raise because key file doesn't exists" do
          @plugin.instance_variable_set(:@type, :ami)

          @plugin.should_receive(:set_default_config_value).with('snapshot', false)

          @plugin.should_receive(:validate_plugin_config).with(['bucket', 'access_key', 'secret_access_key'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin')
          @plugin.should_receive(:validate_plugin_config).with(["cert_file", "key_file", "account_number"], "http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin")

          File.stub(:expand_path)
          File.stub(:exists?)
          File.should_receive(:expand_path).with('/path/to/cert/file').and_return('path1')
          File.should_receive(:exists?).with('path1').and_return(true)
          File.should_receive(:expand_path).with('/path/to/key/file').and_return('path2')
          File.should_receive(:exists?).with('path2').and_return(false)

          lambda { @plugin.validate }.should raise_error(PluginValidationError, "AWS key file doesn't exists, please check the path: '/path/to/key/file'.")
        end

        it "should raise because key file doesn't exists" do
          @plugin.instance_variable_set(:@type, :ami)

          @plugin.should_receive(:set_default_config_value).with('snapshot', false)

          @plugin.should_receive(:validate_plugin_config).with(['bucket', 'access_key', 'secret_access_key'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin')
          @plugin.should_receive(:validate_plugin_config).with(["cert_file", "key_file", "account_number"], "http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin")

          File.stub(:expand_path)
          File.stub(:exists?)
          File.should_receive(:expand_path).with('/path/to/cert/file').and_return('path1')
          File.should_receive(:exists?).with('path1').and_return(false)

          lambda { @plugin.validate }.should raise_error(PluginValidationError, "AWS certificate file doesn't exists, please check the path: '/path/to/cert/file'.")
        end

        it "should raise an error if an invalid region is specified" do
          @plugin.instance_variable_set(:@type, :ami)

          @config.plugins['s3'].merge!('region' => 'near-spain-1')

          @plugin.should_receive(:set_default_config_value).with('snapshot', false)

          @plugin.should_receive(:validate_plugin_config).with(['bucket', 'access_key', 'secret_access_key'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin')
          @plugin.should_receive(:validate_plugin_config).with(["cert_file", "key_file", "account_number"], "http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin")

          File.stub(:expand_path)
          File.stub(:exists?)
          File.should_receive(:expand_path).with('/path/to/cert/file').and_return('path1')
          File.should_receive(:exists?).with('path1').and_return(true)
          File.should_receive(:expand_path).with('/path/to/key/file').and_return('path2')
          File.should_receive(:exists?).with('path2').and_return(true)

          lambda { @plugin.validate }.should raise_error(PluginValidationError, /Invalid region specified: near-spain-1.*/)
        end
      end

      context "bucket exists (AMI mode)" do

        before(:each) do
          @plugin.instance_variable_set(:@type, :ami)
          @plugin.stub(:set_default_config_value)

          File.stub(:expand_path)
          File.stub(:exists?)
          File.should_receive(:expand_path).with('/path/to/cert/file').and_return('path1')
          File.should_receive(:exists?).with('path1').and_return(true)
          File.should_receive(:expand_path).with('/path/to/key/file').and_return('path2')
          File.should_receive(:exists?).with('path2').and_return(true)

          @plugin.should_receive(:validate_plugin_config).with(['bucket', 'access_key', 'secret_access_key'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin')
          @plugin.should_receive(:validate_plugin_config).with(["cert_file", "key_file", "account_number"], "http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin")
        end

        it "should succeed if the bucket location constraint and region match" do
          @plugin.should_receive(:asset_bucket).and_return(@bucket)
          @bucket.should_receive(:location_constraint).and_return(nil)

          @plugin.validate
        end

        it "should raise an error if bucket location constraint and region do not match" do
          @plugin.should_receive(:asset_bucket).and_return(@bucket)
          @bucket.should_receive(:location_constraint).and_return('eu-west-1')

          lambda { @plugin.validate }.should raise_error(PluginValidationError, "Existing bucket bucket has a location constraint that does not match the region selected. AMI region and bucket location constraint must match.")
        end

      end
    end

    describe ".bucket" do
      before(:each) do
        @plugin.unstub(:asset_bucket)
      end

      it "should create the asset bucket by default" do
        @config.plugins['s3'].merge!('region' => 'ap-southeast-1')

        @s3helper.should_receive(:bucket).with(:bucket => 'bucket', :acl => :private,
        :create_if_missing => true, :location_constraint => 'ap-southeast-1')

        @plugin.asset_bucket
      end

      it "should not create the bucket" do
        @config.plugins['s3'].merge!('region' => 'ap-southeast-1')

        @s3helper.should_receive(:bucket).with(:bucket => 'bucket', :acl => :private,
        :create_if_missing => false, :location_constraint => 'ap-southeast-1')

        @plugin.asset_bucket(false)
      end
    end

    describe ".upload_image" do
      it "should upload image for default region" do
        @exec_helper.should_receive(:execute).with("euca-upload-bundle -U http://s3.amazonaws.com -b bucket/ami/key -m build/path/s3-plugin/ami/appliance.ec2.manifest.xml -a access_key -s secret_access_key", :redacted=>["access_key", "secret_access_key"])
        @plugin.upload_image("ami/key")
      end

      it "should upload image for us-west-1 region" do
        @config.plugins['s3'].merge!('region' => 'us-west-1')

        @exec_helper.should_receive(:execute).with("euca-upload-bundle -U http://s3-us-west-1.amazonaws.com -b bucket/ami/key -m build/path/s3-plugin/ami/appliance.ec2.manifest.xml -a access_key -s secret_access_key", :redacted=>["access_key", "secret_access_key"])
        @plugin.upload_image("ami/key")
      end
    end

    describe ".register_image" do
      before(:each) do
        @ami = mock(AWS::EC2::Image)
        @ami.stub(:id).and_return('ami-1234')

        @manifest_key = mock(AWS::S3::S3Object)
        @manifest_key.stub(:key).and_return('ami/manifest/key')

        @ec2.stub(:images)
        @ec2helper.stub(:wait_for_image_state)
      end

      context "when the AMI has not been registered" do
        before(:each) do
          @plugin.stub(:ami_by_manifest_key).and_return(nil)
        end

        it "should register the AMI" do
          @plugin.should_receive(:ami_by_manifest_key).with(@manifest_key)
          @ec2.images.should_receive(:create).with(:image_location => "bucket/ami/manifest/key").and_return(@ami)
          @ec2helper.should_receive(:wait_for_image_state).with(:available, @ami)
          @plugin.register_image(@manifest_key)
        end
      end

      context "when the AMI has been registered" do
        before(:each) do
          @plugin.stub(:ami_by_manifest_key).and_return(@ami)
        end

        it "should not register the AMI" do
          @plugin.should_receive(:ami_by_manifest_key).with(@manifest_key)
          @ec2.images.should_not_receive(:create)

          @plugin.register_image(@manifest_key)
        end
      end
    end

     describe ".deregister_image" do
       before(:each) do
         @ami = mock(AWS::EC2::Image)
         @plugin.stub(:ami_by_manifest_key).and_return(@ami)

         @manifest_key = mock(AWS::S3::S3Object)
         @ec2helper.stub(:wait_for_image_death)

         @ami.stub(:id)
         @ami.stub(:location)
       end

       it "should deregister the AMI" do
         @plugin.should_receive(:ami_by_manifest_key).with(@manifest_key)
         @ami.should_receive(:deregister)
         @ec2helper.should_receive(:wait_for_image_death).with(@ami)
         @plugin.deregister_image(@manifest_key)
       end
    end

  end
end
