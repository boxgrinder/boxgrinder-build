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

require 'logger'
require 'boxgrinder-build/helpers/package-helper'

module BoxGrinder
  describe PackageHelper do
    before(:each) do
      @config = mock('Config')
      @appliance_config = mock('ApplianceConfig')
      @exec_helper = mock(ExecHelper)
      @log = Logger.new('/dev/null')
      @appliance_config.stub!(:name).and_return('jeos-f13')

      @helper = PackageHelper.new(@config, @appliance_config, :log => @log, :exec_helper => @exec_helper)
    end

    it "should package deliverables" do
      File.should_receive(:exists?).with('destination/package.tgz').and_return(false)
      File.should_receive(:expand_path).with('a/dir').and_return('a/dir/expanded')
      FileUtils.should_receive(:ln_s).with("a/dir/expanded", "destination/package")
      FileUtils.should_receive(:rm).with("destination/package")

      @exec_helper.should_receive(:execute).with('tar -C destination -hcvzf destination/package.tgz package')

      @helper.package('a/dir', 'destination/package.tgz')
    end

    it "should NOT package deliverables if pacakge already exists" do
      File.should_receive(:exists?).with('destination/package.tgz').and_return(true)

      @exec_helper.should_not_receive(:execute)

      @helper.package('a/dir', 'destination/package.tgz')
    end

    it "should raise if unsupported format is specified" do
      lambda {
        @helper.package('a/dir', 'destination/package.tgz', :xyz)
      }.should raise_error("Specified format: 'xyz' is currently unsupported.")
    end
  end
end
