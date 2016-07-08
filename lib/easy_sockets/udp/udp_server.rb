require 'logger'
require 'socket'
require 'easy_sockets/constants'
require 'easy_sockets/utils/server_utils'

module EasySockets
    #
    # This class was created for testing purposes only. It should not be used
    # in production.
    #
    class UdpServer
        include EasySockets::ServerUtils

        attr_reader :connections
        
        DEFAULT_TIMEOUT = 0.5 # seconds
        
        def initialize(opts={})
            set_opts(opts)
            @started = false
            @stop_requested = false
            @connections = []
            register_shutdown_signals
        end
        
        def start
            return if @started
            @started = true
            @socket = UDPSocket.new
            @socket.bind('127.0.0.1', @port)
            @logger.info "Listening on udp://127.0.0.1:#{@port}"
            loop do
                shutdown if @stop_requested
                # connection = accept_non_block(@socket)
                # @connections << connection
                # handle(connection)
                handle(@socket)
            end
        end
        
        def stop
            return unless @started
            @stop_requested = true
        end

        private
        
        def set_opts(opts)
            @port = opts[:port].to_i
            @port = DEFAULT_PORT if @port <= 0
            
            @logger = opts[:logger] || Logger.new(STDOUT)
            
            @separator = opts[:separator]
            @separator ||= EasySockets::CRLF
            
            @sleep_time = opts[:sleep_time].to_f
            @sleep_time = 0.0001 if @sleep_time <= 0.0
            
            @timeout = opts[:timeout].to_f
            @timeout = DEFAULT_TIMEOUT if @timeout <= 0.0
        end
        
        def handle(connection)
            loop do
                shutdown if @stop_requested
                begin
                    msg, addr = udp_read_non_block(connection)
                    sleep @sleep_time
                    unless msg.nil?
                        connection.send(msg, 0, addr[3], addr[1])
                        @logger.info "Sent: #{msg.inspect}"
                    end
                rescue EOFError, Errno::ECONNRESET
                    connection.close
                    @logger.info 'Client disconnected.'
                    break
                end
            end
        end
        
    end
end