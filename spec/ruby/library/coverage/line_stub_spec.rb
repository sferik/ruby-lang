require_relative '../../spec_helper'
require_relative 'fixtures/classes'
require 'coverage'

describe 'Coverage.line_stub' do
  it 'returns 0 for each line with code and nil for every other line of the file' do
    code = <<~'RUBY'
      def show
        @product = base_scope
                   .includes(colors_products: :color)
                   .find(params[:id])
      end
    RUBY
    CoverageSpecs.with_file(code) { |path| Coverage.line_stub(path) }.should == [0, 0, nil, nil, nil]
  end

  it 'has an entry for the last line of a file without a trailing newline' do
    code = <<~'RUBY'.chomp
      def show
        @product = base_scope
                   .includes(colors_products: :color)
                   .find(params[:id])
      end
    RUBY
    CoverageSpecs.with_file(code) { |path| Coverage.line_stub(path) }.should == [0, 0, nil, nil, nil]
  end

  it 'has an entry for each trailing blank line' do
    CoverageSpecs.with_file("x = 1\n\n\n\n") { |path| Coverage.line_stub(path) }.should == [0, nil, nil, nil]
  end

  it 'returns an empty array for an empty file' do
    CoverageSpecs.with_file("") { |path| Coverage.line_stub(path) }.should == []
  end

  it 'returns an empty array for an empty file after stubbing a file with an empty else' do
    code = <<~'RUBY'
      x.each do
        if x
          1
        else
        end
      end
    RUBY
    CoverageSpecs.with_file(code) { |path| Coverage.line_stub(path) }.should == [0, 0, 0, nil, nil, nil]
    CoverageSpecs.with_file("") { |path| Coverage.line_stub(path) }.should == []
  end
end
