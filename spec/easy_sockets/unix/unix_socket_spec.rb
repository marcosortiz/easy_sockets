require 'spec_helper'
require 'easy_sockets/unix/unix_socket'

describe EasySockets::UnixSocket do

    let :socket_path do
        "#{TEST_LOGS_PATH}/unix_server"
    end

    before :all do
        start_unix_server("#{TEST_LOGS_PATH}/unix_server")
    end
    
    after :all do
        stop_servers
    end

    let :opts do
        {
            :socket_path => socket_path,
            :logger => Logger.new("#{TEST_LOGS_PATH}/unix_client.log")
        }
    end
    
    def unix_socket(options={})
        # EasySockets::UnixSocket.new(opts.merge(options))
        MyTestUnixSocket.new(opts.merge(options))
    end

    def check_connected(socket, status)
        expect(socket.connected?).to be status
        s = socket.instance_variable_get(:@socket)
        expect(s.closed?).to be !status if s
    end
    
    let :msg do
        'xxx'
    end
    
    def get_msg(size)
        'x'*size
    end

    describe 'initialization' do
        it 'must properly setup the options and connect to the server' do
            s = unix_socket
            expect(s.instance_variable_get(:@socket)).to be nil
            expect(s.instance_variable_get(:@socket_path)).to eq socket_path
            expect(s.instance_variable_get(:@timeout)).to eq EasySockets::BasicSocket::DEFAULT_TIMEOUT
            expect(s.instance_variable_get(:@separator)).to eq EasySockets::CRLF
            expect(s.connect_count).to eq 0
            expect(s.disconnect_count).to eq 0
            expect(s.connected?).to be false
        end
    end
    describe 'connecting' do
        context 'with server available' do
            it 'must be an idempotent operation' do
                s = unix_socket
                expect(s.instance_variable_get(:@socket)).to be nil
                10.times do
                    s.connect
                    check_connected(s, true)
                    expect(s.connect_count).to eq 1
                end
                s.disconnect
                check_connected(s, false)
            end
        end
        context 'with server not available but socket file in place' do
            it 'must raise Errno::ENOENT' do
                s = unix_socket
                10.times do
                    s.connect
                    check_connected(s, true)
                    expect(s.connect_count).to eq 1
                end
                s.disconnect
                expect(s.disconnect_count).to eq 1
            end
        end
        context 'with server not available AND socket file does NOT exists' do
            
            let :socket_path do
                "#{TEST_LOGS_PATH}/9999"
            end
            
            it 'must raise Errno::ENOENT' do
                expect(File.exist?(socket_path)).to be false
                s = unix_socket
                10.times do
                    expect {
                        s.connect
                    }.to raise_error(Errno::ENOENT, /No such file or directory/)
                    check_connected(s, false)
                    expect(s.connect_count).to eq 0
                end
            end
        end
    end
    describe 'send_msg' do
        it 'must connect if not already connected' do
            s = unix_socket
            10.times do |i|
                msg = i.to_s
                expect(s.send_msg(i.to_s).chomp).to eq msg
                expect(s.connect_count).to eq 1
            end
            s.disconnect
        end
        context 'when server crashes after client is connected' do
            
            let :msg do
                'simulate_crash'
            end

            it 'must raise an error and disconnect' do
                s = unix_socket
                s.connect
                check_connected(s, true)
                expect(s.send_msg(msg).chomp).to eq msg
                check_connected(s, true) # at this oint the server disconnected us, but we don't know it yet

                # can be Errno::EPIPE, ECONNRESET or EOFError
                expect {
                    s.send_msg('bla')
                }.to raise_error(/(Broken pipe|Connection reset|end of file reached)/) 
                check_connected(s, false)
                expect(s.connect_count).to eq 1
                expect(s.disconnect_count).to eq 1

                # At this point, it will reconnect the socket
                10.times do |i|
                    expect(s.send_msg('bla').chomp).to eq 'bla'
                    expect(s.connect_count).to eq 2
                    expect(s.disconnect_count).to eq 1
                end
                s.disconnect
                check_connected(s, false)
                expect(s.connect_count).to eq 2
                expect(s.disconnect_count).to eq 2
            end
        end
        context 'when the request timeout' do
            
            def set_timeout(s, timeout)
                s.instance_variable_set(:@timeout, timeout)
            end
            
            it 'must raise Timeout::Error and disconnect' do
                s = unix_socket
                s.connect
                
                set_timeout(s, 0.000001)
                expect{
                    s.send_msg('bla')
                }.to raise_error(Timeout::Error, /No response in/)
                
                check_connected(s, false)
                expect(s.connect_count).to eq 1
                expect(s.disconnect_count).to eq 1
            end
        end
        context 'separators' do

            let(:my_socket) do
                Class.new(EasySockets::UnixSocket) do

                    attr_reader :msg_sent

                    def connect
                    end

                    private

                    def send_non_block(msg)
                        @msg_sent = msg
                    end

                    def receive_non_block
                    end
                end
            end

            context 'when we use a msg separator' do

                let :separators do
                    [nil, "\r", "\n", "\r\n", "\n\r", '111', 'aaa', 'zzz']
                end


                it 'it must proparly set the message before sending it' do
                    separators.each do |sep|
                        s = my_socket.new(opts.merge(separator: sep ))
                        s.send_msg(msg)
                        sep_in_use = sep.nil? ? EasySockets::CRLF : sep
                        expect(s.msg_sent).to eq("#{msg}#{sep_in_use}")
                    end
                end
            end
            context 'when we do NOT use a msg separator' do
                it 'must send the msg without any separator' do
                    s = my_socket.new(no_msg_separator: true)
                    s.send_msg(msg)
                    expect(s.msg_sent).to eq msg
                end
            end
        end
        context 'when msg size is smaller than CHUNK_SIZE' do

            let :range do
                (0..EasySockets::CHUNK_SIZE)
            end

            let :step do
                EasySockets::CHUNK_SIZE / 16
            end

            it 'must properly send and receive the msg' do
                s = unix_socket
                range.step(step) do |i|
                    msg_to_send = get_msg(i)
                    resp = s.send_msg(msg_to_send)
                    expect(resp).to eq (msg_to_send + EasySockets::CRLF)
                end
                s.disconnect
            end
        end
        context 'when msg size is bigger than CHUNK_SIZE' do

            let :range do
                (1..10)
            end
            it 'must properly send and receive the msg' do
                s = unix_socket
                range.each do |i|
                    msg_to_send = 'x' * EasySockets::CHUNK_SIZE * i
                    expect(msg_to_send.bytes.size).to eq(EasySockets::CHUNK_SIZE * i)
                    resp = s.send_msg(msg_to_send)
                    expect(resp).to eq (msg_to_send + EasySockets::CRLF)
                end
                s.disconnect
            end
        end
    end
    describe 'disconnect' do
        context 'with socket disconnected' do
            it 'should not do anything' do
                s = unix_socket
                check_connected(s, false)
                10.times do
                    s.disconnect
                    expect(s.disconnect_count).to eq 0
                    check_connected(s, false)
                end
            end
        end
        context 'with socket connected' do
            it 'must be idempotent'  do
                s = unix_socket
                s.connect
                check_connected(s, true)
                10.times do
                    s.disconnect
                    expect(s.disconnect_count).to eq 1
                    check_connected(s, false)
                end
            end
        end
    end
end