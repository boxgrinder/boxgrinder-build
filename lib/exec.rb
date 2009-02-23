require 'open4/open4'

def execute_command(cmd)
  return execute(cmd, true)
end

def execute(cmd, verbose)
  old_trap = trap("INT") do
    puts "caught SIGINT, shutting down"
  end
  exit_status = Open4.popen4( cmd ) do |pid, stdin, stdout, stderr|
    #stdin.close
    if verbose
      threads = []
      threads << Thread.new(stdout) do |input_str|
        while ( ( l = input_str.gets ) != nil )
          puts l
        end
      end
      threads << Thread.new(stderr) do |input_str|
        while ( ( l = input_str.gets ) != nil )
          puts l
        end
      end
      threads.each{|t|t.join}
    end
  end

  trap("INT", old_trap )

  puts "\r\nCommand '#{cmd}' failed with exit status #{exit_status.exitstatus}" unless exit_status.success? if verbose
  
  return exit_status.success?
end
