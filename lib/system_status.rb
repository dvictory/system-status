require "system_status/version"

os = RUBY_PLATFORM

if os.include? "linux"
  require "system_status/stats"
else
  class SystemStatus
    def self.get_stats
      {error: "OS not supported"}
    end
  end
end

module SystemStatus
  module Stats
  end
end
