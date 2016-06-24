module EasySockets
    module Utils
        def log(level, msg)
            logger.send(level, msg) unless logger.nil?
        end
    end
end