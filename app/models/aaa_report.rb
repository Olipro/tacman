class AaaReport < ActiveRecord::Base
    attr_protected :configuration_id

    belongs_to :configuration

    validates_presence_of :configuration_id
    validates_presence_of :name
    validates_uniqueness_of :name, :scope => :configuration_id

    def end_time
        @end_time
    end

    def end_time=(time)
        @end_time = time
    end

    def search_criteria
        criteria = [ "configuration_id = #{self.configuration_id}" ]
        criteria.push("timestamp >= '#{self.start_time}'") if (!self.start_time.blank?)
        criteria.push("timestamp <= '#{self.end_time}'") if (!self.end_time.blank?)
        criteria.push("client regexp '#{self.client}'") if (!self.client.blank?)
        criteria.push("client_name regexp '#{self.client_name}'") if (!self.client_name.blank?)
        criteria.push("user regexp '#{self.user}'") if (!self.user.blank?)
        criteria.push("command regexp '#{self.command}'") if (!self.command.blank?)
        criteria.push("message regexp '#{self.message}'") if (!self.message.blank?)
        criteria.push("status regexp '#{self.status}'") if (!self.status.blank?)
        criteria.push("msg_type regexp '#{self.msg_type}'") if (!self.msg_type.blank?)

        return( criteria.join(" and ") )
    end

    def set_start_time
        @start_time = (Time.now - 86400).strftime("%Y-%m-%d %H:%M:%S")
    end

    def start_time
        @start_time
    end

    def start_time=(time)
        @start_time = time
    end

    def summarize
        self.set_start_time
        by_client = {}
        by_user = {}
        longest_user = 4
        longest_client = 15
        longest_rem = 15
        AaaLog.find(:all, :conditions => self.search_criteria).each do |l|
            host = l.client
            host << " (#{l.client_name})" if (!l.client_name.blank?)
            l.rem_addr = '-' if (l.rem_addr.blank?)
            longest_user = l.user.length if (l.user.length > longest_user)
            longest_client = host.length if (host.length > longest_client)
            longest_rem = l.rem_addr.length if (l.rem_addr.length > longest_rem)

            if ( by_client.has_key?(host) )
                by_client[host] += 1
            else
                by_client[host] = 1
            end


            if ( by_user.has_key?(l.user) )
                if( by_user[l.user].has_key?(l.rem_addr) )
                    if( by_user[l.user][l.rem_addr].has_key?(host) )
                        by_user[l.user][l.rem_addr][host] += 1
                    else
                        by_user[l.user][l.rem_addr][host] = 1
                    end
                else
                    by_user[l.user][l.rem_addr] = {host => 1}
                end
            else
                by_user[l.user] = { l.rem_addr => {host => 1} }
            end

        end

        summary = "Hits per target host:\n"
        summary << "    Target Host#{' ' * (longest_client - 9)}Hits\n"
        summary << "    -----------#{'-' * (longest_client - 9)}------------------\n"
        by_client.keys.sort.each {|host| summary << "    #{host}#{' ' * (longest_client - host.length + 2)}#{by_client[host]} hits\n"}
        summary << "\nAttempts per user:\n"
        summary << "    User#{' ' * (longest_user - 2)}Remote Addr#{' ' * (longest_rem - 9)}Target Host#{' ' * (longest_client - 9)}Hits\n"
        summary << "    ----#{'-' * (longest_user - 2)}-----------#{'-' * (longest_rem - 9)}-----------#{'-' * (longest_client - 9)}------------------\n"
        by_user.keys.sort.each do |user|
            by_user[user].keys.each do |rem|
                by_user[user][rem].each_pair do |host, hits|
                    summary << "    #{user}#{' ' * (longest_user - user.length + 2)}#{rem}#{' ' * (longest_rem - rem.length + 2)}#{host}#{' ' * (longest_client - host.length + 2)}#{hits} hits\n"
                end
            end
        end

        return(summary)
    end

end
