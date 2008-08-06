class SystemLogArchive < ActiveRecord::Base
    validates_presence_of :archive_file
    validates_uniqueness_of :archive_file

    after_destroy :cleanup


    # return true on success, return false if any errors
    def SystemLogArchive.archive
        ret_status = true

        # update entries which will be archived today
        SystemLogArchive.update_all("archived_on = '#{Date.today.to_s}'", "archived_on = ''")

        managers = {}
        Manager.find(:all).each {|m| managers[m.id] = m.name}

        logs = {}
        SystemLog.find(:all, :conditions => "archived_on = '#{Date.today.to_s}'", :order => :created_at).each do |l|
            day = l.created_at.strftime("%Y-%m-%d")
            log_str = "#{l.created_at}\t#{l.level}\t#{managers[l.owning_manager_id]}\t#{l.username}\t#{l.message}\n"
            if ( logs.has_key?(day) )
                logs[day] << log_str
            else
                logs[day] = log_str
            end
        end

        logs.each_pair do |day, log|
            filename = File.expand_path("#{RAILS_ROOT}/log/system_logs/#{day}.txt")
            arch = SystemLogArchive.find_by_archive_file(filename)
            if (!arch)
                SystemLogArchive.create(:archive_file => filename, :archived_on => day)
            end

            begin
                f = File.open(filename, 'a')
                f.print(log)
                f.close
            rescue Exception => error
                Manager.local.log(:message => "SystemLogArchive - Error writing to archive file: #{error}")
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


private

    def cleanup
        begin
            File.delete(self.archive_file) if ( File.exists?(self.archive_file) )
        rescue Exception => err
            self.errors.add_to_base("Error removing files: #{err}")
        end
    end

end
