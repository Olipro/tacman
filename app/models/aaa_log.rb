class AaaLog < ActiveRecord::Base
    belongs_to :configuration

    validates_presence_of :configuration_id
    validates_presence_of :timestamp


    def AaaLog.log_fields_header
        ["Timestamp", "Level", "Type", "User", "Message", "Command", "Status", "Client", "Client Name",
         "Service", "Action", "Authentication Method", "Authentication Type",
         "Privilege Level", "Port", "Remote Address", "Flags", "TACACS Daemon"]
    end

    def AaaLog.short_log_fields_header
        ["Timestamp", "Type", "User", "Message", "Command", "Status", "Client", "Client Name"]
    end


    def log_fields
        [self.timestamp.strftime("%Y-%m-%d %H:%M:%S %Z"), self.level, self.msg_type, self.user, self.message,
         self.command, self.status, self.client, self.client_name,
         self.service, self.action, self.authen_method, self.authen_type,
         self.priv_lvl, self.port, self.rem_addr, self.flags, self.tacacs_daemon]
    end

    def short_log_fields
        [self.timestamp.strftime("%Y-%m-%d %H:%M:%S %Z"), self.msg_type, self.user, self.message, self.command,
         self.status, self.client, self.client_name]
    end

end
