require 'test/unit'
require 'jboss-cloud/helpers/exec-helper'

module JBossCloud

  class ExecHelper < Test::Unit::TestCase
    def setup
      @exec_helper = ExecHelper.new
    end

    def test_execute_command
      assert_nothing_raised do
        @exec_helper.execute( "ls" )
      end
    end
  end
end