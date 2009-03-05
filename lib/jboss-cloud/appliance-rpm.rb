module JBossCloud
  class ApplianceRPM < JBossCloud::RPM
    
    def initialize( config, appliance_config )
      @config            = config
      @appliance_config  = appliance_config
      
      define
    end
    
    def define
      appliance_build_dir   = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      spec_file             = "#{appliance_build_dir}/#{@appliance_config.name}.spec"
      simple_name           = File.basename( spec_file, ".spec" )
      rpm_file              = "#{@config.dir_top}/#{@appliance_config.os_path}/RPMS/noarch/#{simple_name}-#{@config.version_with_release}.noarch.rpm"
      
      JBossCloud::RPM.provides[simple_name] = "#{simple_name}-#{@config.version_with_release}"
      
      desc "Build #{simple_name} RPM."
      task "rpm:#{simple_name}"=>[ rpm_file ]
      
      file rpm_file => [ spec_file, "#{@config.dir_top}/#{@appliance_config.os_path}/SOURCES/#{simple_name}-#{@config.version}.tar.gz", 'rpm:topdir' ] do
        Dir.chdir( File.dirname( spec_file ) ) do
          exit_status = execute_command "rpmbuild --define '_topdir #{@config.dir_root}/#{@config.dir_top}/#{@config.os_name}/#{@config.os_version}' --target noarch -ba #{simple_name}.spec"
          unless exit_status
            puts "\nBuilding #{simple_name} failed! Hint: consult above messages.\n\r"
            abort
          end
        end
      end
      
      file rpm_file=> [ 'rpm:dkms-open-vm-tools' ]
      file rpm_file=> [ 'rpm:vm2-support' ]
      file rpm_file=> [ 'rpm:oddthesis-repo' ]
      
    end
    
  end
end
