class UserLastLogin < ActiveRecord::Base
    belongs_to :user


    def days_ago
        Date.today - self.last_login_at.to_date
    end

end
