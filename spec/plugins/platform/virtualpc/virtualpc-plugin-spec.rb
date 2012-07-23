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

require 'boxgrinder-build/plugins/platform/virtualpc/virtualpc-plugin.rb'

module BoxGrinder
  describe VirtualPCPlugin do
    def prepare_image(options = {})
      @config = mock('Config')
      @config.stub!(:platform_config).and_return({})
      @config.stub!(:[]).with(:plugins).and_return({})

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade[{:build => 'build/path'}])
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:summary).and_return('asd')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade[{:name => 'fedora', :version => '16'}])
      @appliance_config.stub!(:post).and_return(OpenCascade[{:virtualpc => []}])

      @appliance_config.stub!(:hardware).and_return(
          OpenCascade[{
                              :partitions =>
                                  {
                                      '/' => {'size' => 2},
                                      '/home' => {'size' => 3},
                                  },
                              :arch => 'i686',
                              :base_arch => 'i386',
                              :cpus => 1,
                              :memory => 256,
                          }]
      )

      @plugin = RSpecPluginHelper.new(VirtualPCPlugin).prepare(@config, @appliance_config,
        :previous_plugin => OpenCascade[:deliverables => {:disk => 'a/base/image/path.raw'}],
        :plugin_info => {:class => BoxGrinder::VirtualPCPlugin, :type => :platform, :name => :virtualpc, :full_name => "VirtualPC"}
      )

      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @image_helper = @plugin.instance_variable_get(:@image_helper)
    end

    before(:each) do
      prepare_image
    end

    describe ".execute" do
      it "should convert an image to virtualpc format without post commands" do
        @image_helper.should_not_receive(:customize)
        @image_helper.should_receive(:convert_disk).with("a/base/image/path.raw", :vpc, "build/path/virtualpc-plugin/tmp/full.vhd")
        @plugin.execute
      end

      it "should convert an image to virtualpc format with post commands" do
        @appliance_config.post['virtualpc'] = ["one", "two", "three"]

        guestfs_mock = mock("GuestFS")
        guestfs_helper_mock = mock("GuestFSHelper")

        @image_helper.should_receive(:customize).with("build/path/virtualpc-plugin/tmp/full.vhd").and_yield(guestfs_mock, guestfs_helper_mock)

        guestfs_helper_mock.should_receive(:sh).once.ordered.with("one", :arch => 'i686')
        guestfs_helper_mock.should_receive(:sh).once.ordered.with("two", :arch => 'i686')
        guestfs_helper_mock.should_receive(:sh).once.ordered.with("three", :arch => 'i686')

        @image_helper.should_receive(:convert_disk).with("a/base/image/path.raw", :vpc, "build/path/virtualpc-plugin/tmp/full.vhd")
        @plugin.execute
      end
    end
  end
end
