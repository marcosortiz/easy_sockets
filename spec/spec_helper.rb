require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'easy_sockets'
require 'easy_sockets/tcp/tcp_server'
require 'easy_sockets/unix/unix_server'

TEST_LOGS_PATH = "test_logs"

def clean_logs
    FileUtils.rm_rf TEST_LOGS_PATH if File.exist? TEST_LOGS_PATH
end

def check_log_dir
    FileUtils.mkdir TEST_LOGS_PATH unless File.exist? TEST_LOGS_PATH
end

RSpec.configure do |config|
    config.before(:all) do
        clean_logs
        check_log_dir
    end
end


class MyTestTcpSocket < EasySockets::TcpSocket
    attr_reader :connect_count, :disconnect_count
    
    def initialize(opts={})
        super(opts)
        @connect_count = 0
        @disconnect_count = 0
    end
    
    def connect
        prev = self.connected?
        super
        @connect_count += 1 if self.connected? && prev != self.connected?
    end

    def disconnect
        prev = self.connected?
        super
        @disconnect_count += 1 if !self.connected? && prev != self.connected?
    end
    
end

def start_tcp_server(port=2500)
    @servers ||= []
    t = Thread.new do
        opts = {
            logger: Logger.new("#{TEST_LOGS_PATH}/tcp_server.log"),
            port: port,
        }
        server = EasySockets::TcpServer.new(opts)
        server.start
    end
    @servers << t
    t.join(0.01)
end

class MyTestUnixSocket < EasySockets::UnixSocket
    attr_reader :connect_count, :disconnect_count
    
    def initialize(opts={})
        super(opts)
        @connect_count = 0
        @disconnect_count = 0
    end
    
    def connect
        prev = self.connected?
        super
        @connect_count += 1 if self.connected? && prev != self.connected?
    end

    def disconnect
        prev = self.connected?
        super
        @disconnect_count += 1 if !self.connected? && prev != self.connected?
    end
    
end

def start_unix_server(socket_path="#{TEST_LOGS_PATH}/unix_server")
    @servers ||= []
    t = Thread.new do
        opts = {
            logger: Logger.new("#{TEST_LOGS_PATH}/unix_server.log"),
            socket_path: socket_path,
        }
        server = EasySockets::UnixServer.new(opts)
        server.start
    end
    @servers << t
    t.join(0.01)
end

def stop_servers
    @servers.each do |t|
        Thread.kill(t)
        t.join(0.01)
    end
end