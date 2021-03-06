require 'spec_helper'
require 'orm/models/person'

describe "attribute methods" do
  before do
    @model = Person.new :id => 5, :name => "John", :age => "15"
  end

  it "should define reader method" do
    @model.name.should == "John"
  end

  it "should define writer method" do
    @model.name = "Bar"
    @model.name.should == "Bar"
  end

  it "should be possible to write attributes" do
    @model.write_attribute :name, "baaaaar"
    @model.name.should == "baaaaar"
  end

  it "should be possible to read attributes" do
    @model.read_attribute(:name).should == "John"
  end

  it "should return casted value when read" do
    @model.read_attribute(:age).should == 15
  end
  
  it "should contains the id in the attributes getter" do
    @model.attributes.should include("id")
  end

  describe "#attributes=" do
    it "should simply return if incomming value is not a hash" do
      @model.attributes = "FOO BAR"
      @model.attributes.keys.should include("name")
    end

    it "should mass assign attributes" do
      @model.attributes = {:name => "Foo", :age => 20}
      @model.name.should == "Foo"
      @model.age.should == 20
    end

    it "should raise an error if we encounter an unkown attribute" do
      lambda { @model.attributes = {:unkown => "foo"} }.should raise_error MassiveRecord::ORM::UnknownAttributeError
    end
  end
end
