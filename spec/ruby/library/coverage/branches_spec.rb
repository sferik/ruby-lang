require_relative '../../spec_helper'
require_relative 'fixtures/classes'
require 'coverage'

describe 'Coverage.result with branches: true' do
  before :all do
    @branches_file = fixture __FILE__, 'branches.rb'
  end

  before :each do
    Coverage.running?.should == false
  end

  after :each do
    Coverage.result unless Coverage.state == :idle
    [:Branchy, :Reloaded].each do |name|
      CoverageSpecs.send(:remove_const, name) if CoverageSpecs.const_defined?(name, false)
    end
  end

  ruby_version_is "3.4" do
    it 'reports each branch with its arms and the number of times each arm was taken' do
      Coverage.start(branches: true)
      load @branches_file
      b = CoverageSpecs::Branchy.new
      b.classify(1); b.classify(-1); b.classify(0)
      b.describe(0); b.describe(1); b.describe(200)
      b.count_down(3)
      b.safe(nil); b.safe(-2)
      b.match(20); b.match(3)

      Coverage.result[@branches_file][:branches].should == {
        [:if, 0, 4, 6, 10, 9] => {
          [:then, 1, 5, 8, 5, 17] => 1,
          [:else, 2, 6, 6, 10, 9] => 2,
        },
        [:if, 3, 6, 6, 10, 9] => {
          [:then, 4, 7, 8, 7, 17] => 1,
          [:else, 5, 9, 8, 9, 13] => 1,
        },
        [:if, 6, 14, 13, 14, 39] => {
          [:then, 7, 14, 23, 14, 28] => 1,
          [:else, 8, 14, 31, 14, 39] => 2,
        },
        [:unless, 9, 15, 6, 15, 32] => {
          [:else, 10, 15, 6, 15, 32] => 2,
          [:then, 11, 15, 6, 15, 17] => 1,
        },
        [:case, 12, 16, 6, 22, 9] => {
          [:when, 13, 17, 18, 17, 23] => 1,
          [:when, 14, 19, 8, 19, 12] => 1,
          [:else, 15, 21, 8, 21, 13] => 1,
        },
        [:while, 16, 26, 6, 28, 9] => {
          [:body, 17, 27, 8, 27, 14] => 3,
        },
        [:until, 18, 29, 6, 29, 24] => {
          [:body, 19, 29, 6, 29, 12] => 3,
        },
        [:"&.", 20, 34, 6, 34, 12] => {
          [:then, 21, 34, 6, 34, 12] => 1,
          [:else, 22, 34, 6, 34, 12] => 1,
        },
        [:case, 23, 38, 6, 42, 9] => {
          [:in, 24, 39, 37, 39, 43] => 1,
          [:in, 25, 41, 8, 41, 14] => 1,
          [:else, 26, 38, 6, 42, 9] => 0,
        },
      }
    end

    it 'does not report conditionals whose outcome is known when the code is compiled' do
      file = fixture __FILE__, 'branches_folding.rb'
      Coverage.start(branches: true)
      suppress_warning { load file } # literals in conditions
      CoverageSpecs.folds(1)

      Coverage.result[file][:branches].should == {
        [:if, 0, 7, 4, 7, 15] => { [:then, 1, 7, 4, 7, 6] => 0, [:else, 2, 7, 4, 7, 15] => 1 },
        [:if, 3, 8, 4, 8, 15] => { [:then, 4, 8, 4, 8, 6] => 1, [:else, 5, 8, 4, 8, 15] => 0 },
        [:if, 6, 9, 4, 9, 21] => { [:then, 7, 9, 4, 9, 6] => 1, [:else, 8, 9, 4, 9, 21] => 0 },
        [:if, 9, 10, 4, 10, 18] => { [:then, 10, 10, 4, 10, 6] => 0, [:else, 11, 10, 4, 10, 18] => 1 },
        [:if, 12, 11, 4, 11, 18] => { [:then, 13, 11, 4, 11, 6] => 1, [:else, 14, 11, 4, 11, 18] => 0 },
      }
    end
  end

  it 'reports :branches alone or alongside the other enabled modes' do
    file = fixture __FILE__, 'branches_ternary.rb'
    Coverage.start(branches: true)
    load file
    Coverage.result[file].should == {
      branches: {
        [:if, 0, 2, 4, 2, 23] => { [:then, 1, 2, 12, 2, 16] => 1, [:else, 2, 2, 19, 2, 23] => 0 }
      }
    }

    Coverage.start(:all)
    load file
    result = Coverage.result[file]
    result.keys.should == [:lines, :branches, :methods]
    result[:branches].size.should == 1
  end

  it 'does not count branches while measurement is set up but not running, or suspended' do
    key = [:if, 0, 4, 6, 10, 9]
    Coverage.setup(branches: true)
    load @branches_file
    b = CoverageSpecs::Branchy.new
    b.classify(1)
    Coverage.resume
    b.classify(1)
    Coverage.suspend
    b.classify(1)
    Coverage.peek_result[@branches_file][:branches].fetch(key).values.should == [1, 0]

    Coverage.resume
    b.classify(-1)
    Coverage.result(stop: false, clear: true)[@branches_file][:branches].fetch(key).values.should == [1, 1]
    Coverage.peek_result[@branches_file][:branches].fetch(key).values.should == [0, 0]

    b.classify(0)
    Coverage.result[@branches_file][:branches].fetch(key).values.should == [0, 1]
  end

  it 'counts the branches of a block turned into a method' do
    file = fixture __FILE__, 'branches_define_method.rb'
    Coverage.start(branches: true)
    load file
    CoverageSpecs::Reloaded.new.sign(1)
    CoverageSpecs::Reloaded.new.sign(-1)

    Coverage.result[file][:branches].should == {
      [:if, 0, 3, 31, 3, 50] => { [:then, 1, 3, 39, 3, 43] => 1, [:else, 2, 3, 46, 3, 50] => 1 }
    }
  end

  it 'restarts the counts of a file that is loaded again' do
    file = fixture __FILE__, 'branches_define_method.rb'
    Coverage.start(branches: true)
    load file
    CoverageSpecs::Reloaded.new.sign(1)
    load file
    CoverageSpecs::Reloaded.new.sign(-1)

    Coverage.result[file][:branches].should == {
      [:if, 0, 3, 31, 3, 50] => { [:then, 1, 3, 39, 3, 43] => 1, [:else, 2, 3, 46, 3, 50] => 0 }
    }
  end
end
