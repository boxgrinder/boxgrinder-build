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
require 'boxgrinder-build/plugins/delivery/local/local-plugin'
require 'hashery/opencascade'

module BoxGrinder
  describe LocalPlugin do

    before(:each) do
      @config = Config.new('plugins' => {'local' => {'path' => 'a/path'}})

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('appliance')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => :fedora, :version => '13'}))
      @appliance_config.stub!(:hardware).and_return(OpenCascade.new({:arch => 'x86_64'}))

      @plugin = LocalPlugin.new.init(@config, @appliance_config,
                                     {:class => BoxGrinder::LocalPlugin, :type => :delivery, :name => :local, :full_name => "Local file system"},
                                     :log => LogHelper.new(:level => :trace, :type => :stdout),
                                     :previous_plugin => OpenCascade.new(:deliverables => {:disk => "a_disk.raw", :metadata => 'metadata.xml'})
      )

      @plugin.validate

      @plugin_config = @config.plugins['local']
      @appliance_config = @plugin.instance_variable_get(:@appliance_config)
      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @log = @plugin.instance_variable_get(:@log)
      @dir = @plugin.instance_variable_get(:@dir)
    end

    describe ".execute" do
      it "should package and deliver the appliance" do
        @plugin_config.merge!('package' => true)
  
        FileUtils.should_receive(:mkdir_p).with('a/path')
        package_helper = mock(PackageHelper)
        PackageHelper.should_receive(:new).with(@config, @appliance_config, :log => @log, :exec_helper => @exec_helper).and_return(package_helper)
        package_helper.should_receive(:package).with('.', "a/path/appliance-1.0-fedora-13-x86_64-raw.tgz").and_return("deliverable")

        @plugin.execute
      end

      it "should not package, but deliver the appliance" do
        @plugin_config.merge!('package' => false) 

        FileUtils.should_receive(:mkdir_p).with('a/path')
        PackageHelper.should_not_receive(:new)

        @exec_helper.should_receive(:execute).with("cp 'a_disk.raw' 'a/path'")
        @exec_helper.should_receive(:execute).with("cp 'metadata.xml' 'a/path'")

        @plugin.execute
      end

      it "should not deliver the package, because it is already delivered" do
        @plugin.instance_variable_set(:@plugin_config, {
            'overwrite' => false,
            'path' => 'a/path',
            'package' => false
        })

        PackageHelper.should_not_receive(:new)

        @exec_helper.should_not_receive(:execute)
        @plugin.should_receive(:deliverables_exists?).and_return(true)

        @plugin.execute
      end
    end

    describe ".deliverables_exists?" do
      it "should return true for package" do
        @plugin_config.merge!('package' => true)

        File.should_receive(:exists?).with('a/path/appliance-1.0-fedora-13-x86_64-raw.tgz').and_return(true)

        @plugin.deliverables_exists?.should == true
      end

      it "should return true for non-packaged appliance" do
        @plugin_config.merge!('package' => false)

        File.should_receive(:exists?).with('a/path/a_disk.raw').and_return(true)
        File.should_receive(:exists?).with('a/path/metadata.xml').and_return(true)

        @plugin.deliverables_exists?.should == true
      end
    end
  end
end

