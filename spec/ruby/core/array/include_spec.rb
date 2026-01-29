require_relative '../../spec_helper'
require_relative 'fixtures/classes'

describe "Array#include?" do
  it "returns true if object is present, false otherwise" do
    [1, 2, "a", "b"].include?("c").should == false
    [1, 2, "a", "b"].include?("a").should == true
  end

  it "determines presence by using element eql? obj" do
    o = mock('')

    [1, 2, "a", "b"].include?(o).should == false

    def o.eql?(other); other == 'a'; end

    [1, 2, o, "b"].include?('a').should == true

    # eql? distinguishes between 2 and 2.0
    [1, 2.0, 3].include?(2).should == false
    [1, 2.0, 3].include?(2.0).should == true
  end

  it "calls eql? on elements from left to right until success" do
    key = "x"
    one = mock('one')
    two = mock('two')
    three = mock('three')
    one.should_receive(:eql?).any_number_of_times.and_return(false)
    two.should_receive(:eql?).any_number_of_times.and_return(true)
    three.should_not_receive(:eql?)
    ary = [one, two, three]
    ary.include?(key).should == true
  end
end
