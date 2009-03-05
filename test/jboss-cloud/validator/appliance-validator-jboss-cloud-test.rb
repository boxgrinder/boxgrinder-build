require 'test/unit'

require 'jboss-cloud/validator/appliance-validator'

class ApplianceValidatorWithJBossCloudTest < Test::Unit::TestCase
  def setup
    @appliances_dir = "../../../appliances"
  end

  def test_appliances_for_validity
    Dir[ "#{@appliances_dir}/*/*.appl" ].each do |appliance_def|
      assert_not_nil JBossCloud::ApplianceValidator.new( @appliances_dir, appliance_def ), "Validator shouldn't be nil!"
    end if File.exists?( @appliances_dir ) # for stand-alone jboss-cloud-support testing
  end
end

