require 'boxgrinder-build/plugins/delivery/s3/s3-plugin'
require 'rspec-helpers/rspec-config-helper'

module BoxGrinder
  describe S3Plugin do
    include RSpecConfigHelper

    before(:each) do
      @plugin = S3Plugin.new.init(generate_config, generate_appliance_config, :log => Logger.new('/dev/null'))

      @config             = @plugin.instance_variable_get(:@config)
      @appliance_config   = @plugin.instance_variable_get(:@appliance_config)
      @exec_helper        = @plugin.instance_variable_get(:@exec_helper)
      @log                = @plugin.instance_variable_get(:@log)

      @plugin_config = {
              'access_key'        => 'access_key',
              'secret_access_key' => 'secret_access_key',
              'bucket'            => 'bucket',
              'account_number'    => '0000-0000-0000',
              'cert_file'         => '/path/to/cert/file',
              'key_file'          => '/path/to/key/file'
      }

      @plugin.instance_variable_set(:@plugin_config, @plugin_config)

    end

    it "should generate valid bucket_key" do
      @plugin.bucket_key( "name", "this/is/a/path" ).should == "bucket/this/is/a/path/name/1.0/i386"
    end

    it "should generate valid bucket_key with mixed slashes" do
      @plugin.bucket_key( "name", "//this/" ).should == "bucket/this/name/1.0/i386"
    end

    it "should generate valid bucket_key with root path" do
      @plugin.bucket_key( "name", "/" ).should == "bucket/name/1.0/i386"
    end

    it "should generate valid bucket manifest key" do
      @plugin.bucket_manifest_key( "name", "/a/asd/f/sdf///" ).should == "bucket/a/asd/f/sdf/name/1.0/i386/name.ec2.manifest.xml"
    end

  end
end

