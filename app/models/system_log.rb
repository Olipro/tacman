class SystemLog < ActiveRecord::Base


    validates_format_of :level, :with => /(info|warn|error)/, :message => "must be either 'info', 'warn', or 'error'"
    validates_presence_of :owning_manager_id
    validates_presence_of :message
    after_create :create_on_remote_managers!



    def SystemLog.log_fields_header
        ["Timestamp", "Level", "Username", "Message"]
    end



    def log_fields
        [self.created_at.strftime("%Y-%m-%d %H:%M:%S %Z"), self.level, self.username, self.message]
    end

private

    def create_on_remote_managers!
        Manager.replicate_to_master('create', self.to_xml(:skip_instruct => true, :except => [:owning_manager_id, :manager_id]) )
    end

end
