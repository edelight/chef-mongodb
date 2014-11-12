require 'chef'

module MongoDBCB
  # Shorthand for accessing Chef::Log functions
  module LogHelpers
    def debug(msg)
      Chef::Log.debug msg
    end

    def info(msg)
      Chef::Log.info msg
    end

    # this stomps on Kernel#warn, that's fine
    def warn(msg)
      Chef::Log.warn msg
    end

    def error(msg)
      Chef::Log.error msg
    end
  end
end
