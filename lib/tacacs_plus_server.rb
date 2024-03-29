require 'getoptlong'
require 'rubygems'
require 'tacacs_plus'
gem 'tacacs_plus', '= 1.1.0'


def cleanup_on_stop(pid_file,conf_file)
    begin
        File.delete(pid_file)
    rescue Errno::ESRCH => error
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Could not delete pid file. #{error}")
    end

    return(nil)
end

def kill_existing_daemon(pid_file)
    begin
        file = File.open(pid_file)
        child = file.readline.to_i
        Process.kill('INT', child)
        file.close
        File.delete(pid_file)
    rescue Errno::ENOENT => error
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Error with pid file: #{error}")
    rescue Errno::ESRCH
    end

    return(nil)
end


def process_config(conf_file, dump_file, log_file)
    config = nil

    # load up main config file
    begin
        config = YAML.load_file(conf_file)
    rescue Exception => error
        error = "#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Error with file #{conf_file}: #{error}"
        raise(error)
    end

    # set up dump file
    config[:tacacs_daemon][:dump_file] = File.expand_path(dump_file) if (dump_file)

    # set up log file
    config[:tacacs_daemon][:logger] = File.expand_path(log_file) if (log_file)

    return(config)
end


def redirect_io(error_log)
    STDIN.reopen('/dev/null')
    STDOUT.reopen(error_log, 'a')
    STDERR.reopen(error_log, 'a')
end


def reload_daemon(pid_file)
    if (!File.exists?(pid_file))
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - PID file #{pid_file} does not exist. Cannot reload daemon.")
        return(nil)
    end

    begin
        file = File.open(pid_file)
        pid = file.readline.to_i
        file.close
        Process.kill('USR1', pid)
    rescue Errno::ESRCH => error
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Reload failed. #{error}\n\n#{error.backtrace.join("\n")}")
    end

    return(nil)
end


def start_daemon(conf_file, dump_file, error_log, log_file, pid_file, stats_file)
    # initialize server
    begin
        config = process_config(conf_file, dump_file, log_file)
        server = TacacsPlus::Server.new(config)
    rescue Exception => error
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Failed to re-initialize TACACS+ server. #{error}\n\n#{error.backtrace.join("\n")}")
        exit(2)
    end

    # if pid file exists, check that another instance isnt already running
    # if so, then stop it
    kill_existing_daemon(pid_file) if(File.exists?(pid_file))

    # fork off daemon
    child = Process.fork do
        Process.setsid
        Dir::chdir('/')
        File::umask(0)

        # setup signal trapping & start server
        trap("INT") do
            server.stop
            cleanup_on_stop(pid_file,conf_file)
        end

        trap("TERM") do
            server.stop
            cleanup_on_stop(pid_file,conf_file)
        end

        trap("HUP") do
            # re-initialize server
            begin
                config = process_config(conf_file, dump_file, log_file)
                server.restart_with(config)
            rescue Exception => error
                STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Failed to reload TACACS+ server. #{error}")
                exit(2)
            end
        end

        trap("USR1") do
            # write config
            begin
                config = server.configuration
                f = File.open(conf_file, 'w')
                f.puts(config.to_yaml)
                f.close
            rescue Exception => error
                STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Failed to write TACACS+ server configuration. #{error}\n#{error.backtrace.join("\n")}")
            end
        end

        trap("USR2") do
            # re-initialize logger
            begin
                server.restart_logger
            rescue Exception => error
                STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Failed to reload TACACS+ server logger. #{error}")
            end
        end

        trap("ALRM") do
            # dump connection stats
            begin
                f = File.open(stats_file, 'w')
                f.print("#{Time.now.to_i}:#{server.client_connection_count!}")
                f.close
            rescue Exception => error
                STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Failed to write stats_file. #{error}")
            end
        end

        begin
            server.start
        rescue Exception => error
            STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Server raised uncaught exception: #{error}\n\n #{error.backtrace.join("\n")}")
            exit(2)
        end

    end

    # check that child is running
    child_is_running = true
    begin
        Process.kill(0, child)
    rescue Errno::ESRCH
        child_is_running = false
    end

    if (child_is_running)
        begin
            # log to pid file
            file = File.open(pid_file, 'w')
            file.print(child)
            file.close
            STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Server Started")
        rescue Exception => error
            STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Error opening pid file: #{error}")
            Process.kill('INT', child)
            return
        end
    end

    return(nil)
end


def stop_daemon(pid_file)
    if (!File.exists?(pid_file))
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - PID file #{pid_file} does not exist. Cannot stop daemon.")
        return(nil)
    end

    begin
        file = File.open(pid_file)
        pid = file.readline.to_i
        file.close
        Process.kill('INT', pid)
    rescue Errno::ESRCH => error
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Could not stop daemon. #{error}")
    end

    return(nil)
end



######   MAIN   ######

# get args from cli
if (ARGV.length == 0)
    puts "\nUsage:\nruby tacacs_plus_server.rb [options]\n\n"
    puts "Example:\nruby tacacs_plus_server.rb --conf_file sample_config.yml --start\n\n"
    puts "Options:\n"
    puts "--conf_file - configuration file for the server."
    puts "--dump_file - causes server to packet dump to this file."
    puts "--error_log - the server error_log file. 'error.log' by default."
    puts "--log_file - the AAA log file. 'aaa.log' by default."
    puts "--pid_file - the server pid file. 'pid' by default."
    puts "--reload - reload the configuration."
    puts "--reload-logger - reload the logger."
    puts "--restart - restart the server with a new pid."
    puts "--start - start the server."
    puts "--stats_file - the file into which client connection count information is dumped. format of file is 'time:count'"
    puts "--stop - stop the server."
    puts "--write - write the currently running configuration.\n\n"
    puts "Running with no start/stop directive will test the configuration file.\n\n"
    print "\n\n"
    puts "Signaling:"
    puts "SIGINT - shutdown"
    puts "SIGTERM - shutdown"
    puts "SIGHUP - reinitialize"
    puts "SIGUSR1 - write configuration"
    puts "SIGUSR2 - re-initialize logger"
    puts "SIGALRM - write stats file\n\n"
    exit(0)
end


opts = GetoptLong.new([ '--conf_file', GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--dump_file', GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--error_log', GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--log_file', GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--pid_file', GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--reload', GetoptLong::NO_ARGUMENT ],
                      [ '--reload-logger', GetoptLong::NO_ARGUMENT ],
                      [ '--restart', GetoptLong::NO_ARGUMENT ],
                      [ '--start', GetoptLong::NO_ARGUMENT ],
                      [ '--stats_file', GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--stop', GetoptLong::NO_ARGUMENT ],
                      [ '--write', GetoptLong::NO_ARGUMENT ])

conf_file = nil
dump_file = nil
error_log = File.expand_path('error.log')
log_file = File.expand_path('aaa.log')
pid_file = File.expand_path('pid')
stats_file = File.expand_path('stats.log')
run_directive = nil
begin
    opts.each do |opt, arg|
        case opt
            when '--conf_file'
                conf_file = File.expand_path(arg)
            when '--dump_file'
                dump_file = arg
            when '--error_log'
                error_log = File.expand_path(arg)
            when '--log_file'
                log_file = arg
            when '--pid_file'
                pid_file = File.expand_path(arg)
            when '--reload'
                run_directive = :reload
            when '--reload-logger'
                run_directive = :reload_logger
            when '--restart'
                run_directive = :restart
            when '--start'
                run_directive = :start
            when '--stats_file'
                stats_file = arg
            when '--stop'
                run_directive = :stop
            when '--write'
                run_directive = :write
        end
    end
rescue Exception => error
    exit(1)
end


# start/stop/restart server
if (run_directive == :reload)
    redirect_io(error_log)
    reload_daemon(pid_file)

elsif (run_directive == :reload_logger)
    redirect_io(error_log)
    if (!File.exists?(pid_file))
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - PID file #{pid_file} does not exist. Cannot write configuration.")
    else
        begin
            file = File.open(pid_file)
            pid = file.readline.to_i
            file.close
            Process.kill('USR2', pid)
        rescue Errno::ESRCH => error
            STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Could not reload logger. #{error}")
        end
    end

elsif (run_directive == :restart)
    # exit if config_file is nil
    if (!conf_file)
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - No config file provided.")
        exit(1)
    end

    redirect_io(error_log)
    stop_daemon(pid_file)
    start_daemon(conf_file, dump_file, error_log, log_file, pid_file)

elsif (run_directive == :start)
    # exit if config_file is nil
    if (!conf_file)
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - No config file provided.")
        exit(1)
    end

    redirect_io(error_log)
    start_daemon(conf_file, dump_file, error_log, log_file, pid_file, stats_file)

elsif (run_directive == :stop)
    redirect_io(error_log)
    stop_daemon(pid_file)

elsif (run_directive == :write)
    redirect_io(error_log)
    if (!File.exists?(pid_file))
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - PID file #{pid_file} does not exist. Cannot write configuration.")
    else
        begin
            file = File.open(pid_file)
            pid = file.readline.to_i
            file.close
            Process.kill('USR1', pid)
        rescue Errno::ESRCH => error
            STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - Could not write configuration. #{error}")
        end
    end

else
    # exit if config_file is nil
    if (!conf_file)
        STDERR.puts("#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} - No config file provided.")
        exit(0)
    end

    print "\nTesting Configuration... "

    begin
        config = process_config(conf_file, dump_file, log_file)
        server = TacacsPlus::Server.new(config)
        puts "Passed."
    rescue Exception => error
        puts "Failed. #{error}"
    end
    print "\n"
end

exit(0)
__END__
