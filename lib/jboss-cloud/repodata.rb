require 'rake/tasklib'

module JBossCloud
  class Repodata < Rake::TaskLib

    def initialize( config )
      @config = config
      @topdir = @config.dir_top
      @arches = SUPPORTED_ARCHES + [ "noarch" ]
      @oses   = SUPPORTED_OSES
      define
    end

    def define
      desc "Force a rebuild of the repository data"
      task "rpm:repodata:force" => [ 'rpm:topdir' ] do
        for os in @oses.keys
          for version in @oses[os]
            for arch in @arches
              execute_command( "createrepo --update #{@topdir}/#{os}/#{version}/RPMS/#{arch}" )
            end
          end
        end
      end

      # TODO this isn't used, is it required?
      desc "Build repository data"
      task 'rpm:repodata' => [ 'rpm:topdir' ] do
        for os in @oses.keys
          for version in @oses[os]
            for arch in @arches
              file "#{@topdir}/#{os}/#{version}/RPMS/#{arch}/repodata/repomd.xml" => FileList.new( "#{@topdir}/#{os}/#{version}/RPMS/#{arch}/*.rpm" ) do
                execute_command( "createrepo --update #{@topdir}/#{os}/#{version}/RPMS/#{arch}" )
              end
              task 'rpm:repodata' => "#{@topdir}/#{os}/#{version}/RPMS/#{arch}/repodata/repomd.xml"
            end
          end
        end
      end
    end
  end
end
