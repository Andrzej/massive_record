require 'spec_helper'

class TestEmbedsManyProxy < MassiveRecord::ORM::Relations::Proxy::EmbedsMany; end

describe TestEmbedsManyProxy do
  include SetUpHbaseConnectionBeforeAll
  include SetTableNamesToTestTable

  let(:proxy_owner) { Person.new :id => "person-id-1", :name => "Test", :age => 29 }
  let(:proxy_target) { Address.new :id => "address-1",:street => "Main St." }
  let(:proxy_target_2) { Address :id => "address-2" }
  let(:proxy_target_3) { Address :id => "address-3" }
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
					#proxy_owner.reload
					proxy_owner = Person.find ("person-id-1")
					proxy_owner.addresses.should include(proxy_target)
				end

				it "should not persist proxy owner if owner is a new record" do
					subject.send(add_method, proxy_target)
					proxy_owner.should be_new_record
				end

			end
		end
	end
end
