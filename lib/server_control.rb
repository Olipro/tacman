run_directive = 'start'
ENV['RAILS_ENV'] = 'production'

# get cli args
if (ARGV[0])
    run_directive = ARGV[0]
end

# load rails
require File.dirname(__FILE__) + '/../config/environment.rb'
db = YAML.load_file(File.dirname(__FILE__) + '/../config/database.yml')
ActiveRecord::Base.connection = db[RAILS_ENV]


# redirect stdio
STDIN.reopen('/dev/null')
STDOUT.reopen('/dev/null', 'w')
STDERR.reopen('/dev/null', 'w')

local_manager = Manager.local

# start/stop/restart
if (run_directive == 'start')
    TacacsDaemon.find(:all, :conditions => 'manager_id = null').each do |tacacs_daemon|
        tacacs_daemon.errors.each_full {|error| local_manager.log(:level => 'error', :message => "server_control.rb start : TacacsDaemon '#{tacacs_daemon.name}' - #{error}") }
    end

elsif (run_directive == 'stop')
    TacacsDaemon.find(:all, :conditions => 'manager_id = null').each do |tacacs_daemon|
        tacacs_daemon.errors.each_full {|error| local_manager.log(:level => 'error', :message => "server_control.rb stop : TacacsDaemon '#{tacacs_daemon.name}' - #{error}") }
    end

elsif (run_directive == 'restart')
    TacacsDaemon.find(:all, :conditions => 'manager_id = null').each do |tacacs_daemon|
        tacacs_daemon.errors.each_full {|error| local_manager.log(:level => 'error', :message => "server_control.rb restart : TacacsDaemon '#{tacacs_daemon.name}' - #{error}") }
    end

else
    local_manager.log(:level => 'error', :message => "server_control.rb - unknown directive '#{run_directive}'")
    exit(1)
end

exit(0)

__END__