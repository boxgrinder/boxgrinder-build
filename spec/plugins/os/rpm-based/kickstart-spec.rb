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
require 'boxgrinder-build/plugins/os/rpm-based/kickstart'
require 'hashery/opencascade'

module BoxGrinder
  describe Kickstart do
    KICKSTART_FEDORA_REPOS = {
        "11" => {
            "base" => {"mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-11&arch=#BASE_ARCH#"},
            "updates" => {"mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f11&arch=#BASE_ARCH#"}
        }
    }

    def prepare_kickstart(repos = {})
      @config = mock('Config')
      @appliance_config = mock('ApplianceConfig')
      @dir = mock('Some directory')
      @dir.stub!(:tmp).and_return('baloney')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '11', :password => 'boxgrinder'}))
      @appliance_config.stub!(:packages).and_return(["gcc-c++", "wget"])
      @appliance_config.stub!(:repos).and_return(repos)

      @kickstart = Kickstart.new(@config, @appliance_config, @dir, OpenCascade.new(:base => 'a/base/dir'))
    end

    describe ".build_definition" do
      it "should prepare valid definition" do
        prepare_kickstart(KICKSTART_FEDORA_REPOS)

        @appliance_config.stub!(:hardware).and_return(
            OpenCascade.new({
                                :partitions =>
                                    {
                                        '/' => {'size' => 2},
                                        '/home' => {'size' => 3},
                                    },
                                :arch => 'i686',
                                :base_arch => 'i386'
                            })
        )

        @appliance_config.should_receive(:repos).and_return(
            [
                {'name' => 'cirras', 'baseurl' => "http://repo.boxgrinder.org/packages/fedora/11/RPMS/i686"},
                {'name' => 'abc', 'baseurl' => 'http://abc', 'mirrorlist' => "http://abc.org/packages/fedora/11/RPMS/i686"},
            ]
        )

        definition = @kickstart.build_definition

        definition['repos'].size.should == 2

        definition['repos'][0].should == "repo --name=cirras --cost=40 --baseurl=http://repo.boxgrinder.org/packages/fedora/11/RPMS/i686"
        definition['repos'][1].should == "repo --name=abc --cost=41 --mirrorlist=http://abc.org/packages/fedora/11/RPMS/i686"

        definition['appliance_config'].packages.size.should == 2
        definition['appliance_config'].packages.should == ["gcc-c++", "wget"]

        definition['appliance_config'].os.password.should == "boxgrinder"
        definition['appliance_config'].hardware.partitions.size.should == 2
        definition['appliance_config'].hardware.partitions['/']['size'].should == 2
        definition['appliance_config'].hardware.partitions['/home']['size'].should == 3
      end
    end
  end
end
