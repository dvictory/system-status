require "system_status/version"

os = RUBY_PLATFORM
text =  "Unsupported OS! This gem requires Linux"

if os.include? "linux"
  require "system_status/stats"
else
   puts text
end

module SystemStatus
end
