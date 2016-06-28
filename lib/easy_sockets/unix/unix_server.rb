require 'logger'
require 'easy_sockets/constants'
require 'easy_sockets/utils/server_utils'

module EasySockets
    #
    # This class was created for testing purposes only. It should not be used
    # in production.
    #
    class UnixServer
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
            @server = UNIXServer.new(@socket_path)
            @logger.info "Listening on #{@socket_path}"
            loop do
                shutdown if @stop_requested
                # connection = @server.accept
                connection = accept_non_block(@server)
                @connections << connection
                handle(connection)
            end
        end
        
        def stop
            return unless @started
            @stop_requested = true
        end

        private
        
        def set_opts(opts)
            @socket_path = opts[:socket_path]
            @socket_path ||= '/tmp/unix_server'
            
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
                    msg = read_non_block(connection)
                    next if msg.nil? || msg.empty?
                    sleep @sleep_time
                    write_non_block(connection, msg)
                    if msg.chomp == 'simulate_crash'
                        connection.close
                        break
                    end
                rescue EOFError, Errno::ECONNRESET, Errno::EPIPE
                    connection.close
                    @logger.info 'Client disconnected.'
                    break
                end
            end
        end
        
    end
end