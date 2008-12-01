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

    def hits(recent_only=true)
        set_start_time if (recent_only)
        AaaLog.count_by_sql("SELECT COUNT(*) FROM aaa_logs WHERE #{self.search_criteria}")
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
        matrix = {'Authentication' => {}, 'Authorization' => {}, 'Accounting' => {}}
        user_len = 4
        client_len = 6
        rem_len = 11
        stat_len = 6
        cmd_len = 7
        AaaLog.find(:all, :conditions => self.search_criteria).each do |l|
            if (l.client_name.blank?)
                client = l.client
            else
                client = l.client_name
            end
            l.rem_addr = '' if (l.rem_addr.blank?)
            l.command = '' if (l.msg_type == 'Authentication' || l.command.blank?)
            l.message = '' if (l.message.blank?)
            user_len = l.user.length if (l.user.length > user_len)
            rem_len = l.rem_addr.length if (l.rem_addr.length > rem_len)
            stat_len = l.status.length if (l.status.length > stat_len)
            cmd_len = l.command.length if (l.command.length > cmd_len)
            client_len = client.length if (client.length > client_len)

            if ( matrix[l.msg_type].has_key?(l.status) )
                if ( matrix[l.msg_type][l.status].has_key?(client) )
                    if ( matrix[l.msg_type][l.status][client].has_key?(l.user) )
                        if ( matrix[l.msg_type][l.status][client][l.user].has_key?(l.rem_addr) )
                            if ( matrix[l.msg_type][l.status][client][l.user][l.rem_addr].has_key?(l.message) )
                                if ( matrix[l.msg_type][l.status][client][l.user][l.rem_addr][l.message].has_key?(l.command) )
                                    matrix[l.msg_type][l.status][client][l.user][l.rem_addr][l.message][l.command] += 1
                                else
                                    matrix[l.msg_type][l.status][client][l.user][l.rem_addr][l.message][l.command] = 1
                                end
                            else
                                matrix[l.msg_type][l.status][client][l.user][l.rem_addr][l.message] = {l.command => 1}
                            end
                        else
                            matrix[l.msg_type][l.status][client][l.user][l.rem_addr] = { l.message => {l.command => 1} }
                        end
                    else
                        matrix[l.msg_type][l.status][client][l.user] = { l.rem_addr => { l.message => {l.command => 1} } }
                    end
                else
                    matrix[l.msg_type][l.status][client] = { l.user => { l.rem_addr => { l.message => {l.command => 1} } } }
                end
            else
                matrix[l.msg_type][l.status] = { client => { l.user => { l.rem_addr => { l.message => {l.command => 1} } } } }
            end

        end

        col_lens = [user_len + 2, client_len + 2, rem_len + 2, stat_len + 2, cmd_len + 2]
        summary = ''
        summary << print_matrix(matrix, 'Authentication', col_lens)
        summary << print_matrix(matrix, 'Authorization', col_lens)
        summary << print_matrix(matrix, 'Accounting', col_lens)

        return(summary)
    end

private

    def print_matrix(matrix, msg_type, col_lens)
        summary = ''
        user_len, client_len, rem_len, stat_len, cmd_len = col_lens
        if (!matrix[msg_type].empty?)
            summary << "\n\n#{msg_type} summary:\n"
            if (msg_type == 'Authentication')
                summary << "  Hits     Status#{' ' * (stat_len - 6)}Client#{' ' * (client_len - 6)}User#{' ' * (user_len - 4)}Remote Addr#{' ' * (rem_len - 11)}Message\n"
                summary << "  ---------------#{'-' * (stat_len - 6)}------#{'-' * (client_len - 6)}----#{'-' * (user_len - 4)}-----------#{'-' * (rem_len - 11)}------------------------\n"
            else
                summary << "  Hits     Status#{' ' * (stat_len - 6)}Client#{' ' * (client_len - 6)}User#{' ' * (user_len - 4)}Remote Addr#{' ' * (rem_len - 11)}Command#{' ' * (cmd_len - 7)}Message\n"
                summary << "  ---------------#{'-' * (stat_len - 6)}------#{'-' * (client_len - 6)}----#{'-' * (user_len - 4)}-----------#{'-' * (rem_len - 11)}-------#{'-' * (cmd_len - 7)}------------------------\n"
            end

            matrix[msg_type].keys.sort.each do |stat|
                matrix[msg_type][stat].keys.sort.each do |client|
                    matrix[msg_type][stat][client].keys.sort.each do |user|
                        matrix[msg_type][stat][client][user].keys.sort.each do |rem|
                            matrix[msg_type][stat][client][user][rem].keys.sort.each do |msg|
                                matrix[msg_type][stat][client][user][rem][msg].keys.sort.each do |cmd|
                                    hits = matrix[msg_type][stat][client][user][rem][msg][cmd].to_s
                                    summary << "  " << hits << ' ' * (9 - hits.length)
                                    summary << stat << ' ' * (stat_len - stat.length)
                                    summary << client << ' ' * (client_len - client.length)
                                    summary << user << ' ' * (user_len - user.length)
                                    summary << rem << ' ' * (rem_len - rem.length)
                                    if (msg_type != 'Authentication')
                                        summary << cmd << ' ' * (cmd_len - cmd.length)
                                    end
                                    summary << msg << "\n"
                                end
                            end
                        end
                    end
                end
            end
        end
        return(summary)
    end

end
