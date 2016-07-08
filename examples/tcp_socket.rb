require 'easy_sockets'

host = ARGV[0] || '127.0.0.1'

port = ARGV[1].to_i
port = 2500 if port <= 0

opts = {
    host:      host,
    port:      port,
    timeout:   300,
    separator: "\r\n",
    logger: Logger.new(STDOUT),
}
s = EasySockets::TcpSocket.new(opts)
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