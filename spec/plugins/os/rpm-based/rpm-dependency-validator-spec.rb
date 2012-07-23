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

require 'boxgrinder-build/plugins/os/rpm-based/rpm-dependency-validator'
require 'hashery/open_cascade'

module BoxGrinder
  describe RPMDependencyValidator do
    before(:each) do
      @config = mock('Config')
      @appliance_config = mock('ApplianceConfig')
      plugins = mock('Plugins')
      plugins.stub!(:[]).with('rpm_based').and_return({})
      @config.stub!(:[]).with(:plugins).and_return(plugins)

      @appliance_config.stub!(:path).and_return(OpenCascade[{:build => 'build/path'}])
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:hardware).and_return(OpenCascade[:arch => 'i386'])
      @appliance_config.stub!(:os).and_return(OpenCascade[{:name => 'fedora', :version => '11'}])

      @validator = RPMDependencyValidator.new(@config, @appliance_config, OpenCascade[:tmp => 'tmp'])
    end

    describe ".generate_yum_config" do
      it "should create a yum config also with an url with tilde character" do
        Dir.should_receive(:pwd).and_return('/dir')

        @appliance_config.stub!(:version).and_return(1)
        @appliance_config.stub!(:repos).and_return([{'name' => 'name', 'mirrorlist' => 'mirror~list'}])

        file = mock(File)
        file.should_receive(:puts).with("[main]\r\ncachedir=/dir/tmp/boxgrinder-i386-yum-cache/\r\n\r\n")
        file.should_receive(:puts).with("[boxgrinder-name]")
        file.should_receive(:puts).with("name=name")
        file.should_receive(:puts).with("mirrorlist=mirror~list")
        file.should_receive(:puts).with("enabled=1")
        file.should_receive(:puts)

        File.should_receive(:open).with("tmp/yum.conf", "w").and_yield(file)

        @validator.generate_yum_config
      end
    end
  end
end

