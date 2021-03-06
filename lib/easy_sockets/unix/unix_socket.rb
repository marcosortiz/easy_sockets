require 'easy_sockets/basic_socket'

module EasySockets
    #
    # @author Marcos Ortiz
    # Subclass of {EasySockets::BasicSocket} that implement a Unix socket.
    #
    class UnixSocket < EasySockets::BasicSocket
        
        DEFAULT_SOCKET_PATH = '/tmp/unix_socket'

        #
        # @param [Hash] opts the options to create a socket with.
        # @option opts [Integer] :socket_path ('/tmp/unix_socket') The unix socket file path.
        #
        # It also accepts all options that {EasySockets::BasicSocket#initialize} accepts
        def initialize(opts={})
            super(opts)
            @socket_path = opts[:socket_path] || DEFAULT_SOCKET_PATH
        end
        
        private
        
        def on_connect
            @socket = Socket.new(:UNIX, :STREAM)
            begin
                # Initiate a nonblocking connection
                remote_addr = Socket.pack_sockaddr_un(@socket_path)
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
            
            log(:debug, "Successfully connected to #{@socket_path}.")
        rescue Exception => e
            @socket.close if @socket && !@socket.closed?
            raise e
        end
    end

end