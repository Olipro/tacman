#!/usr/bin/ruby

require 'time'
require 'date'

# get serials & pids for running tacacs daemons
files = Dir.glob("/var/tacman/tmp/pids/tacacs_daemon_pid_files/*")
pids = {}
files.each do |f|
    s = File.basename(f)
    begin
        pids[s] = File.open("/var/tacman/tmp/pids/tacacs_daemon_pid_files/#{s}").read
    rescue
    end
end

# tell daemons to write their connection count data
pids.each_value { |p| Process.kill('ALRM', p.to_i) }

# wait a moment for results
sleep(3)

# read connection data
connections = {}
pids.each_key do |s|
    begin
        connections[s] = File.open("/var/tacman/tmp/tacacs_daemon_stats/#{s}").read
    rescue
    end
end

# update rrd
today = Time.parse( Date.today.to_s + " 00:00:00" ).to_i
week =  Time.parse( (Date.today-7).to_s + " 00:00:00" ).to_i
month =  Time.parse( (Date.today-30).to_s + " 00:00:00" ).to_i
year =  Time.parse( (Date.today-365).to_s + " 00:00:00" ).to_i
base_graph_dir = "/var/tacman/public/graphs/tacacs_daemons/"
connections.each_pair do |s,c|
    graph_dir = base_graph_dir + "#{s}/"
    file = "/var/tacman/log/rrdtool/tacacs_daemons/#{s}"

    # create rrd if non exist
    if ( !File.exists?(file) )
        arg = "create #{file} --start #{today} DS:connections:GAUGE:600:U:U " +
              "RRA:AVERAGE:0.5:1:600 RRA:AVERAGE:0.5:6:700 RRA:AVERAGE:0.5:24:775 RRA:AVERAGE:0.5:288:797"
        `rrdtool #{arg}`
    end

    # update
    arg = "update #{file} #{c}"
    `rrdtool #{arg}`

    # generate graphs
    arg = "graph #{graph_dir}daily.jpg --start #{today} -t 24 hour -w 600 " +
          "DEF:connections=#{file}:connections:AVERAGE LINE1:connections#217A2D:\"Connections\""
    `rrdtool #{arg}`
    arg = "graph #{graph_dir}weekly.jpg --start #{week}  --tt 7 day -w 600 " +
          " DEF:connections=#{file}:connections:AVERAGE LINE1:connections#217A2D:\"Connections\""
    `rrdtool #{arg}`
    arg = "graph #{graph_dir}monthly.jpg --start #{month}  -t 30 day -w 600 " +
          " DEF:connections=#{file}:connections:AVERAGE LINE1:connections#217A2D:\"Connections\""
    `rrdtool #{arg}`
    arg = "graph #{graph_dir}yearly.jpg --start #{year}  -t 365 day -w 600 " +
          " DEF:connections=#{file}:connections:AVERAGE LINE1:connections#217A2D:\"Connections\""
    `rrdtool #{arg}`
end


