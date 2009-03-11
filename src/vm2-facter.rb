
if ( File.exist?( "/etc/vm2-user-data.conf" ) )
  File.open( "/etc/vm2-user-data.conf" ).each_line do |line|
    name, value = line.split("=")
    name.strip!
    value.strip!
    Facter.add( "vm2_#{name}".downcase ) do
      setcode do
        value
      end
    end
  end
end
