class AaaLogArchive < ActiveRecord::Base
    belongs_to :configuration

    validates_presence_of :configuration_id
    validates_presence_of :archive_file
    validates_uniqueness_of :archive_file
    validates_presence_of :archived_on

    before_validation :setup
    after_destroy :cleanup


    def AaaLogArchive.zip_old_archives!
        local_manager = Manager.local
        date = Date.today -3
        AaaLogArchive.find(:all, :conditions => "archived_on <= '#{date}'").each do |arch|
            begin
                exec "gzip #{arch.archive_file}"
                arch.update_attribute(:archive_file, arch.archive_file + ".gz")
            rescue Exception => error
                local_manager.log(:level => 'error', :message => "Could not zip file #{arch.archive_file}: #{error}")
            end
        end
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
