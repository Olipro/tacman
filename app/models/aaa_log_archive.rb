class AaaLogArchive < ActiveRecord::Base
    belongs_to :configuration

    validates_presence_of :configuration_id
    validates_presence_of :archive_file
    validates_uniqueness_of :archive_file
    validates_presence_of :archived_on

    before_validation :setup
    after_destroy :cleanup


private

    def cleanup
        begin
            File.delete(self.archive_file) if ( File.exists?(self.archive_file) )
        rescue Exception => err
            self.errors.add_to_base("Error removing files: #{err}")
        end
    end

    def setup
        self.archive_file = self.archive_file + ".txt"
        self.archived_on = Date.today if (!self.archived_on)
    end

end
