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
require 'boxgrinder-build/helpers/s3-helper'
require 'aws-sdk'

module BoxGrinder
  describe S3Helper do

    before(:each) do
      AWS.stub!
      AWS.config({:access_key_id => '', :secret_access_key => ''})
      @ec2 = AWS::EC2.new
      @s3 = AWS::S3.new
      @ec2helper = EC2Helper.new(@ec2)
      @s3helper = S3Helper.new(@ec2, @s3)
      @s3obj = mock(AWS::S3::S3Object)
      @bucket = mock(AWS::S3::Bucket)
    end

    describe ".bucket" do

      it "should return the existing bucket if it already exists" do
          @bucket.stub!(:exists).and_return(true)
          @s3.stub_chain(:buckets, :[]).and_return(@bucket)

          @s3.buckets.should_receive(:[]).with('tolstoy').and_return(@bucket)
          @bucket.should_receive(:exists?).and_return(true)

          @s3helper.bucket(:bucket => 'tolstoy').should == @bucket
      end

      context "when the bucket does not yet exist"  do

        before(:each) do
          @bucket.stub!(:exists).and_return(false)
          @s3.stub_chain(:buckets, :[]).and_return(@bucket)
          @s3.stub_chain(:buckets, :create).and_return(@bucket_real)

          @bucket_real = mock(AWS::S3::Bucket)
          @bucket_real.stub!(:exists).and_return(true)
        end

        context ":create_if_missing" do

          it "should return nil if :create_if_missing is not set" do
            @s3.buckets.should_receive(:[]).with('tolstoy').and_return(@bucket)
            @bucket.should_receive(:exists?).once.and_return(false)
            @s3helper.bucket(:bucket => 'tolstoy').should == nil
          end

          context "When :create_if_missing is set" do

            it "should return a bucket, with other settings defaulted" do
              @s3.buckets.should_receive(:[]).with('tolstoy').and_return(@bucket)
              @bucket.should_receive(:exists?).once.and_return(false)
              @s3.buckets.
                  should_receive(:create).
                  once.
                  with('tolstoy', :acl => :private, :location_constraint => 'us-east-1').
                  and_return(@bucket_real)

              @s3helper.bucket(:bucket => 'tolstoy', :create_if_missing => true).should == @bucket_real
            end

            it "should return a bucket assigned with the attributes provided by the user" do
                @s3.buckets.should_receive(:[]).with('tolstoy').and_return(@bucket)
                @bucket.should_receive(:exists?).once.and_return(false)
                @s3.buckets.
                    should_receive(:create).
                    once.
                    with('tolstoy', :acl => :ham, :location_constraint => 'biscuit').
                    and_return(@bucket_real)

                @s3helper.bucket(:bucket => 'tolstoy',  :create_if_missing => true,
                                 :acl => :ham, :location_constraint => 'biscuit').should == @bucket_real
            end

          end
        end
      end
    end

    describe ".object_exists?"  do

      it "should return true if the object exists" do
        @s3obj.stub!(:exists?).and_return(true)
        @s3obj.should_receive(:exists?).and_return(true)
        @s3helper.object_exists?(@s3obj).should == true
      end

      it "should return false if the object does not exist" do
        @s3obj.stub!(:exists?).and_return(false)
        @s3obj.should_receive(:exists?).and_return(false)
        @s3helper.object_exists?(@s3obj).should == false
      end

    end

    describe ".delete_folder" do

      it "should delete a folder from a bucket" do
        object = mock(AWS::S3::S3Object)
        objects = [object]

        @bucket.stub!(:objects)
        @bucket.objects.
            should_receive(:with_prefix).
            with('cacoethes/carpendi').
            and_return(objects)

        object.should_receive(:delete).once

        @s3helper.delete_folder(@bucket, '/cacoethes/carpendi/')
      end

    end

    describe ".stub_s3obj" do

      it "should return a stub AWS::S3::S3Object associated with the specified bucket" do
        object = mock(AWS::S3::S3Object)
        objects = mock(AWS::S3::ObjectCollection)
        objects.stub!(:[]).and_return(object)
        objects.stub!(:to_sym).and_return(:anything)

        @bucket.stub!(objects).and_return(objects)
        @bucket.should_receive(:objects).and_return(objects)
        objects.should_receive(:[]).and_return(object)

        @s3helper.stub_s3obj(@bucket, 'vini/vidi/vici') == @s3obj
      end

    end

    describe ".parse_path" do

      it "should return root if is empty" do
        @s3helper.parse_path('').should == '/'
      end

      it "should remove extranous slashes" do
        @s3helper.parse_path('//cave/canem//').
            should == 'cave/canem/'
      end

    end


  end
end