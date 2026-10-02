require_relative '../../spec_helper'
require_relative 'fixtures/classes'
require 'coverage'

describe 'Coverage.result with methods: true' do
  before :all do
    @methods_file = fixture __FILE__, 'methods.rb'
    # Since Ruby 4.1 the span of a lambda starts at its ->, not at its parameters [Bug #21784]
    @lambda_start = ruby_version_is("4.1") ? 25 : 27
  end

  before :each do
    Coverage.running?.should == false
  end

  after :each do
    Coverage.result unless Coverage.state == :idle
    [:Covered, :Mixin, :Prepended, :Sub].each do |name|
      CoverageSpecs.send(:remove_const, name) if CoverageSpecs.const_defined?(name, false)
    end
  end

  it 'reports each method by its owner, name and source span, with the number of calls' do
    Coverage.start(methods: true)
    load @methods_file
    c = CoverageSpecs::Covered.new
    c.plain(1, d: 2)
    c.block(1)
    c.lam(1)
    2.times { c.aliased(1, d: 2) }
    CoverageSpecs::Covered.single
    CoverageSpecs::Covered.single2
    CoverageSpecs::Mixin.mixed
    CoverageSpecs::Prepended.new.prepended
    CoverageSpecs::Sub.new.send(:plain, 1, d: 2)

    Coverage.result[@methods_file][:methods].should == {
      [CoverageSpecs::Covered, :plain, 3, 4, 3, 45] => 4,
      [CoverageSpecs::Covered, :block, 4, 26, 4, 35] => 1,
      [CoverageSpecs::Covered, :lam, 5, @lambda_start, 5, 36] => 1,
      [CoverageSpecs::Covered.singleton_class, :single, 7, 4, 7, 24] => 1,
      [CoverageSpecs::Covered.singleton_class, :single2, 9, 6, 9, 22] => 1,
      [CoverageSpecs::Covered, :strict, 11, 4, 11, 22] => 0,
      [CoverageSpecs::Covered, :keyword, 12, 4, 12, 24] => 0,
      [CoverageSpecs::Covered, :default, 13, 4, 13, 39] => 0,
      [CoverageSpecs::Covered, :multi, 14, 4, 16, 7] => 0,
      [CoverageSpecs::Mixin, :mixed, 20, 4, 20, 18] => 0,
      [CoverageSpecs::Mixin.singleton_class, :mixed, 20, 4, 20, 18] => 1,
      [CoverageSpecs::Prepended, :prepended, 26, 4, 26, 22] => 1,
    }
  end

  it 'counts only the calls that get past argument processing' do
    Coverage.start(methods: true)
    load @methods_file
    c = CoverageSpecs::Covered.new
    -> { c.strict(1, 2) }.should.raise(ArgumentError)
    -> { c.keyword }.should.raise(ArgumentError)
    -> { c.default }.should.raise(RuntimeError)
    -> { c.block(1, 2) }.should.raise(ArgumentError)
    -> { c.lam }.should.raise(ArgumentError)

    methods = Coverage.peek_result[@methods_file][:methods]
    methods[[CoverageSpecs::Covered, :strict, 11, 4, 11, 22]].should == 0
    methods[[CoverageSpecs::Covered, :keyword, 12, 4, 12, 24]].should == 0
    methods[[CoverageSpecs::Covered, :default, 13, 4, 13, 39]].should == 0
    methods[[CoverageSpecs::Covered, :block, 4, 26, 4, 35]].should == 0
    methods[[CoverageSpecs::Covered, :lam, 5, @lambda_start, 5, 36]].should == 0

    c.strict(1)
    c.keyword(a: 1)
    c.default(1)
    c.block(1)
    c.lam(1)

    methods = Coverage.result[@methods_file][:methods]
    methods[[CoverageSpecs::Covered, :strict, 11, 4, 11, 22]].should == 1
    methods[[CoverageSpecs::Covered, :keyword, 12, 4, 12, 24]].should == 1
    methods[[CoverageSpecs::Covered, :default, 13, 4, 13, 39]].should == 1
    methods[[CoverageSpecs::Covered, :block, 4, 26, 4, 35]].should == 1
    methods[[CoverageSpecs::Covered, :lam, 5, @lambda_start, 5, 36]].should == 1
  end

  it 'does not count a define_method call that fails its arity check, nor the block called directly' do
    file = fixture __FILE__, 'methods_define_method_failure.rb'
    Coverage.start(methods: true)
    load file
    -> { CoverageSpecs::Covered.new.blk }.should.raise(ArgumentError)
    CoverageSpecs::Covered::BLK.call(1)

    Coverage.result[file][:methods].should == {
      [CoverageSpecs::Covered, :blk, 3, 15, 3, 24] => 0
    }
  end

  it 'counts the calls of methods defined by an eval that is not itself covered' do
    file = fixture __FILE__, 'methods_eval.rb'
    Coverage.start(methods: true)
    load file
    3.times { CoverageSpecs::Covered.new.from_eval(1) }

    Coverage.result[file][:methods].should == {
      [CoverageSpecs::Covered, :from_eval, 4, 6, 4, 30] => 3
    }
  end

  it 'reports the span of a block that follows a command argument or a constant-like method call' do
    file = fixture __FILE__, 'methods_command_blocks.rb'
    Coverage.start(methods: true)
    load file
    c = CoverageSpecs::Covered.new
    c.brace(1)
    c.do_block(1)
    c.constant_call(1)

    methods = Coverage.result[file][:methods]
    methods[[CoverageSpecs::Covered, :brace, 4, 27, 4, 36]].should == 1
    methods[[CoverageSpecs::Covered, :do_block, 7, 6, 9, 7]].should == 1
    methods[[CoverageSpecs::Covered, :constant_call, 11, 23, 11, 32]].should == 1
  end

  it 'reports a method defined from a Method object under its new owner but its original name' do
    file = fixture __FILE__, 'methods_renamed.rb'
    Coverage.start(methods: true)
    load file
    CoverageSpecs::Sub.new.renamed

    Coverage.result[file][:methods].should == {
      [CoverageSpecs::Covered, :original, 3, 4, 3, 21] => 0,
      [CoverageSpecs::Sub, :original, 3, 4, 3, 21] => 1,
    }
  end

  it 'does not count calls while measurement is set up but not running, or suspended' do
    Coverage.setup(methods: true)
    load @methods_file
    key = [CoverageSpecs::Covered, :strict, 11, 4, 11, 22]
    c = CoverageSpecs::Covered.new
    c.strict(1)
    Coverage.resume
    c.strict(1)
    Coverage.suspend
    c.strict(1)
    Coverage.peek_result[@methods_file][:methods][key].should == 1

    Coverage.resume
    c.strict(1)
    Coverage.result(stop: false, clear: true)[@methods_file][:methods][key].should == 2
    Coverage.peek_result[@methods_file][:methods][key].should == 0

    c.strict(1)
    Coverage.result[@methods_file][:methods][key].should == 1
  end

  it 'sums the calls of the methods defined at the same place when a file is loaded again' do
    file = fixture __FILE__, 'methods_shape.rb'
    Coverage.start(methods: true)
    load file
    CoverageSpecs.shape
    load file
    2.times { CoverageSpecs.shape }

    Coverage.result[file][:methods].should == {
      [CoverageSpecs.singleton_class, :shape, 2, 2, 2, 21] => 3
    }
  end

  it 'reports :methods alone or alongside the other enabled modes' do
    file = fixture __FILE__, 'methods_shape.rb'
    Coverage.start(methods: true)
    load file
    Coverage.result[file].should == {
      methods: { [CoverageSpecs.singleton_class, :shape, 2, 2, 2, 21] => 0 }
    }

    Coverage.start(lines: true, methods: true)
    load file
    Coverage.result[file].should == {
      lines: [1, 1, nil],
      methods: { [CoverageSpecs.singleton_class, :shape, 2, 2, 2, 21] => 0 }
    }

    Coverage.start(oneshot_lines: true, methods: true)
    load file
    Coverage.result[file].should == {
      oneshot_lines: [1, 2],
      methods: { [CoverageSpecs.singleton_class, :shape, 2, 2, 2, 21] => 0 }
    }
  end
end
