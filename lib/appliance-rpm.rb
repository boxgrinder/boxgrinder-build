
module JBossCloud
  class ApplianceRPM < JBossCloud::RPM

    def initialize( config )
      @config       = config
      @topdir       = Config.get.dir_top
      @version      = Config.get.version
      @release      = Config.get.release
      define
    end

    def define
      appliance_build_dir   = "#{Config.get.dir_build}/appliances/#{@config.arch}/#{@config.name}"
      spec_file             = "#{appliance_build_dir}/#{@config.name}.spec"
      simple_name           = File.basename( spec_file, ".spec" )
      rpm_file              = "#{@topdir}/RPMS/noarch/#{simple_name}-#{@version}-#{@release}.noarch.rpm"

      JBossCloud::RPM.provides[simple_name] = "#{simple_name}-#{@version}-#{@release}"

      desc "Build #{simple_name} RPM."
      task "rpm:#{simple_name}"=>[ rpm_file ]

      file rpm_file => [ spec_file, "#{@topdir}/SOURCES/#{simple_name}-#{@version}.tar.gz", 'rpm:topdir' ] do
        Dir.chdir( File.dirname( spec_file ) ) do
          exit_status = execute_command "rpmbuild --define '_topdir #{Config.get.dir_root}/#{@topdir}' --target noarch -ba #{simple_name}.spec"
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
