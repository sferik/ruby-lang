describe :enumerable_include, shared: true do
  it "returns true if any element eql? argument for numbers" do
    elements = (0..5).to_a
    EnumerableSpecs::Numerous.new(*elements).send(@method,5).should == true
    EnumerableSpecs::Numerous.new(*elements).send(@method,10).should == false
  end

  it "returns true if any element eql? argument for other objects" do
    # Create an object with custom eql? and include it in the collection
    # Then search for a value that the object's eql? will match
    class EnumerableSpecIncludeP11; def eql?(obj); obj == '11'; end; end

    obj = EnumerableSpecIncludeP11.new
    elements = ('0'..'5').to_a + [obj]
    EnumerableSpecs::Numerous.new(*elements).send(@method,'5').should == true
    EnumerableSpecs::Numerous.new(*elements).send(@method,'10').should == false
    # The custom object in the collection has eql? that matches '11'
    EnumerableSpecs::Numerous.new(*elements).send(@method,'11').should == true
  end


  it "returns true if any member of enum eql? obj (eql? distinguishes numeric types)" do
    # equality is tested with eql?, which distinguishes 2 from 2.0
    EnumerableSpecs::Numerous.new(2,4,6,8,10).send(@method, 2.0).should == false
    EnumerableSpecs::Numerous.new(2,4,6,8,10).send(@method, 2).should == true
    EnumerableSpecs::Numerous.new(2,4,[6,8],10).send(@method, [6, 8]).should == true
    EnumerableSpecs::Numerous.new(2,4,[6,8],10).send(@method, [6.0, 8.0]).should == false
  end

  it "gathers whole arrays as elements when each yields multiple" do
    multi = EnumerableSpecs::YieldsMulti.new
    multi.send(@method, [1,2]).should be_true
  end

end
