require "test/unit"

require 'jboss-cloud/config'

class ApplianceConfigTest < Test::Unit::TestCase
  def test_hash_with_empty_appliances_list
    assert_nothing_raised do
      JBossCloud::ApplianceConfig.new("really-good-appliance", "i386", "fedora", "10").hash
    end
  end
  
  def test_simple_name_with_appliance_at_the_end
    appliance_config = JBossCloud::ApplianceConfig.new("really-good-appliance", "i386", "fedora", "10")
    
    assert_equal(appliance_config.simple_name, "really-good")
  end
  
  def test_simple_name_without_appliance_at_the_end
    appliance_config = JBossCloud::ApplianceConfig.new("really-good", "i386", "fedora", "10")
    
    assert_equal(appliance_config.simple_name, "really-good")
  end
  
  def test_os_path
    appliance_config = JBossCloud::ApplianceConfig.new("really-good", "i386", "fedora", "10")
    
    assert_equal(appliance_config.os_path, "fedora/10")
  end
  
  def test_build_path
    appliance_config = JBossCloud::ApplianceConfig.new("really-good", "i386", "fedora", "10")
    
    assert_equal(appliance_config.main_path, "i386/fedora/10")
  end
  
  def test_appliance_path
    appliance_config = JBossCloud::ApplianceConfig.new("really-good", "i386", "fedora", "10")
    
    assert_equal(appliance_config.appliance_path, "appliances/i386/fedora/10/really-good")
  end
end