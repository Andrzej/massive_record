module MassiveRecord
  module ORM
    module Schema
      class Field
        include ActiveModel::Validations

        TYPES = [:string, :integer, :float, :boolean, :array, :hash, :date, :time, :embed]

        attr_writer :default
        attr_accessor :name, :column, :type, :fields, :coder


        validates_presence_of :name
        validates_inclusion_of :type, :in => TYPES
        validate do
          errors.add(:fields, :blank) if fields.nil?
          errors.add(:name, :taken) if fields.try(:attribute_name_taken?, name)
        end


        #
        # Creates a new field based on arguments from DSL
        # args: name, type, options
        #
        def self.new_with_arguments_from_dsl(*args)
          field_options = args.extract_options!
          field_options[:name] = args[0]
          field_options[:type] ||= args[1]

          new(field_options)
        end



        def initialize(*args)
          options = args.extract_options!.to_options

          self.fields = options[:fields]
          self.name = options[:name]
          self.column = options[:column]
          self.type = options[:type] || :string
          self.default = options[:default]

          self.coder = options[:coder] || Base.coder

          @@encoded_nil_value = coder.dump(nil)
          @@encoded_null_string = coder.dump("null")
        end


        def ==(other)
          other.instance_of?(self.class) && other.hash == hash
        end
        alias_method :eql?, :==

        def hash
          name.hash
        end

        def type=(type)
          @type = type.to_sym
        end


        def column
          @column || name
        end

        def default
          @default.duplicable? ? @default.dup : @default
        end


        def unique_name
          raise "Can't generate a unique name as I don't have a column family!" if column_family.nil?
          [column_family.name, column].join(":")
        end

        def column_family
          fields.try :contained_in
        end

        def column=(column)
          column = column.to_s unless column.nil?
          @column = column
        end




        def decode(value)
          return value if value.nil? || value_is_already_decoded?(value)

          value = case type
                  when :boolean
                    value.blank? ? nil : !value.to_s.match(/^(true|1)$/i).nil?
                  when :date
                    value.blank? || value.to_s == "0" ? nil : (Date.parse(value) rescue nil)
                  when :time
                    value.blank? ? nil : (Time.parse(value) rescue nil)
                  when :string
                    if value.present?
                      value = value.to_s if value.is_a? Symbol
                      if value.is_a? Fixnum
                        value.to_s
                      else
                        coder.load(value)
                      end
                    end
                  when :integer, :float, :array, :hash, :embed
                    coder.load(value) if value.present?
                  else
                    raise "Unable to decode #{value}, class: #{value}"
                  end
          ensure
            unless loaded_value_is_of_valid_class?(value)
              if type != :string
                raise SerializationTypeMismatch.new("Expected #{value} (class: #{value.class}) to be any of: #{classes.join(', ')}.")
              end
            end
        end

        def encode(value)
          if type == :embed && value.is_a?(Array) && value.all?{|v| v.respond_to?(:attributes)}
            return coder.dump(value.map(&:attributes))
          end
          if type == :string && !(value.nil? || value == @@encoded_nil_value)
            value
          else
            # Truncate float if the field type is integer otherwise we will get an error on decoding
            value = value.to_i if type == :integer && value.is_a?(Float)
            coder.dump(value)
          end
        end



        private

        def name=(name)
          @name = name.to_s
        end

        def classes
          classes = case type
                    when :embed
                      [Array]
                    when :boolean
                      [TrueClass, FalseClass]
                    when :integer, :float
                      [Fixnum, Bignum, Float]
                    else
                      klass = type.to_s.classify
                      if ::Object.const_defined?(klass)
                        [klass.constantize]
                      end
                    end

          classes || []
        end

        def value_is_already_decoded?(value)
          if type == :string
            value.is_a?(String) && !(value == @@encoded_null_string || value == @@encoded_nil_value)
          else
            classes.include?(value.class)
          end
        end

        def loaded_value_is_of_valid_class?(value)
          # TODO: remove false, it currently supports atomic increment fields, they should be read with atomic_increment("field",0)
          value.nil? || value == false || value.is_a?(String) && value == @@encoded_nil_value || value_is_already_decoded?(value)
        end
      end
    end
  end
end
