class SystemLogArchive < ActiveRecord::Base
    validates_presence_of :archive_file
    validates_uniqueness_of :archive_file

    after_destroy :cleanup


    # return true on success, return false if any errors
    def SystemLogArchive.archive
        local_manager = Manager.local
        ret_status = true

        managers = {}
        Manager.find(:all).each {|m| managers[m.id] = m.name}

        logs = {}
        SystemLog.find(:all, :conditions => "archived_on is null", :order => :created_at).each do |l|
            day = l.created_at.strftime("%Y-%m-%d")
            log_str = "#{l.created_at}\t#{l.level}\t#{managers[l.owning_manager_id]}\t#{l.username}\t#{l.message}\n"
            if ( logs.has_key?(day) )
                logs[day] << log_str
            else
                logs[day] = log_str
            end
        end

        logs.each_pair do |day, log|
            arch = SystemLogArchive.find_by_archived_on(day)
            if (!arch)
                SystemLogArchive.create(:archive_file => File.expand_path("#{RAILS_ROOT}/log/system_logs/#{day}.txt"), :archived_on => day)
            elsif (arch.zipped?)
                if (!arch.unzip!)
                    local_manager.log(:message => "SystemLogArchive - Error unzipping #{arch.archive_file}: #{arch.errors.full_messages.join(' ')}")
                    next
                end
            end

            filename = arch.archive_file

            begin
                f = File.open(filename, 'a')
                f.print(log)
                f.close
                SystemLog.update_all("archived_on = '#{Date.today.to_s}'",
                                     "archived_on is null and created_at >= '#{day} 00:00:00' and created_at <= '#{day} 23:59:59'")
            rescue Exception => error
                local_manager.log(:message => "SystemLogArchive - Error writing to archive file: #{error}")
                ret_status = false
            end
        end

        return(ret_status)
    end

    def SystemLogArchive.cleanup_logs!
        days = Manager.local.retain_system_logs_for
        return(false) if (days == 0)

        date = (Date.today - days).to_s
        datetime = date + ' 23:59:59'
        SystemLog.delete_all("created_at <= '#{datetime}'")
    end

    def SystemLogArchive.cleanup_archives!
        days = Manager.local.archive_system_logs_for
        return(false) if (days == 0)

        date = (Date.today - days).to_s
        SystemLog.destroy_all("archived_on <= '#{date}'")
    end

    def SystemLogArchive.zip_old_archives!
        date = Date.today -3
        local_manager = Manager.local
        SystemLogArchive.find(:all, :conditions => "archived_on <= '#{date}'").each do |arch|
            if (!arch.zip!)
                local_manager.log(:level => 'error', :message => "#{arch.errors.full_messages.join("\n")}")
            end
        end
    end


    def zip!
        if (self.zipped?)
            self.errors.add_to_base("Cannot compress already compressed file: #{self.archive_file}")
            return(false)
        end

        begin
            msg = `gzip #{self.archive_file}`
            exit_status = $?
            if (exit_status == 1)
                raise msg
            else
                self.update_attribute(:archive_file, self.archive_file + ".gz")
            end
        rescue Exception => error
            self.errors.add_to_base("Could not zip file #{self.archive_file}: #{error}")
            return(false)
        end
        return(true)
    end

    def zipped?
        return(true) if (self.archive_file =~ /.*gz$/)
        return(false)
    end

    def unzip!
        if (!self.zipped?)
            self.errors.add_to_base("Cannot uncompress non gzipped file: #{self.archive_file}")
            return(false)
        end

        begin
            msg = `gunzip #{self.archive_file}`
            exit_status = $?
            if (exit_status == 1)
                raise msg
            else
                self.update_attribute(:archive_file, self.archive_file.sub(/.gz/, '') )
            end
        rescue Exception => error
            self.errors.add_to_base("Could not zip file #{self.archive_file}: #{error}")
            return(false)
        end
        return(true)
    end


private

    def cleanup
        begin
            File.delete(self.archive_file) if ( File.exists?(self.archive_file) )
        rescue Exception => err
            self.errors.add_to_base("Error removing files: #{err}")
        end
    end

end
