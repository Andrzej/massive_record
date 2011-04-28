module MassiveRecord
  module ORM
    module Relations
      class Proxy
        class EmbedsMany < Proxy

          def find(id)
						load_proxy_target unless loaded?
            record = proxy_target.find { |record| record.id == id }
            raise RecordNotFound.new("Could not find #{proxy_target_class.model_name} with id=#{id}") if record.nil?
            record
          end

          def limit(limit)
						load_proxy_target unless loaded?
            proxy_target.slice(0, limit)
          end

          def reset
            super
            @proxy_target = []
          end


          #
          # Adding record(s) to the collection.
          #
          def <<(*records)
            save_records = proxy_owner.persisted?
            if records.flatten.all? &:valid?
              records.flatten.each do |record|
                unless include? record
                  raise_if_type_mismatch(record)
                  proxy_target << record
                  proxy_owner.attributes[metadata.name] = proxy_target.map(&:attributes)
                end
              end

              proxy_owner.save if save_records

              self
            end
          end
          alias_method :push, :<<
          alias_method :concat, :<<

          #
          # Destroy record(s) from the collection
          # Each record will be asked to destroy itself as well
          #
          def destroy(*records)
            delete_or_destroy *records, :destroy
          end


          #
          # Deletes record(s) from the collection
          #
          def delete(*records)
            delete_or_destroy *records, :delete
          end

          #
          # Destroys all records
          #
          def destroy_all
            destroy(load_proxy_target)
            reset
            loaded!
          end

          #
          # Deletes all records from the relationship.
          # Does not destroy the records
          #
          def delete_all
            delete(load_proxy_target)
            reset
            loaded!
          end

          #
          # Checks if record is included in collection
          #
          def include?(record)
            load_proxy_target.include? record
          end

          def length
            load_proxy_target.length
          end
          alias_method :count, :length
          alias_method :size, :length

          def empty?
            length == 0
          end

          def first
            limit(1).first
          end

        private

          def find_proxy_target
            (proxy_owner.attributes["addresses"] || []).map{|h| metadata.proxy_target_class.new(h)}
          end


          def delete_or_destroy(*records, method)
            records.flatten.each do |record|
              if include? record
                proxy_target.delete(record)
                #record.destroy if method.to_sym == :destroy
              end
						end
						proxy_owner.attributes[metadata.name] = proxy_target.map(&:attributes)
            proxy_owner.save if proxy_owner.persisted?
          end

          def can_find_proxy_target?
            true
          end
        end
      end
    end
  end
end
