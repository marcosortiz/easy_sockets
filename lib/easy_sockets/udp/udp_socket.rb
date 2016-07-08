require 'easy_sockets/basic_socket'

module EasySockets
    #
    # @author Marcos Ortiz
    # Subclass of {EasySockets::BasicSocket} that implement a UDP socket.
    #
    class UdpSocket < EasySockets::BasicSocket
        
        #
        # @param [Hash] opts the options to create a socket with.
        # @option opts [Integer] :port (2000) The udp port the server is running on.
        # @option opts [String] :host ('127.0.0.1') The hostname or IP address the server is running on.
        #
        # It also accepts all options that {EasySockets::BasicSocket#initialize} accepts
        def initialize(opts={})
            super(opts)
            
            @port = opts[:port].to_i || '127.0.0.1'
            @port = DEFAULT_PORT if @port <= 0
            @host = opts[:host] || DEFAULT_HOST
        end
        
        private
        
        def on_connect
            @socket = UDPSocket.new
            @socket.connect(@host, @port)
            log(:debug, "Successfully connected to udp://#{@host}:#{@port}.")
        rescue Exception => e
            @socket.close if @socket && !@socket.closed?
            raise e
        end
    end
end