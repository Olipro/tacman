class AaaLogArchive < ActiveRecord::Base
    belongs_to :configuration

    validates_presence_of :configuration_id
    validates_presence_of :archive_file
    validates_uniqueness_of :archive_file
    validates_presence_of :archived_on

    before_validation :setup
    after_destroy :cleanup


    def AaaLogArchive.zip_old_archives!
        date = Date.today - 1
        local_manager = Manager.local
        AaaLogArchive.find(:all, :conditions => "archived_on <= '#{date}'").each do |arch|
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

    def setup
        self.archived_on = Date.today if (!self.archived_on)
    end

end
