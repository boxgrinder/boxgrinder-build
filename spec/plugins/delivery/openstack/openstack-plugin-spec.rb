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

require 'boxgrinder-build/plugins/delivery/openstack/openstack-plugin'

module BoxGrinder
  describe OpenStackPlugin do
    before(:each) do
      @config = Config.new #('plugins' => {'openstack' => {'host' => 'a/path'}})
      @plugin = OpenStackPlugin.new

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
          {:class => BoxGrinder::OpenStackPlugin, :type => :delivery, :name => :openstack, :full_name => "OpenStack"},
          :log => LogHelper.new(:level => :trace, :type => :stdout),
          :previous_plugin => OpenCascade.new(:type => :os, :deliverables => {:disk => "a_disk.raw", :metadata => 'metadata.xml'})
      )
    end

    describe ".get_images" do
      it "should get list of all images" do

        RestClient.stub!(:get)
        RestClient.should_receive(:get).with('http://localhost:9292/v1/images', :params => {}).and_return({"images" => [{"id" => 1}]}.to_json)

        @plugin.get_images.should == [{"id" => 1}]
      end

      it "should get list of filtered images" do

        RestClient.stub!(:get)
        RestClient.should_receive(:get).with('http://localhost:9292/v1/images', :params => {:name => 'xyz'}).and_return({"images" => [{"id" => 1}]}.to_json)

        @plugin.get_images(:name => "xyz").should == [{"id" => 1}]
      end
    end

    describe ".delete_image" do
      it "should delete selected image" do
        RestClient.stub!(:delete)
        RestClient.should_receive(:delete).with('http://localhost:9292/v1/images/1')
        @plugin.delete_image(1)
      end
    end

    describe ".disk_and_container_format" do
      it "should specify valid disk and container format for vmware" do
        @plugin.instance_variable_set(:@previous_plugin_info, :type => :platform, :name => :vmware)
        @plugin.disk_and_container_format.should == [:vmdk, :bare]
      end

      it "should specify valid disk and container format for ec2" do
        @plugin.instance_variable_set(:@previous_plugin_info, :type => :platform, :name => :ec2)
        @plugin.disk_and_container_format.should == [:ami, :ami]
      end

      it "should specify valid disk and container format for virtualbox" do
        @plugin.instance_variable_set(:@previous_plugin_info, :type => :platform, :name => :virtualbox)
        @plugin.disk_and_container_format.should == [:vmdk, :bare]
      end

      it "should specify valid disk and container format for deliverables of os plugin" do
        @plugin.instance_variable_set(:@previous_plugin_info, :type => :os, :name => :fedora)
        @plugin.disk_and_container_format.should == [:raw, :bare]
      end
    end

    describe ".post_image" do
      it "should post the image" do
        File.stub!(:new)
        File.stub!(:size)
        File.should_receive(:new).with('a_disk.raw', 'rb').and_return('file')
        File.should_receive(:size).with('a_disk.raw').and_return(12345)
        RestClient.stub!(:post)
        RestClient.should_receive(:post).with('http://localhost:9292/v1/images', 'file', "x-image-meta-name"=>"appliance_name-1.0-raw", :content_type=>"application/octet-stream", "x-image-meta-is-public"=>"true", "x-image-meta-size"=>12345, "x-image-meta-property-distro"=>"Fedora 14", "x-image-meta-container-format"=>:bare, "x-image-meta-disk-format"=>:raw).and_return({"image" => {"id" => 1}}.to_json)

        @plugin.post_image
      end
    end
  end
end

