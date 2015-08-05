require 'timeout'

module SystemStatus
  class Stats
    def self.get_stats
      @output = {}

      Timeout::timeout(2) {

        threads = []
        @disk_used = self.disk_used
        @cpu_top = self.cpu_top
        @mem_used = self.mem_used
        @mem_top = self.mem_top
        @load = self.load

        threads << Thread.new { @cpu_used = self.cpu_used }
        threads << Thread.new { @bandwith_rec = self.bandwidth_rec }
        threads << Thread.new { @bandwith_sent = self.bandwidth_sent }
        threads << Thread.new { @disk_writes = self.diskiowrites }
        threads << Thread.new { @disk_reads = self.diskioreads }
        threads.each { |thr| thr.join }

        @output = {
          disk_used: @disk_used,
          cpu_used: @cpu_used,
          cpu_top: @cpu_top,
          mem_used: @mem_used,
          mem_top: @mem_top,
          load: @load,
          bandwidth_rec: @bandwith_rec,
          bandwidth_sent: @bandwith_sent,
          disk_writes: @disk_writes,
          disk_reads: @disk_reads
        }
      }

    rescue Timeout::Error
      @output
    end

    private

    ## Returns a hash of disk with the available space and the used % of disk
    def self.disk_used
      df = `df`

      parts = df.split(" ").map { |s| s }

      output = {}
      for i in (7..parts.size - 1).step(6) do
        output[parts[i]] = { available: ((parts[i+3].to_i.round(2)/1024)/1024).round(2),
                              used: parts[i+4]
        }
      end

      output
    end

    # Show the percentage of CPU used
    def self.cpu_used
      proc0 = File.readlines('/proc/stat').grep(/^cpu /).first.split(" ")
      sleep 0.2
      proc1 = File.readlines('/proc/stat').grep(/^cpu /).first.split(" ")

      proc0_usagesum = proc0[1].to_i + proc0[2].to_i + proc0[3].to_i
      proc1_usagesum = proc1[1].to_i + proc1[2].to_i + proc1[3].to_i
      proc_usage = proc1_usagesum - proc0_usagesum

      proc0_total = 0
      for i in (1..4) do
        proc0_total += proc0[i].to_i
      end
      proc1_total = 0
      for i in (1..4) do
        proc1_total += proc1[i].to_i
      end
      proc_total = (proc1_total - proc0_total)

      cpu_usage = (proc_usage.to_f / proc_total.to_f)

      (500 * cpu_usage).to_f.round(2)
    end

    # return hash of top ten proccesses by cpu consumption
    # example [["apache2", 12.0], ["passenger", 13.2]]
    def self.cpu_top
      ps = `ps aux | awk '{print $11, $3}' | sort -k2nr  | head -n 10`
      array = []
      ps.each_line do |line|
        line = line.chomp.split(" ")
        array << [line.first.gsub(/[\[\]]/, ""), line.last]
      end
      array
    end

    # Show the percentage of Active Memory used
    def self.mem_used
      if File.exists?("/proc/meminfo")
        File.open("/proc/meminfo", "r") do |file|
          @result = file.read
        end
      end

      mem_stat = @result.split("\n").collect{|x| x.strip}
      mem_total = mem_stat[0].gsub(/[^0-9]/, "")
      mem_active = mem_stat[5].gsub(/[^0-9]/, "")
      mem_activecalc = (mem_active.to_f * 100) / mem_total.to_f
      mem_activecalc.round
    end

    # return hash of top ten proccesses by mem consumption
    # example [["apache2", 12.0], ["passenger", 13.2]]
    def self.mem_top
      ps = `ps aux | awk '{print $11, $4}' | sort -k2nr  | head -n 10`
      array = []
      ps.each_line do |line|
        line = line.chomp.split(" ")
        array << [line.first.gsub(/[\[\]]/, ""), line.last]
      end
      array
    end

    # Show the average system load of the past minute
    def self.load
      if File.exists?("/proc/loadavg")
        File.open("/proc/loadavg", "r") do |file|
          @loaddata = file.read
        end

        @loaddata.split(/ /).first.to_f
      end
    end

    # Bandwidth Received Method
    def self.bandrx

      if File.exists?("/proc/net/dev")
        File.open("/proc/net/dev", "r") do |file|
          @result = file.read
        end
      end

      rows = @result.split("\n")

      eth_lo_rows = rows.grep(/eth|lo/)

      row_count = (eth_lo_rows.count - 1)

      for i in (0..row_count)
        eth_lo_rows[i] = eth_lo_rows[i].gsub(/\s+/m, ' ').strip.split(" ")
      end

      columns = Array.new
      for l in (0..row_count)
        temp = Array.new
        temp[0] = eth_lo_rows[l][1]
        temp[1] = eth_lo_rows[l][9]
        columns << temp
      end

      column_count = (columns[0].count - 1)

      total = Array.new
      for p in (0..column_count)
        total[p] = 0
      end

      for j in (0..column_count)
        for k in (0..row_count)
          total[j] = columns[k][j].to_i + total[j]
        end
      end

      total
    end

    # Current Bandwidth Received Calculation in Mbit/s
    def self.bandwidth_rec

      new0 = self.bandrx
      sleep 0.2
      new1 = self.bandrx

      bytes_received = new1[0].to_i - new0[0].to_i
      bits_received = (bytes_received * 8 * 5)

      (bits_received.to_f / 1024 / 1024).round(3)
    end

    # Bandwidth Transmitted Method
    def self.bandtx

      if File.exists?("/proc/net/dev")
        File.open("/proc/net/dev", "r") do |file|
          @result = file.read
        end
      end

      rows = @result.split("\n")

      eth_lo_rows = rows.grep(/eth|lo/)

      row_count = (eth_lo_rows.count - 1)

      for i in (0..row_count)
        eth_lo_rows[i] = eth_lo_rows[i].gsub(/\s+/m, ' ').strip.split(" ")
      end

      columns = Array.new
      for l in (0..row_count)
        temp = Array.new
        temp[0] = eth_lo_rows[l][1]
        temp[1] = eth_lo_rows[l][9]
        columns << temp
      end

      column_count = (columns[0].count - 1)

      total = Array.new
      for p in (0..column_count)
        total[p] = 0
      end

      for j in (0..column_count)
        for k in (0..row_count)
          total[j] = columns[k][j].to_i + total[j]
        end
      end

      total
    end

    # Current Bandwidth Transmitted in Mbit/s
    def self.bandwidth_sent

      new0 = self.bandtx
      sleep 0.2
      new1 = self.bandtx

      bytestransmitted = new1[1].to_i - new0[1].to_i
      bitstransmitted = (bytestransmitted * 8 * 5)
      (bitstransmitted.to_f / 1024 / 1024).round(3)
    end

    # Disk Usage Method
    def self.diskio

      if File.exists?("/proc/diskstats")
        File.open("/proc/diskstats", "r") do |file|
          @result = file.read
        end
      end

      rows = @result.split("\n")

      row_count = (rows.count - 1)

      for i in (0..row_count)
        rows[i] = rows[i].gsub(/\s+/m, ' ').strip.split(" ")
      end

      columns = Array.new
      for l in (0..row_count)
        temp = Array.new
        temp[0] = rows[l][3]
        temp[1] = rows[l][7]
        columns << temp
      end

      column_count = (columns[0].count - 1)

      total = Array.new
      for p in (0..column_count)
        total[p] = 0
      end

      for j in (0..column_count)
        for k in (0..row_count)
          total[j] = columns[k][j].to_i + total[j]
        end
      end

      total
    end

    # Current Disk Reads Completed
    def self.diskioreads

      new0 = self.diskio
      sleep 0.2
      new1 = self.diskio

      (new1[0].to_i - new0[0].to_i) * 5
    end

    # Current Disk Writes Completed
    def self.diskiowrites

      new0 = self.diskio
      sleep 0.2
      new1 = self.diskio

      (new1[1].to_i - new0[1].to_i) * 5
    end

  end
end