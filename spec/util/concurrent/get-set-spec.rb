require "rspec"

require 'boxgrinder-build/util/concurrent/get_set'

describe GetSet do
  subject{ GetSet.new }
  its(:get_set){ should be_false }

  context "#initialize" do
    it "should have a value of true with default init" do
      GetSet.new.get_set.should be_false
    end

    it "should have an arbitrary value after setting initial_state" do
      GetSet.new(:boxgrinder).get_set.should equal(:boxgrinder)
    end
  end

  context "#get_set" do
    context "without block" do
      it "should return the existing value when none is set" do
        subject.get_set(:some_value)
        subject.get_set.should equal(:some_value)
      end

      it "should return the set non-nil value when explicitly provided" do
        subject.get_set(:boxgrinder).should equal(:boxgrinder)
      end
    end

    context "with block" do
      it "yield existing the value and set block return as the new value" do
        expect{ subject.get_set(:blah){|v| :boo} }.
          to change(subject, :get_set).from(false).to(:boo)
      end

      it "parameter should be ignored" do
        expect{ subject.get_set(:blah){|v| v} }.
          not_to change(subject, :get_set)
      end
    end
  end
end
