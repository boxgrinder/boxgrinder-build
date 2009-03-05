require 'test/unit'

require 'jboss-cloud/validator/appliance-validator'

class ApplianceValidatorTest < Test::Unit::TestCase
  # def setup
  # end
  
  # def teardown
  # end
  
  def test_nil_appliances_dir
    assert_raise JBossCloud::ValidationError do
      JBossCloud::ApplianceValidator.new( nil, nil )
    end
  end
  
  def test_doesnt_exists_appliances_dir
    assert_raise JBossCloud::ValidationError do
      JBossCloud::ApplianceValidator.new( "bled/sd/sd", nil )
    end
  end
  
  def test_init_and_raise_validation_error_if_file_is_nil
    assert_raise JBossCloud::ValidationError do
      JBossCloud::ApplianceValidator.new( "src/appliances", nil )
    end
  end
  
  def test_init_and_raise_validation_error_if_file_doesnt_exists
    assert_raise JBossCloud::ValidationError do
      JBossCloud::ApplianceValidator.new( "src/appliances", "strange/path.appl" )
    end
  end
  
  def test_appliance_without_summary
    validator = JBossCloud::ApplianceValidator.new( "src/appliances", "src/appliances/without-summary-appliance/without-summary-appliance.appl" )
    assert_raise JBossCloud::ValidationError do
      validator.validate
    end
  end
  
  def test_multiappliance_without_dependent_appliance
    validator = JBossCloud::ApplianceValidator.new( "src/appliances", "src/appliances/without-dependent-appliances-appliance/without-dependent-appliances-appliance.appl" )
    assert_not_nil validator , "Validator shouldn't be nil!"
    
    assert_raise JBossCloud::ValidationError do
      validator.validate
    end
  end
  
  def test_valid_data
    validator = JBossCloud::ApplianceValidator.new( "src/appliances", "src/appliances/valid-appliance/valid-appliance.appl" )
    assert_not_nil validator , "Validator shouldn't be nil!"
    validator.validate
  end
end
