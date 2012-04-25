module BoxGrinder
  module EBS
    module Messages
      EPHEMERAL_MESSAGE = <<-DOC 
#{%(As of version 0.10.2 BoxGrinder no longer *attaches* or *mounts* any 
ephemeral disks by default for EBS AMIs.).bold}

It is still possible to specify device mappings at build-time if you desire by
using: 
 #{%(--delivery-config block_device_mappings:"/dev/sdb=ephemeral0&/dev/sdc=ephemeral1").bold}

You may specify additional EBS devices to be created and attached at launch-time, 
see documentation for examples.

Alternatively, mappings can be specified at launch-time rather than build-time.
 
For fuller details, including an outline of terminology and different strategies
for attaching and mounting, see the following resource: 
  #{%(http://www.boxgrinder.org/permalink/ephemeral#ebs).bold}
DOC
    end
  end
end
