require 'logger'
require 'socket'
require 'timeout'
require 'easy_sockets/constants'
require 'easy_sockets/utils'

module EasySockets
    #
    # @author Marcos Ortiz
    # @abstract Please check the following subclasses: {EasySockets::TcpSocket} and {EasySockets::UnixSocket}.
    #
    class BasicSocket
        include EasySockets::Utils
        
        DEFAULT_TIMEOUT = 0.5
        
        attr_reader :logger, :connected
        alias_method :connected?, :connected
        
        #
        # @param [Hash] opts the options to create a socket with.
        # @option opts [Logger] :logger (nil) An instance of Logger.
        # @option opts [Float] :timeout (0.5) Timeout in seconds for socket connect, read and write operations.
        # @option opts [String] :separator ("\r\n") Message separator.
        # @option opts [Boolean] :no_msg_separator (nil) If true, the socket will not use message separators.
        def initialize(opts={})
            setup_opts(opts)
            @connected = false
        end
        
        #
        # Connects to the server. This is an idempotent operation.
        #
        def connect
            return if @connected && (@socket && !@socket.closed?)
            on_connect
            @connected = true
        end

        #
        # Disconnects to the server. This is an idempotent operation.
        #
        def disconnect
            return unless @connected
            if @socket && !@socket.closed?
                @socket.close 
                log(:debug, "Socket successfully disconnected")
                @connected = false
                return true
            end
        end
        
        #
        # Sends the message to the server, and reads and return the response if read_response=true.
        # If you call this method and the socket is not connected yet, it will automatically connect the socket.
        # @param [String] msg The message to send.
        # @param [Boolean] read_response Whether or not to read from the server after sending the message. Defaul to true.
        #
        #
        def send_msg(msg, read_response=true)
            msg_to_send = msg.dup
            msg_to_send << @separator unless @separator.nil? || msg.end_with?(@separator)

            # This is an idempotent operation
            connect

            log(:debug, "Sending #{msg_to_send.inspect}")
            send_non_block(msg_to_send)
            
            if read_response
                resp = receive_non_block 
                log(:debug, "Got #{resp.inspect}")
                resp
            end
        # Raised by some IO operations when reaching the end of file. Many IO methods exist in two forms,
        # one that returns nil when the end of file is reached, the other raises EOFError EOFError.
        # EOFError is a subclass of IOError.
        rescue EOFError => e
            log(:info, "Server disconnected.")
            self.disconnect
            raise e
        # "Connection reset by peer" is the TCP/IP equivalent of slamming the phone back on the hook.
        # It's more polite than merely not replying, leaving one hanging.
        # But it's not the FIN-ACK expected of the truly polite TCP/IP converseur.
        rescue Errno::ECONNRESET => e
            log(:info, 'Connection reset by peer.')
            self.disconnect
            raise e
        rescue Errno::EPIPE => e
            log(:info, 'Broken pipe.')
            self.disconnect
            raise e
        rescue Errno::ECONNREFUSED => e
                log(:info, 'Connection refused by peer.')
                self.disconnect
                raise e
        rescue Exception => e
            @socket.close if @socket && !@socket.closed?
            raise e
        end
        
        private
        
        def setup_opts(opts)
            @logger = opts[:logger]
            @timeout = opts[:timeout].to_f || DEFAULT_TIMEOUT
            @timeout = DEFAULT_TIMEOUT if @timeout <= 0
            @separator = opts[:separator] || CRLF
            @separator = nil if opts[:no_msg_separator] == true
        end
        
        def on_connect
        end
        
        def send_non_block(msg)
            begin
                loop do
                    bytes = @socket.write_nonblock(msg)
                    break if bytes >= msg.size
                    msg.slice!(0, bytes)
                    IO.select(nil, [@socket])
                end
            rescue Errno::EAGAIN
                IO.select(nil, [@socket])
            end
        end
        
        def receive_non_block
            resp = ''
            begin
                resp << @socket.read_nonblock(CHUNK_SIZE)
                while @separator && !resp.end_with?(@separator) do
                    resp << @socket.read_nonblock(CHUNK_SIZE)
                end
                resp
            rescue Errno::EAGAIN
                if IO.select([@socket], nil, nil, @timeout)
                    retry
                else
                    self.disconnect
                    raise Timeout::Error, "No response in #{@timeout} seconds."
                end
            rescue EOFError => e
                log(:info, "Server disconnected.")
                self.disconnect
                raise e
            rescue Errno::EPIPE => e
                log(:info, "Broken pipe.")
                self.disconnect
                raise e
            end
        end
    end
end
