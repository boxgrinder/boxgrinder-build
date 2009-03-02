require 'test/unit'

require 'jboss-cloud/validator/appliance-validator'

class ApplianceValidatorTest < Test::Unit::TestCase
  def setup
    JBossCloud::Config.new.init( "JBoss-Cloud", "1", "1", "i386", "i386", "/tmp/dir_rpms_cache", "/tmp/dir_src_cache", "/tmp/dir_root", "/tmp/dir_top", "/tmp/dir_build", "/tmp/dir_specs", "src/appliances", "/tmp/dir_src",  "../../kickstarts/base-pkgs.ks" )
  end

  # def teardown
  # end

  def test_init_and_raise_validation_error_if_file_is_nil
    assert_raise JBossCloud::ValidationError do
      JBossCloud::ApplianceValidator.new( nil )
    end
  end

  def test_init_and_raise_validation_error_if_file_doesnt_exists
    assert_raise JBossCloud::ValidationError do
      JBossCloud::ApplianceValidator.new( "strange/path.appl" )
    end
  end

  def test_appliance_without_summary
    validator = JBossCloud::ApplianceValidator.new( "src/appliances/without-summary-appliance/without-summary-appliance.appl" )
    assert_raise JBossCloud::ValidationError do
      validator.validate
    end
  end

  def test_multiappliance_without_dependent_appliance
    validator =  JBossCloud::ApplianceValidator.new( "src/appliances/without-dependent-appliances-appliance/without-dependent-appliances-appliance.appl" )
    assert_not_nil validator , "Validator shouldn't be nil!"

    assert_raise JBossCloud::ValidationError do
      validator.validate
    end
  end

  def test_valid_data
    validator =  JBossCloud::ApplianceValidator.new( "src/appliances/valid-appliance/valid-appliance.appl" )
    assert_not_nil validator , "Validator shouldn't be nil!"
    validator.validate
  end
end


