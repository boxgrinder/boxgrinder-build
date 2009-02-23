require 'rake/tasklib'
require 'rexml/document'

module JBossCloud

  class ApplianceVMXImage < Rake::TaskLib

    def initialize( config )

      @config                 = config
      appliance_build_dir     = "#{Config.get.dir_build}/appliances/#{@config.arch}/#{@config.name}"
      @appliance_xml_file     = "#{appliance_build_dir}/#{@config.name}.xml"

      define
    end

    def define
      define_precursors
    end

    # returns value of cylinders, heads and sector for selected disk size (in MB)
    def generate_scsi_chs(disk_size)

      gb_sectors = 2097152
      
      if disk_size == 1024
        h = 128
        s = 32
      else
        h = 255
        s = 63
      end

      c = disk_size / 1024 * gb_sectors / (h*s)
      total_sectors = gb_sectors * disk_size / 1024

      return [ c, h, s, total_sectors ]
    end

    def change_vmdk_values( vmdk_data )
      
      c, h, s, total_sectors = generate_scsi_chs( @config.disk_size )

      vmdk_data.gsub!( /#NAME#/ , @config.name )
      vmdk_data.gsub!( /#CYLINDERS#/ , c.to_s )
      vmdk_data.gsub!( /#HEADS#/ , h.to_s )
      vmdk_data.gsub!( /#SECTORS#/ , s.to_s )
      vmdk_data.gsub!( /#TOTAL_SECTORS#/ , total_sectors.to_s )
      
      return vmdk_data
    end

    def change_common_vmx_values( vmx_data )
      # replace version with current jboss cloud version
      vmx_data.gsub!( /#VERSION#/ , JBossCloud::Config.get.version_with_release )
      # change name
      vmx_data.gsub!( /#NAME#/ , @config.name )
      # replace guestOS informations to: linux or otherlinux-64, this seems to be the savests values
      vmx_data.gsub!( /#GUESTOS#/ , "#{@config.arch == "x86_64" ? "otherlinux-64" : "linux"}" )
      # memory size
      vmx_data.gsub!( /#MEM_SIZE#/ , @config.mem_size.to_s )
      # memory size
      vmx_data.gsub!( /#VCPU#/ , @config.vcpu.to_s )
      # network name
      vmx_data += "\nethernet0.networkName = \"#{@config.network_name}\""

      return vmx_data
    end

    def define_precursors
      super_simple_name = File.basename( @config.name, '-appliance' )
      vmware_personal_output_folder = File.dirname( @appliance_xml_file ) + "/vmware/personal"
      vmware_personal_vmx_file = vmware_personal_output_folder + "/" + File.basename( @appliance_xml_file, ".xml" ) + '.vmx'
      vmware_enterprise_output_folder = File.dirname( @appliance_xml_file ) + "/vmware/enterprise"
      vmware_enterprise_vmx_file = vmware_enterprise_output_folder + "/" + File.basename( @appliance_xml_file, ".xml" ) + '.vmx'
      vmware_enterprise_vmdk_file = vmware_enterprise_output_folder + "/" + File.basename( @appliance_xml_file, ".xml" ) + '.vmdk'

      file "#{@appliance_xml_file}.vmx-input" => [ @appliance_xml_file ] do
        doc = REXML::Document.new( File.read( @appliance_xml_file ) )
        name_elem = doc.root.elements['name']
        name_elem.attributes[ 'version' ] = "#{JBossCloud::Config.get.version_with_release}"
        description_elem = doc.root.elements['description']
        if ( description_elem.nil? )
          description_elem = REXML::Element.new( "description" )
          description_elem.text = "#{@config.name} Appliance\n Version: #{JBossCloud::Config.get.version_with_release}"
          doc.root.insert_after( name_elem, description_elem )
        end
        # update xml the file according to selected build architecture
        arch_elem = doc.elements["//arch"]
        arch_elem.text = @config.arch
        File.open( "#{@appliance_xml_file}.vmx-input", 'w' ) {|f| f.write( doc ) }
      end

      desc "Build #{super_simple_name} appliance for VMware personal environments (Server/Workstation/Fusion)"
      task "appliance:#{@config.name}:vmware:personal" => [ "#{@appliance_xml_file}.vmx-input" ] do
        FileUtils.mkdir_p vmware_personal_output_folder

        if ( !File.exists?( vmware_personal_vmx_file ) || File.new( "#{@appliance_xml_file}.vmx-input" ).mtime > File.new( vmware_personal_vmx_file ).mtime  )
          puts "Creating VMware personal disk..."
          execute_command( "#{Dir.pwd}/lib/python-virtinst/virt-convert -o vmx -D vmdk #{@appliance_xml_file}.vmx-input #{vmware_personal_output_folder}/" )
        end

        vmx_data = File.open( "src/base.vmx" ).read
        vmx_data = change_common_vmx_values( vmx_data )

        # disk filename must match
        vmx_data.gsub!(/#{@config.name}.vmdk/, "#{@config.name}-sda.vmdk")

        # write changes to file
        File.new( vmware_personal_vmx_file , "w+" ).puts( vmx_data )
      end

      desc "Build #{super_simple_name} appliance for VMware enterprise environments (ESX/ESXi)"
      task "appliance:#{@config.name}:vmware:enterprise" => [ @appliance_xml_file ] do
        FileUtils.mkdir_p vmware_enterprise_output_folder

        base_raw_file = File.dirname( @appliance_xml_file ) + "/#{@config.name}-sda.raw"
        vmware_raw_file = vmware_enterprise_output_folder + "/#{@config.name}-sda.raw"

        # copy RAW disk to VMware enterprise destination folder
        # todo: consider moving this file

        if ( !File.exists?( vmware_raw_file ) || File.new( base_raw_file ).mtime > File.new( vmware_raw_file ).mtime )
          puts "Creating VMware enterprise disk..."
          FileUtils.cp( base_raw_file , vmware_enterprise_output_folder )
        end

        vmx_data = File.open( "src/base.vmx" ).read
        vmx_data = change_common_vmx_values( vmx_data )
        
        # replace IDE disk with SCSI, it's recommended for workstation and required for ESX
        vmx_data.gsub!( /ide0:0/ , "scsi0:0" )

        # yes, we want a SCSI controller because we have SCSI disks!
        vmx_data += "\nscsi0.present = \"true\""
        vmx_data += "\nscsi0.virtualDev = \"lsilogic\""

        # write changes to file
        File.new( vmware_enterprise_vmx_file , "w+" ).puts( vmx_data )

        # create new VMDK descriptor file
        File.new( vmware_enterprise_vmdk_file, "w+" ).puts( change_vmdk_values( File.open( "src/base.vmdk" ).read ) )

      end

      #desc "Build #{super_simple_name} appliance for VMware"
      #task "appliance:#{@config.name}:vmware" => [ "appliance:#{@config.name}:vmware:personal", "appliance:#{@config.name}:vmware:enterprise" ]
    end
  end
end
