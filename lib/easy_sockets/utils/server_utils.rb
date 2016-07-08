module EasySockets
    module ServerUtils
        
        def register_shutdown_signals
            [:INT, :QUIT, :TERM].each do |signal|
                Signal.trap(signal) do
                    t = Thread.new do
                        stop
                    end
                    t.join
                end
            end
        end
        
        def accept_non_block(server)
            begin
                connection = server.accept_nonblock
            rescue Errno::EAGAIN
                shutdown if @stop_requested
                retry
            end
        end
        
        def read_non_block(connection)
            msg = ''
            begin
                msg << connection.read_nonblock(EasySockets::CHUNK_SIZE)
                while !msg.end_with?(@separator) do
                    msg << connection.read_nonblock(EasySockets::CHUNK_SIZE)
                end
            rescue Errno::EAGAIN
                if IO.select([connection], nil, nil, @timeout)
                    retry
                end
            end
            @logger.info "Got: #{msg.inspect}" unless msg.nil? || msg.empty?
            msg
        end
        
        def udp_read_non_block(connection)
            total_msg = ''
            addr = nil
            begin
                msg, addr = connection.recvfrom_nonblock(CHUNK_SIZE)
                total_msg << msg
                while !total_msg.end_with?(@separator) do
                    msg, addr = connection.recvfrom_nonblock(EasySockets::CHUNK_SIZE)
                    total_msg << msg
                end
                @logger.info "Got: #{total_msg.inspect}" unless total_msg.nil? || total_msg.empty?
                total_msg.empty? ? nil : [total_msg, addr]
            rescue IO::WaitReadable
                if IO.select([connection], nil, nil, @timeout)
                    retry
                end
            end
        end
        
        def write_non_block(connection, msg)
            return 0 unless msg && msg.is_a?(String)
            total_bytes = 0
            begin
                loop do
                    bytes = connection.write_nonblock(msg)
                    total_bytes += bytes
                    break if bytes >= msg.size
                    msg.slice!(0, bytes)
                    IO.select(nil, [connection])
                end
                @logger.info "Sent: #{msg.inspect}"
                total_bytes
            rescue Errno::EAGAIN
                IO.select(nil, [connection], nil, @timeout)
            end
        end
        
        def shutdown
            if @stop_requested
                @connections.each do |c|
                    c.close
                    @logger.info "Server shutting down: closed connection #{c}."
                end
                exit
            end
        end
        
    end
end