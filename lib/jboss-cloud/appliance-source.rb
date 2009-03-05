require 'r@configake/tasklib'

module JBossCloud
  class ApplianceSource < Rake::TaskLib
    def initialize( config, appliance_config )
      @config                = config
      @appliance_config      = appliance_config
      
      @appliance_dir         = "#{@config.dir_appliances}/#{@appliance_config.name}"
      @appliance_build_dir   = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      
      define
    end
    
    def define
      directory @appliance_build_dir
      
      source_files = FileList.new( "#{@appliance_dir}/*/**" )      
      source_tar_gz = "#{@config.dir_top}/#{@appliance_config.os_path}/SOURCES/#{@appliance_config.name}-#{@config.version}.tar.gz"
      
      file source_tar_gz => [ @appliance_build_dir, source_files, 'rpm:topdir' ].flatten do
        stage_directory = "#{@appliance_build_dir}/sources/#{@appliance_config.name}-#{@config.version}/appliances"
        FileUtils.rm_rf stage_directory
        FileUtils.mkdir_p stage_directory
        FileUtils.cp_r( "#{@appliance_dir}/", stage_directory  )
        
        defs = { }
        
        defs['appliance_name']        = @appliance_config.name
        defs['appliance_summary']     = @appliance_config.summary
        defs['appliance_version']     = @config.version_with_release
        
        def defs.method_missing(sym,*args)
          self[ sym.to_s ]
        end
        
        puppet_file = "#{stage_directory}/#{@appliance_config.name}/#{@appliance_config.name}.pp"
        
        erb = ERB.new( File.read( puppet_file ) )
        
        File.open( puppet_file, 'w' ) {|f| f.write( erb.result( defs.send( :binding ) ) ) }
        
        Dir.chdir( "#{@appliance_build_dir}/sources" ) do
          command = "tar zcvf #{@config.dir_root}/#{source_tar_gz} #{@appliance_config.name}-#{@config.version}/"
          execute_command( command )
        end
      end
      
      desc "Build source for #{@appliance_config.simple_name} appliance"
      task "appliance:#{@appliance_config.name}:source" => [ source_tar_gz ]
    end
    
  end
end
