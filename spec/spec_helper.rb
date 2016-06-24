require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'easy_sockets'

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

def start_tcp_server(port=2500)
    @servers ||= []
    t = Thread.new do
        server = TCPServer.new(port)
        logger = Logger.new("#{TEST_LOGS_PATH}/tcp_server.log")
        loop do
            client = server.accept
            loop do
                begin
                    msg = client.readpartial(1024)
                rescue EOFError, Errno::ECONNRESET
                    client.close
                    logger.info "Client disconnected."
                    break
                end
                logger.info "Got: #{msg.inspect}"
                sleep 0.0001
                client.write(msg)
                logger.info "Sent: #{msg.inspect}"
                if msg.chomp == 'simulate_crash'
                    client.close
                    break
                end
            end
        end
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