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

require 'rspec'
require 'boxgrinder-build/helpers/ec2-helper'
require 'aws-sdk'

module BoxGrinder
  describe EC2Helper do

    FAST_POLL = 0.1
    FAST_TO   = 1

    before(:each) do
      AWS.stub!
      AWS.config({:access_key_id => '', :secret_access_key => ''})
      @ec2 = AWS::EC2.new()
      @ec2helper = EC2Helper.new(@ec2)
      @ami = mock(AWS::EC2::Image)
      @instance = mock(AWS::EC2::Instance)
      @snapshot = mock(AWS::EC2::Snapshot)
      @volume = mock(AWS::EC2::Volume)
    end

    describe ".wait_for_image_state" do
      before(:each) do
        @ami.stub!(:state).and_return(:ham, :biscuit, :available)
      end

      it "should wait until the image state is :available before returning" do
        @ami.stub(:exists?).and_return(true)

        @ami.should_receive(:exists?).once.and_return(true)
        @ami.should_receive(:state).exactly(3).times
        @ec2helper.wait_for_image_state(:available, @ami, :frequency => FAST_POLL, :timeout => FAST_TO)
      end

      it "should wait until the image exists before sampling for state" do
        @ami.stub(:exists?).and_return(false, false, true)

        @ami.should_receive(:exists?).once.exactly(3).times
        @ami.should_receive(:state).exactly(3).times
        @ec2helper.wait_for_image_state(:available, @ami, :frequency => FAST_POLL, :timeout => FAST_TO)
      end
    end

    describe ".wait_for_image_death" do
      it "should wait until image no longer exists" do
        @ami.stub!(:exists?).and_return(true, true, false)

        @ami.should_receive(:exists?).exactly(3).times
        @ec2helper.wait_for_image_death(@ami, :frequency => FAST_POLL, :timeout => FAST_TO)
      end

      it "should return normally if InvalidImageID::NotFound error occurs" do
        @ami.stub!(:exists?).and_raise(aws_sdk_exception_hack(AWS::EC2::Errors::InvalidImageID::NotFound))

        @ami.should_receive(:exists?).once
        @ec2helper.wait_for_image_death(@ami, :frequency => FAST_POLL, :timeout => FAST_TO)
      end
    end

    describe ".wait_for_instance_status" do
      it "should wait until the instance status is :available before returning" do
        @instance.stub!(:status).and_return(:bacon, :buttie, :available)

        @instance.should_receive(:status).exactly(3).times
        @ec2helper.wait_for_instance_status(:available, @instance, :frequency => FAST_POLL, :timeout => FAST_TO)
      end
    end

    describe ".wait_for_instance_death" do
      it "should wait until instance status is :terminated before returning" do
        @instance.stub!(:exists?).and_return(true)
        @instance.stub!(:status).and_return(:stottie, :bread, :terminated)

        @instance.should_receive(:status).exactly(3).times
        @ec2helper.wait_for_instance_death(@instance, :frequency => FAST_POLL, :timeout => FAST_TO)
      end

      it "should return normally if InvalidInstance::NotFound error occurs" do
        @instance.stub!(:exists?).and_return(true)
        @instance.stub!(:status).and_raise(aws_sdk_exception_hack(AWS::EC2::Errors::InvalidInstanceID::NotFound))

        @instance.should_receive(:exists?).once
        @instance.should_receive(:status).once
        @ec2helper.wait_for_instance_death(@instance, :frequency => FAST_POLL, :timeout => FAST_TO)
      end

      it "should return immediately if the instance does not appear to exist at all" do
        @instance.stub!(:exists?).and_return(false)

        @instance.should_receive(:exists?).once
        @ec2helper.wait_for_instance_death(@instance, :frequency => FAST_POLL, :timeout => FAST_TO)
      end
    end

    describe ".wait_for_snapshot_status" do
      it "should wait until the instance status is :completed before returning" do
        @snapshot.stub!(:status).and_return(:crumpet, :tea, :completed, :cricket)
        @snapshot.stub!(:progress).and_return(99)

        @snapshot.should_receive(:status).exactly(3).times
        @ec2helper.wait_for_snapshot_status(:completed, @snapshot, :frequency => FAST_POLL, :timeout => FAST_TO)
      end
    end

    describe ".wait_for_volume_status" do
      it "should wait until the instance status is :available before returning" do
        @volume.stub!(:status).and_return(:edictum, :imperatoris, :available)

        @volume.should_receive(:status).exactly(3).times
        @ec2helper.wait_for_volume_status(:available, @volume, :frequency => FAST_POLL, :timeout => FAST_TO)
      end
    end

    describe ".current_availability_zone" do
      it "should return the current availability zone" do
        EC2Helper.stub!(:get_meta_data).and_return('protuberant-potato-1a')

        EC2Helper.should_receive(:get_meta_data).
            with('/latest/meta-data/placement/availability-zone/').
            and_return('protuberant-potato-1a')
        EC2Helper.current_availability_zone.should == 'protuberant-potato-1a'
      end
    end

    describe ".current_instance_id" do
      it "should return the current instance id" do
        EC2Helper.stub!(:get_meta_data).and_return('voluminous-verbiage')

        EC2Helper.should_receive(:get_meta_data).
            with('/latest/meta-data/instance-id').
            and_return('voluminous-verbiage')
        EC2Helper.current_instance_id.should == 'voluminous-verbiage'
      end
    end

    describe ".availability_zone_to_region" do
      it "should convert an availability zone to a region" do
        EC2Helper.availability_zone_to_region('protuberant-potato-1a').
            should == 'protuberant-potato-1'
      end
    end

    describe ".ami_by_name" do
      before(:each) do
        @ec2.stub!(:images)
      end

      it "should query for an image filtered by name" do
        @ec2.should_receive(:images)
        @ec2.images.should_receive(:with_owner).with('987654321')
        @ec2.images.should_receive(:filter).with('name','inauspicious-interlocution').and_return([@ami])

        @ec2helper.ami_by_name('inauspicious-interlocution', '987654321').should == @ami
      end

      it "should return nil if no results are returned" do
        @ec2.should_receive(:images)
        @ec2.images.should_receive(:with_owner).with('987654321')
        @ec2.images.should_receive(:filter).with('name','inauspicious-interlocution').and_return([])

        @ec2helper.ami_by_name('inauspicious-interlocution', '987654321').should == nil
      end
    end

    describe ".snapshot_by_id" do
      before(:each) do
        snap_mock = mock('snapshots')
        @ec2.stub!(:snapshots).and_return(snap_mock)
      end

      it "should query for a snapshot by snapshot-id" do

        @ec2.snapshots.
            should_receive(:filter).
            with('snapshot-id','count-bezukhov').
            and_return([@snapshot])

        @ec2helper.snapshot_by_id('count-bezukhov').should == @snapshot

      end

      it "should return nil if no results are returned" do
        @ec2.snapshots.
            should_receive(:filter).
            with('snapshot-id','count-bezukhov').
            and_return([])

        @ec2helper.snapshot_by_id('count-bezukhov').should == nil
      end

    end

    describe ".live_instances" do
      before(:each) do
        instances_mock = mock('instances')
        @ec2.stub!(:instances).and_return(instances_mock)

        @instance_1 = mock(AWS::EC2::Instance)
        @instance_2 = mock(AWS::EC2::Instance)
        @instance_3 = mock(AWS::EC2::Instance)

        @instance_1.stub!(:status).and_return(:available)
        @instance_2.stub!(:status).and_return(:available)
        @ami.stub!(:id).and_return('war-and-peace')
      end

      it "should query for live instances by ami" do
        @ec2.instances.
            should_receive(:filter).
            with('image-id','war-and-peace').
            and_return([@instance_1, @instance_2])

        @ec2helper.live_instances(@ami).should == [@instance_1, @instance_2]
      end

      it "should ignore any :terminated instances" do
        @instance_3.stub!(:status).and_return(:terminated)

        @ec2.should_receive(:instances)
        @ec2.instances.should_receive(:filter).
            with('image-id','war-and-peace').
            and_return([@instance_3, @instance_2, @instance_1])

        @ec2helper.live_instances(@ami).should == [@instance_2, @instance_1]
      end

    end

    describe ".endpoints" do

    end

    # Complex auto-generated exceptions means we can't use the normal method of raising
    def aws_sdk_exception_hack(klass)
      mock_param = mock('fake_param')
      mock_param.stub!(:status).and_return(1)
      mock_param.stub!(:body).and_return('')
      klass.new(mock_param, mock_param)
    end

  end
end