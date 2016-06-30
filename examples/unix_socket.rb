require 'easy_sockets'

host = ARGV[0] || '127.0.0.1'

socket_path = ARGV[1]
socket_path ||= '/tmp/test_socket'

opts = {
    host:      host,
    socket_path: socket_path,
    timeout:   300,
    separator: "\n",
    logger: Logger.new(STDOUT),
}
s = EasySockets::UnixSocket.new(opts)
[:INT, :QUIT, :TERM].each do |signal|
    Signal.trap(signal) do
        exit
    end
end

loop do
    puts "Please write the message you want to send and hit ENTER, or type Ctrl+c to quit:"
    msg = gets.chomp
    s.send_msg(msg)
end