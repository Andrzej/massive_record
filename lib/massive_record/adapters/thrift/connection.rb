module MassiveRecord
  module Adapters
    module Thrift
      class Connection
  
        attr_accessor :host, :port, :timeout
    
        def initialize(opts = {})
          @timeout = 4000
          @host    = opts[:host]
          @port    = opts[:port] || 9090
        end
      
        def transport
          @transport ||= ::Thrift::BufferedTransport.new(::Thrift::Socket.new(@host, @port, @timeout))
        end
      
        def open
          protocol = ::Thrift::BinaryProtocol.new(transport)
          @client = Apache::Hadoop::Hbase::Thrift::Hbase::Client.new(protocol)
        
          begin
            transport.open()
            true
          rescue
            raise MassiveRecord::Wrapper::Errors::ConnectionException.new, "Unable to connect to HBase on #{@host}, port #{@port}"
          end
        end
      
        def close
          @transport.close.nil?
        end
          
        def client
          @client
        end
      
        def open?
          @transport.try("open?")
        end
      
        def tables
          collection = MassiveRecord::Wrapper::TablesCollection.new
          collection.connection = self
          getTableNames().each{|table_name| collection.push(table_name)}
          collection
        end
    
        # Wrapp HBase API to be able to catch errors and try reconnect
        def method_missing(method, *args)
          begin
            open if not @client
            client.send(method, *args) if @client
          rescue IOError
            @client = nil
            open
            client.send(method, *args) if @client
          rescue ::Thrift::TransportException
            @transport = nil
            @client = nil
            open
            client.send(method, *args) if @client
          end
        end
    
      end
    end
  end
end