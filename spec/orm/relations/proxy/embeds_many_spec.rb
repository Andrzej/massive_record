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

	describe "#find_proxy_target" do
    describe "with foreig keys stored in proxy_owner" do
      it "should not try to find proxy_target if foreign_keys is blank" do
        proxy_owner.test_class_ids.clear
        Address.should_not_receive(:find)
        subject.load_proxy_target.should be_empty
      end
    end

    describe "with start from" do
      let(:proxy_target) { Person.new :id => proxy_owner.id+"-friend-1", :name => "T", :age => 2 }
      let(:proxy_target_2) { Person.new :id => proxy_owner.id+"-friend-2", :name => "H", :age => 9 }
      let(:not_proxy_target) { Person.new :id => "foo"+"-friend-2", :name => "H", :age => 1 }
      let(:metadata) { subject.metadata }

      subject { proxy_owner.send(:relation_proxy, 'friends') }

      before do
        proxy_target.save!
        proxy_target_2.save!
        not_proxy_target.save!
      end

      it "should not try to find proxy_target if start from method is blank" do
        proxy_owner.should_receive(:friends_records_starts_from_id).and_return(nil)
        Person.should_not_receive(:all)
        subject.load_proxy_target.should be_empty
      end

      it "should find all friends when loading" do
        friends = subject.load_proxy_target
        friends.length.should == 2
        friends.should include(proxy_target)
        friends.should include(proxy_target_2)
        friends.should_not include(not_proxy_target)
      end
    end
  end

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

	describe "removing records from the collection" do
    [:destroy, :delete].each do |delete_method|
      describe "with ##{delete_method}" do
        before do
          subject << proxy_target
        end

        it "should not be in proxy after being removed" do
          subject.send(delete_method, proxy_target)
          subject.proxy_target.should_not include proxy_target
        end

        it "should remove the destroyed records id from proxy_owner foreign keys" do
          subject.send(delete_method, proxy_target)
          proxy_owner.test_class_ids.should_not include(proxy_target.id)
        end

        it "should not save the proxy_owner if it has not been persisted" do
          proxy_owner.should_receive(:persisted?).and_return(false)
          proxy_owner.should_not_receive(:save)
          subject.send(delete_method, proxy_target)
        end

        it "should save the proxy_owner if it has been persisted" do
          proxy_owner.save!
          proxy_owner.should_receive(:save)
          subject.send(delete_method, proxy_target)
        end
      end
		end

		describe "with #delete" do
			before do
				subject << proxy_target
			end

			it "should not ask the record to destroy self" do
				proxy_target.should_not_receive(:destroy)
				proxy_target.should_not_receive(:delete)
				subject.delete(proxy_target)
			end
		end

		describe "with destroy_all" do
			before do
				proxy_owner.save!
				subject << proxy_target << proxy_target_2
			end

			it "should not include any records after destroying all" do
				subject.destroy_all
				subject.proxy_target.should be_empty
			end

			it "should remove all foreign keys in proxy_owner" do
				subject.destroy_all
				proxy_owner.test_class_ids.should be_empty
			end

			it "should call reset after all destroyed" do
				subject.should_receive(:reset)
				subject.destroy_all
			end

			it "should be loaded after all being destroyed" do
				subject.destroy_all
				should be_loaded
			end

		end

		describe "with delete_all" do
			before do
				proxy_owner.save!
				subject << proxy_target << proxy_target_2
			end

			it "should not include any records after destroying all" do
				subject.delete_all
				subject.proxy_target.should be_empty
			end

			it "should remove all foreign keys in proxy_owner" do
				subject.delete_all
				proxy_owner.test_class_ids.should be_empty
			end

			it "should call reset after all destroyed" do
				subject.should_receive(:reset)
				subject.delete_all
			end

			it "should be loaded after all being destroyed" do
				subject.delete_all
				should be_loaded
			end

		end
	end

	describe "#limit" do
    let(:not_among_targets) { proxy_target_3 }

    describe "stored foreign keys" do
      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
        proxy_owner.save!

      end

      it "should return empty array if no targets are found" do
        subject.destroy_all
        subject.limit(1).should be_empty
      end


      it "should do db query with a limited set of ids" do
        subject.limit(1).should == [proxy_target]
      end

      it "should not hit the database if the proxy is loaded" do
        subject.load_proxy_target
        TestClass.should_not_receive(:find)
        subject.limit(1)
      end

      it "should return correct result set if proxy is loaded" do
        subject.load_proxy_target
        subject.limit(1).should == [proxy_target]
      end
		end
	end
end
