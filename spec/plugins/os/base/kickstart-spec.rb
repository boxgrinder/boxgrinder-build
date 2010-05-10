require 'boxgrinder-build/plugins/os/base/kickstart'
require 'rspec-helpers/rspec-config-helper'

module BoxGrinder
  describe Kickstart do
    include RSpecConfigHelper

    before(:all) do
      @current_arch = (-1.size) == 8 ? "x86_64" : "i386"
    end

    def prepare_kickstart
      @kickstart = Kickstart.new( generate_config, generate_appliance_config, {} )
    end

    it "should prepare valid definition" do
      prepare_kickstart

      definition = @kickstart.build_definition

      definition['repos'].size.should == 3

      definition['repos'][0].should == "repo --name=cirras --cost=40 --baseurl=http://repo.boxgrinder.org/packages/fedora/11/RPMS/#{@current_arch}"
      definition['repos'][1].should == "repo --name=abc --cost=41 --mirrorlist=http://repo.boxgrinder.org/packages/fedora/11/RPMS/#{@current_arch}"
      definition['repos'][2].should == "repo --name=boxgrinder-f11-testing-#{@current_arch} --cost=42 --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=updates-testing-f11&arch=#{@current_arch}"

      definition['packages'].size.should == 5
      definition['packages'].should == ["gcc-c++", "wget", "kernel", "passwd", "lokkit"]

      definition['root_password'].should == "boxgrinder"
      definition['fstype'].should == "ext3"
    end
  end
end

