require_relative '../../spec_helper'
require_relative 'fixtures/classes'
require 'coverage'

describe 'Coverage.result with lines: true' do
  before :each do
    Coverage.running?.should == false
  end

  after :each do
    Object.send(:remove_method, :coverage_spec_method) if Object.private_method_defined?(:coverage_spec_method)
    CoverageSpecs.send(:remove_const, :Undef) if CoverageSpecs.const_defined?(:Undef, false)
  end

  it 'counts a lone statement in an interpolation without dropping an earlier statement on its line' do
    CoverageSpecs.line_coverage(<<~'RUBY').should == [1, 1, 1]
      def coverage_spec_method(*) = nil
      coverage_spec_method([1].map {
        y = 1; nil }, "#{3}")
    RUBY
  end

  it 'counts each of several statements in an interpolation on its own line' do
    CoverageSpecs.line_coverage(<<~'RUBY').should == [1, 1, 1, nil]
      x = "#{
        a = 1
        a
      }"
    RUBY
  end

  it 'counts a statement whose call continues on a later line once, on its first line' do
    CoverageSpecs.line_coverage(<<~'RUBY').should == [1, 1, nil, 1, nil]
      o = Struct.new(:b).new
      o.b =
        [].size
      o.b.to_s.concat(
        [].size.to_s)
    RUBY
  end

  it 'counts a statement on the line of its first instruction' do
    CoverageSpecs.line_coverage(<<~'RUBY').should == [nil, 1, nil, 1, nil, nil, nil, 1, 1]
      x =
        [].size
      y = <<~EOS
        #{[].size}
        #{[].size}
      EOS
      z = {
        a: [].size }
      x = y
    RUBY
  end

  it 'counts a literal array or hash spanning several lines on its first line' do
    CoverageSpecs.line_coverage(<<~'RUBY').should == [1, nil, nil, 1, nil, nil]
      x = [
        1,
        2]
      y = {
        a: :b,
        c: 1.0}
    RUBY
  end

  it 'counts a statement in a begin block once' do
    CoverageSpecs.line_coverage(<<~'RUBY').should == [1, 1, nil, 1, nil, 1, nil, nil, 1]
      def coverage_spec_method
        x = 1
        begin
          [].size
        ensure
          x = 2
        end
      end
      coverage_spec_method
    RUBY
  end

  ruby_version_is "3.4" do
    it 'counts a conditional in an interpolation' do
      CoverageSpecs.line_coverage(<<~'RUBY').should == [1, nil, 1, nil, 1]
        x = <<~EOS
          abc
          #{[].empty? ? "a" : "b"}
        EOS
        x = x
      RUBY
    end
  end

  it 'counts an interpolation in a heredoc that ends the file' do
    CoverageSpecs.line_coverage(<<~'RUBY').should == [nil, 1, nil]
      x = <<~EOS
        #{1.to_s}
      EOS
    RUBY
  end

  it 'counts undef on the line of its keyword' do
    CoverageSpecs.line_coverage(<<~'RUBY').should == [2, 1, 1, nil, nil, nil]
      class CoverageSpecs::Undef; def a; end; def b; end; end
      class CoverageSpecs::Undef
        x = 1; undef
          a,
          b
      end
    RUBY
  end

  ruby_version_is "3.4" do
    it 'counts the arms of a ternary operator as lines of their own' do
      CoverageSpecs.line_coverage(<<~'RUBY').should == [1, 1, 1, 1, 0, 1, 1, nil]
        y = [1]
        x = y.size ?
          1 : 2
        if y.empty? ?
             y.first :
             y.last
          z = 1
        end
      RUBY
    end
  end

  it 'restarts the counts of a file that is loaded again' do
    CoverageSpecs.with_file("x = 0\n2.times { x += 1 }\n") do |path|
      Coverage.start(lines: true)
      load path
      load path
      Coverage.result.fetch(path)[:lines]
    end.should == [1, 3]
  end
end
