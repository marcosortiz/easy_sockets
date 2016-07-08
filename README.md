# Easy Sockets

[![Gem Version][GV img]][Gem Version]
[![Build Status][BS img]][Build Status]
[![Dependency Status][DS img]][Dependency Status]
[![Code Climate][CC img]][Code Climate]
[![Coverage Status][CS img]][Coverage Status]

[Gem Version]: https://rubygems.org/gems/easy_sockets
[Build Status]: https://travis-ci.org/marcosortiz/easy_sockets
[Dependency Status]: https://gemnasium.com/marcosortiz/easy_sockets
[Code Climate]: https://codeclimate.com/github/marcosortiz/easy_sockets
[Coverage Status]: https://codeclimate.com/github/marcosortiz/easy_sockets/coverage

[GV img]: https://badge.fury.io/rb/easy_sockets.svg
[BS img]: https://travis-ci.org/marcosortiz/easy_sockets.svg?branch=master
[DS img]: https://gemnasium.com/marcosortiz/easy_sockets.svg
[CC img]: https://codeclimate.com/github/marcosortiz/easy_sockets/badges/gpa.svg
[CS img]: https://codeclimate.com/github/marcosortiz/easy_sockets/badges/coverage.svg

## Description

Over and over I see developers struggling to implement basic sockets with features available on ruby socket stdlib.

easy_sockets, takes care of basic details that usually are overlooked by developers when implementing TCP/Unix sockets from scratch.

I also strongly recommend [the following book](http://www.jstorimer.com/products/working-with-tcp-sockets) if you want to learn more about TCP sockets.

### Dependencies

easy_sockets only uses the following ruby stdlib gems:

- sockets
- logger
- timeout (just to raise Timeout::Error)

### Transparent idempotent connect and disconnect operations

You don't needneed to worry about connecting your socket (you can still call it if you want). All you need to do is call `send_msg`. If the socket object is not connected yet, it will automatically try to connect the socket before sending the message. You still need to disconnect your socket after using it.

The `connect` and `disconnect` methods are idempotent methods. That means you can call them over and over again and they will only try to do something (connect and disconnect respectively) when the instance of your socket object is disconnected and connected respectively.

The code bellow illustrates this:

```ruby
irb(main):001:0> require 'easy_sockets'
=> true
irb(main):002:0> s = EasySockets::TcpSocket.new
=> #<EasySockets::TcpSocket:0x007fd16bb69308 @logger=nil, @timeout=0.5, @separator="\r\n", @connected=false, @port=2000, @host="127.0.0.1">
irb(main):003:0> s.connected
=> false
irb(main):004:0> s.connect
=> true
irb(main):005:0> s.connected
=> true
irb(main):006:0> s.connect
=> nil
irb(main):007:0> s.connect
=> nil
irb(main):008:0> s.connected
=> true
irb(main):009:0> s.disconnect
=> true
irb(main):010:0> s.connected
=> false
irb(main):011:0> s.disconnect
=> nil
irb(main):012:0> s.disconnect
=> nil
```

### Safe connect, read and write timeout implementation

There is a lot of material on the internet saying [why you should not use ruby timeout stdlib](http://www.mikeperham.com/2015/05/08/timeout-rubys-most-dangerous-api/). However, over and over I see developers using the timeout stdlib for production code!

easy_sockets implements connect, read and write timeouts using [IO.select](http://ruby-doc.org/core-2.3.1/IO.html#method-c-select).

### Framing Messages

Usually, if you don't want to open and close a new connection everytime you need to send something to the server, you need to implement some sort of message framing. Openning (and closing) a new connection for each message, generates unnecessary overhead. While this might be ok for some communications where the messsage exchange rate is low, it might be a show stopper when this rate needs to be bigger.

Message framing is an agreement between client and server on the message format. That way clients and server can signal that one message is ending and another on is beginning.

There are numerous ways of framing messages. easy_sockets support 2:

1. **Message separators:** When pass the `:separator` option when creating your socket, easy_sockets will add it to the end of the message. For instance, if you setup `separator: "\r\n"` and you call `send_msg("some_message")`, the server will receive `"some_message\r\n"`.

2. **No separators**: When you pass the option `no_separator: true` when creating your socket, easy_sockets will not add anything to the end of the message. This is useful when both client and server uses a more specific protocol. For instance, both client and server know that the first 4 bytes of the message represent and little ending integer, and depending on the value of that integer, the message will have a specific size and format.

Whether to use separators or not, is totally up to what both client and server expects.

> If you decide to use new lines as the message separator, remember that it is `\n` on Unix systems but `\r\n` on Windows. So, be sure that both client and server are using the same separator.
 
## Installation

Add this line to your application's Gemfile:
```ruby
gem 'easy_sockets'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install easy_sockets

## Usage

Make sure you have netcat installed on your system. We will use it to emulate our servers.

### TCP Sockets

Open up a terminal window and type the following to start a TCP server:
```bash
nc -ckl 2500
```

On another terminal window, run the following [code](https://github.com/marcosortiz/easy_sockets/blob/master/examples/tcp_socket.rb) to start the client:
```ruby
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
```

Then typing `sample_request` in the client terminal, you should see:
```
$ bundle exec ruby examples/tcp_socket.rb 
Please write the message you want to send and hit ENTER, or type Ctrl+c to quit:
sample_request
D, [2016-06-30T15:17:39.648945 #90385] DEBUG -- : Successfully connected to tcp://127.0.0.1:2500.
D, [2016-06-30T15:17:39.649044 #90385] DEBUG -- : Sending "sample_request\r\n"
```

And the server terminal window should display:
```
$ nc -ckl 2500
sample_request

```

Then type `sample_response` on the server terminal window, and you should see:
```
$ nc -ckl 2500
sample_request
sample_response

```

And the client window should show:
```
$ bundle exec ruby examples/tcp_socket.rb 
Please write the message you want to send and hit ENTER, or type Ctrl+c to quit:
sample_request
D, [2016-06-30T15:17:39.648945 #90385] DEBUG -- : Successfully connected to tcp://127.0.0.1:2500.
D, [2016-06-30T15:17:39.649044 #90385] DEBUG -- : Sending "sample_request\r\n"
D, [2016-06-30T15:19:52.494791 #90385] DEBUG -- : Got "sample_response\r\n"
Please write the message you want to send and hit ENTER, or type Ctrl+c to quit:

```

Press `Ctrl+c` on the client and server terminal windows to terminate both.

### Unix Sockets

Open up a terminal window and type the following to start a Unix server:
```bash
nc -Ucl /tmp/test_socket
```

On another terminal window, run the following [code](https://github.com/marcosortiz/easy_sockets/blob/master/examples/unix_socket.rb) to start the client:
```ruby
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
```

Then typing `sample_request` in the client terminal, you should see:
```
marcosortiz@~/dev/easy_sockets$ bundle exec ruby examples/unix_socket.rb 
Please write the message you want to send and hit ENTER, or type Ctrl+c to quit:
sample_request
D, [2016-06-30T15:38:10.303188 #96993] DEBUG -- : Successfully connected to /tmp/test_socket.
D, [2016-06-30T15:38:10.303265 #96993] DEBUG -- : Sending "sample_request\n"
```

And the server terminal window should display:
```
$ nc -Ul /tmp/test_socket
sample_request

```

Then type `sample_response` on the server terminal window, and you should see:
```
$ nc -Ul /tmp/test_socket
sample_request
sample_response    

```

And the client window should show:
```
$ bundle exec ruby examples/unix_socket.rb 
Please write the message you want to send and hit ENTER, or type Ctrl+c to quit:
sample_request
D, [2016-06-30T15:38:10.303188 #96993] DEBUG -- : Successfully connected to /tmp/test_socket.
D, [2016-06-30T15:38:10.303265 #96993] DEBUG -- : Sending "sample_request\n"
D, [2016-06-30T15:38:23.503411 #96993] DEBUG -- : "sample_response\n"
D, [2016-06-30T15:38:23.503488 #96993] DEBUG -- : Got "sample_response\n"
Please write the message you want to send and hit ENTER, or type Ctrl+c to quit:

```

Press `Ctrl+c` on the client and server terminal windows to terminate both. Also, type `rm -rf /tmp/test_socket` to remove the socket file.

### UDP Sockets

Open up a terminal window and type the following to start a TCP server:
```bash
nc -ukcl 2500
```

On another terminal window, run the following [code](https://github.com/marcosortiz/easy_sockets/blob/master/examples/udp_socket.rb) to start the client:
```ruby
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
s = EasySockets::UdpSocket.new(opts)
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
```

Then typing `sample_request` in the client terminal, you should see:
```
$ bundle exec ruby examples/udp_socket.rb 
Please write the message you want to send and hit ENTER, or type Ctrl+c to quit:
sample_request
D, [2016-07-08T10:45:17.935787 #83697] DEBUG -- : Successfully connected to udp://127.0.0.1:2500.
D, [2016-07-08T10:45:17.935893 #83697] DEBUG -- : Sending "sample_request\r\n"

```

And the server terminal window should display:
```
$ nc -ukcl 2500
sample_request

```

Then type `sample_response` on the server terminal window, and you should see:
```
$ nc -ukcl 2500
sample_request
sample_response

```

And the client window should show:
```
$ bundle exec ruby examples/udp_socket.rb 
Please write the message you want to send and hit ENTER, or type Ctrl+c to quit:
sample_request
D, [2016-07-08T10:45:17.935787 #83697] DEBUG -- : Successfully connected to udp://127.0.0.1:2500.
D, [2016-07-08T10:45:17.935893 #83697] DEBUG -- : Sending "sample_request\r\n"
D, [2016-07-08T10:45:22.086731 #83697] DEBUG -- : Got "sample_response\r\n"
Please write the message you want to send and hit ENTER, or type Ctrl+c to quit:

```

Press `Ctrl+c` on the client and server terminal windows to terminate both.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## 5. Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcosortiz/easy_sockets.


## 6. License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

