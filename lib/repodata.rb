require 'rake/tasklib'

module JBossCloud
  class Repodata < Rake::TaskLib

    def initialize(arches)
      @topdir = Config.get.dir_top
      @arches = arches
      define
    end

    def define
      desc "Force a rebuild of the repository data"
      task "rpm:repodata:force"=>[ 'rpm:topdir' ] do
        for arch in @arches
          execute_command( "createrepo --update #{@topdir}/RPMS/#{arch}" )
        end
      end

      desc "Build repository data"
      task 'rpm:repodata'

      for arch in @arches
        file "#{@topdir}/RPMS/#{arch}/repodata/repomd.xml"=>FileList.new( "#{@topdir}/RPMS/#{arch}/*.rpm" ) do
          execute_command( "createrepo --update #{@topdir}/RPMS/#{arch}" )
        end
        task 'rpm:repodata' => "#{@topdir}/RPMS/#{arch}/repodata/repomd.xml"
      end

    end
  end
end
