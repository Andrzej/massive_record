require 'spec_helper'

class TestEmbedsManyProxy < MassiveRecord::ORM::Relations::Proxy::EmbedsMany; end

describe TestEmbedsManyProxy do
  include SetUpHbaseConnectionBeforeAll
  include SetTableNamesToTestTable

  let(:proxy_owner) { Person.new :id => "person-id-1", :name => "Test", :age => 29 }
  let(:proxy_target) { Address.new :id => "address-1",:street => "Main St." }
  let(:proxy_target_2) { Address.new :id => "address-2",:street => "Left St." }
  let(:proxy_target_3) { Address.new :id => "address-3",:street => "Middle St." }
  let(:metadata) { subject.metadata }

  subject { proxy_owner.send(:relation_proxy, 'addresses') }

  it_should_behave_like "relation proxy"

	describe "adding records to collection" do
		[:<<, :push, :concat].each do |add_method|
      describe "by #{add_method}" do
        it "should include the proxy_target in the proxy" do
          subject.send(add_method,proxy_target)
					subject.proxy_target.should include proxy_target
        end

        it "should not add invalid objects to collection" do
          proxy_target.should_receive(:valid?).and_return false
          subject.send(add_method, proxy_target).should be_false
          subject.proxy_target.should_not include proxy_target
				end

				it "should auto-persist proxy_target if owner has been persisted" do
					proxy_owner.addresses << proxy_target
					proxy_owner.save!
					subject.send(add_method, proxy_target)
					proxy_owner = Person.find ("person-id-1")
					proxy_owner.addresses.should include(proxy_target)
				end

				it "should not persist proxy owner if owner is a new record" do
					subject.send(add_method, proxy_target)
					proxy_owner.should be_new_record
				end

				it "should not do anything adding the same record twice" do
					2.times { subject.send(add_method, proxy_target) }
					subject.proxy_target.length.should == 1
					proxy_owner.addresses.length.should == 1
				end

				it "should be able to add two records at the same time" do
					subject.send add_method, [proxy_target, proxy_target_2]
					subject.proxy_target.should include proxy_target
					subject.proxy_target.should include proxy_target_2
				end

				it "should return proxy so calls can be chained" do
          subject.send(add_method, proxy_target).object_id.should == subject.object_id
        end

        it "should raise an error if there is a type mismatch" do
          lambda { subject.send add_method, Person.new(:name => "Foo", :age => 2) }.should raise_error MassiveRecord::ORM::RelationTypeMismatch
        end

        it "should not save the pushed proxy_target if proxy_owner is not persisted" do
          proxy_owner.should_receive(:persisted?).and_return false
          proxy_target.should_not_receive(:save)
          subject.send(add_method, proxy_target)
        end

        it "should not save the proxy_owner object if it has not been persisted before" do
          proxy_owner.should_receive(:persisted?).and_return false
          proxy_owner.should_not_receive(:save)
          subject.send(add_method, proxy_target)
        end

        it "should not save anything if one record is invalid" do
          proxy_owner.save!

          proxy_target.should_receive(:valid?).and_return(true)
          proxy_target_2.should_receive(:valid?).and_return(false)

          proxy_target.should_not_receive(:save)
          proxy_target_2.should_not_receive(:save)
          proxy_owner.should_not_receive(:save)

          subject.send(add_method, [proxy_target, proxy_target_2]).should be_false
        end
			end
		end
	end
end
