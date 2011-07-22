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

require 'boxgrinder-build/plugins/delivery/ebs/ebs-plugin'
require 'rubygems'
require 'rspec'
require 'ostruct'
require 'logger'
require 'set'

module BoxGrinder

  describe EBSPlugin do
    before(:all) do
      @arch = `uname -m`.chomp.strip
    end

    def prepare_plugin
      @plugin = EBSPlugin.new

      yield @plugin if block_given?

      @config = Config.new('plugins' => { 'ebs' => {
        'access_key' => 'access_key',
        'secret_access_key' => 'secret_access_key',
        'account_number' => '000000000000'
      }})

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:name).and_return('appliance_name')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '14'}))
      @appliance_config.stub!(:hardware).and_return(OpenCascade.new({:arch => 'x86_64', :base_arch => 'x86_64'}))
      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => '/a/build/path'}))

      @plugin.stub!(:validate)

      @plugin.init(
          @config,
          @appliance_config,
          {:class => BoxGrinder::EBSPlugin, :type => :delivery, :name => :ebs, :full_name => "Elastic Block Storage"},
          :log => LogHelper.new(:level => :trace, :type => :stdout)
      )

      #Set convenient dummies
      AWS.config({:access_key_id => '', :secret_access_key => ''})
      @ec2 = AWS::EC2.new
      @s3 = AWS::S3.new
      @s3helper = S3Helper.new(@ec2, @s3)
      @ec2helper = EC2Helper.new(@ec2)

      @plugin.instance_variable_set(:@ec2, @ec2)
      @plugin.instance_variable_set(:@s3, @s3)
      @plugin.instance_variable_set(:@ec2helper, @ec2helper)
      @plugin.instance_variable_set(:@s3helper, @s3helper)

      @plugin_config = @config.plugins['ebs']

      @plugin.instance_variable_set(:@plugin_config, @plugin_config)
    end

    it "should register all operating systems with specific versions" do
      prepare_plugin do |plugin|
        plugin.instance_variable_set(:@current_availability_zone, 'us-east-1a')
      end

      supported_oses = @plugin.instance_variable_get(:@supported_oses)

      supported_oses.size.should == 3
      Set.new(supported_oses.keys).should == Set.new(['fedora', 'rhel', 'centos'])
      supported_oses['rhel'].should == ['6']
      supported_oses['fedora'].should == ['13', '14', '15']
      supported_oses['centos'].should == ['5']
    end
    #
    it "should adjust fstab" do
      prepare_plugin { |plugin| plugin.stub!(:after_init) }

      guestfs = mock('GuestFS')
      guestfs.should_receive(:sh).with("cat /etc/fstab | grep -v '/mnt' | grep -v '/data' | grep -v 'swap' > /etc/fstab.new")
      guestfs.should_receive(:mv).with("/etc/fstab.new", "/etc/fstab")

      @plugin.adjust_fstab(guestfs)
    end
    #

    describe '.free_device_suffix' do
      it "should get a new free device" do
        prepare_plugin { |plugin| plugin.stub!(:after_init) }

        File.should_receive(:exists?).with("/dev/sdf").and_return(false)
        File.should_receive(:exists?).with("/dev/xvdf").and_return(false)

        @plugin.free_device_suffix.should == "f"
      end
      #
      it "should get a new free device next in order" do
        prepare_plugin { |plugin| plugin.stub!(:after_init) }

        File.should_receive(:exists?).with("/dev/sdf").and_return(false)
        File.should_receive(:exists?).with("/dev/xvdf").and_return(true)
        File.should_receive(:exists?).with("/dev/sdg").and_return(false)
        File.should_receive(:exists?).with("/dev/xvdg").and_return(false)

        @plugin.free_device_suffix.should == "g"
      end
    end
    #
    describe ".valid_platform?" do
      it "should return true if on EC2" do
        prepare_plugin do |plugin|
          plugin.stub!(:after_init)
          @plugin.instance_variable_set(:@ec2_endpoints, EC2Helper::endpoints)
          EC2Helper::stub!(:current_availability_zone).and_return('eu-west-1a')
          EC2Helper::stub!(:availability_zone_to_region).with('eu-west-1a').and_return('eu-west-1')
        end
        @plugin.valid_platform?.should == true
      end
    #
      it "should return false if NOT on EC2" do
        prepare_plugin do |plugin|
          plugin.stub!(:after_init)
          @plugin.instance_variable_set(:@ec2_endpoints, EC2Helper::endpoints)
          EC2Helper::stub!(:current_availability_zone).and_raise(Timeout::Error)
        end
        @plugin.valid_platform?.should == false
      end
    #
    end
    #
    describe ".ebs_appliance_name" do
      it "should return basic appliance name" do
        prepare_plugin { |plugin| plugin.stub!(:after_init) }
        @plugin.ebs_appliance_name.should == "appliance_name/fedora/14/1.0/x86_64"
      end
    #
      it "should always return basic appliance name when overwrite is enabled, but snapshot is disabled" do
        prepare_plugin { |plugin| plugin.stub!(:after_init) }
        @plugin_config.merge!('overwrite' => true, 'snapshot' => false)
        @plugin.ebs_appliance_name.should == "appliance_name/fedora/14/1.0/x86_64"
      end
    #
      it "should still return a valid _initial_ snapshot appliance name, even if overwrite and snapshot are enabled on first ever run" do
        prepare_plugin { |plugin| plugin.stub!(:after_init) }
        @plugin_config.merge!('overwrite' => true, 'snapshot' => true)

        @ec2helper.should_receive(:already_registered?).with("appliance_name/fedora/14/1.0-SNAPSHOT-1/x86_64")
        @plugin.ebs_appliance_name.should == "appliance_name/fedora/14/1.0-SNAPSHOT-1/x86_64"
      end
    #
      it "should return 2nd snapshot of appliance" do
        prepare_plugin { |plugin| plugin.stub!(:after_init) }

        @plugin_config.merge!('snapshot' => true)

        @ec2helper.should_receive(:already_registered?).with("appliance_name/fedora/14/1.0-SNAPSHOT-1/x86_64").and_return(true)
        @ec2helper.should_receive(:already_registered?).with("appliance_name/fedora/14/1.0-SNAPSHOT-2/x86_64").and_return(false)

        @plugin.ebs_appliance_name.should == "appliance_name/fedora/14/1.0-SNAPSHOT-2/x86_64"
      end
    #
      it "should return the last snapshot name again when OVERWRITE is enabled" do
        prepare_plugin { |plugin| plugin.stub!(:after_init) }

        @plugin_config.merge!('snapshot' => true, 'overwrite' => true)

        @ec2helper.should_receive(:already_registered?).with("appliance_name/fedora/14/1.0-SNAPSHOT-1/x86_64").and_return(true)
        @ec2helper.should_receive(:already_registered?).with("appliance_name/fedora/14/1.0-SNAPSHOT-2/x86_64").and_return(false)

        @plugin.ebs_appliance_name.should == "appliance_name/fedora/14/1.0-SNAPSHOT-1/x86_64"
      end
    #
    end
    #
    describe ".stomp_ebs" do
      before(:each) do
        prepare_plugin

        @ami = mock(AWS::EC2::Image)
        @ami.stub!(:id).and_return('ami-bratwurst')
        @ami.stub!(:deregister)
        @ami.stub!(:block_device_mappings).and_return({'/dev/sda1' => OpenStruct.new(
                {'snapshot_id' => 'snap-hambiscuit', 'volume_size' => 2})}
        )
        @ami.stub!(:root_device_name).and_return('/dev/sda1')
        instance_1 = mock(AWS::EC2::Instance)
        instance_2 = mock(AWS::EC2::Instance)
        instance_1.stub!(:id).and_return('i-cake')
        instance_1.stub!(:status).and_return(:running)
        instance_2.stub!(:id).and_return('i-bake')
        instance_2.stub!(:status).and_return(:stopped)

        @instances = [ instance_1, instance_2 ]

        @snap = mock(AWS::EC2::Snapshot)
      end

      it "destroys the preexisting EBS assets and de-registers the image with default settings" do
        @ec2helper.stub!(:live_instances)
        @ec2helper.should_receive(:snapshot_by_id).with('snap-hambiscuit').and_return(@snap)
        @ami.should_receive(:deregister)
        @ec2helper.should_receive(:wait_for_image_death).with(@ami)
        @snap.should_receive(:delete)
        @plugin.stomp_ebs(@ami)
      end

      context "there are live running instances" do
        before(:each) do
          @ec2helper.stub!(:snapshot_by_id).and_return(@snap)
          @ec2helper.stub!(:wait_for_image_death)
          @ec2helper.stub!(:snapshot_by_id)
          @ec2helper.stub!(:wait_for_image_death)
          @ami.stub!(:deregister)
          @snap.stub!(:delete)
        end

        context "instance termination is disabled" do
          it "raise an error to alert the user" do
            @ec2helper.should_receive(:live_instances).with(@ami).and_return(@instances)
            lambda { @plugin.stomp_ebs(@ami) }.should raise_error(RuntimeError)
          end
        end

        context "instance termination is enabled" do
          it "terminate any running instances" do
            @plugin_config.merge!('terminate_instances' => true)
            @ec2helper.should_receive(:live_instances).with(@ami).and_return(@instances)
            @plugin.should_receive(:terminate_instances).with(@instances)
            @plugin.stomp_ebs(@ami)
          end
        end
      end

      context "snapshot preservation" do
        before(:each) do
          @ec2helper.stub!(:live_instances).and_return(false)
        end

        it "retains the primary snapshot when preserve_snapshots is enabled" do
          @plugin_config.merge!('preserve_snapshots' => true)
          @ec2helper.should_receive(:snapshot_by_id).with('snap-hambiscuit').and_return(@snap)
          @ami.should_receive(:deregister)
          @ec2helper.should_receive(:wait_for_image_death).with(@ami)
          @snap.should_not_receive(:delete)
          @plugin.stomp_ebs(@ami)
        end
      end
    end

    #Amazon-EC2 gem uses recursive ostructs, and wont work with opencascade
    #this replicates the format to avoid breaking the code in tests.
    def recursive_ostruct(initial)
      clone = initial.clone
      ostruct = case initial.class
        when Array
          clone.collect! do |v|
            recursive_ostruct v
          end
        when Hash
           clone.each_pair do |k,v| #follow down until reach terminal
            clone[k] = recursive_ostruct v
           end
          return OpenStruct.new clone
        else
          return clone
        end
      ostruct
    end
  end
end

