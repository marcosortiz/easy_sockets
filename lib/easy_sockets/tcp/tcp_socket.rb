require 'easy_sockets/basic_socket'

module EasySockets
    class TcpSocket < EasySockets::BasicSocket
        
        def initialize(opts={})
            opts[:log_path] ||= 'logs/tcp/basic_socket'
            super(opts)
            
            @port = opts[:port].to_i || '127.0.0.1'
            @port = DEFAULT_PORT if @port <= 0
            @host = opts[:host] || DEFAULT_HOST
        end
                    
        def on_connect
            @socket = Socket.new(:INET, :STREAM)
            begin
                # Initiate a nonblocking connection
                remote_addr = Socket.pack_sockaddr_in(@port, @host)
                @socket.connect_nonblock(remote_addr)

                rescue Errno::EINPROGRESS
                    # Indicates that the connect is in progress. We monitor the
                    # socket for it to become writable, signaling that the connect
                    # is completed.
                    #
                    # Once it retries the above block of code it
                    # should fall through to the EISCONN rescue block and end up
                    # outside this entire begin block where the socket can be used.
                    if IO.select(nil, [@socket], nil, @timeout)
                        retry
                    else
                        @socket.close if @socket && !@socket.closed?
                        raise Timeout::Error.new("Timeout is set to #{@timeout} seconds.")
                    end
                rescue Errno::EISCONN
                # Indicates that the connect is completed successfully.
            end
            log(:debug, "Successfully connected to tcp://#{@host}:#{@port}.")
        rescue Exception => e
            @socket.close if @socket && !@socket.closed?
            raise e
        end
    end
end