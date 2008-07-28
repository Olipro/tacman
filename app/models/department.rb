class Department < ActiveRecord::Base

    has_many :configurations, :dependent => :nullify, :order => :name
    has_many :users, :dependent => :nullify, :order => :username

    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!

private

    def destroy_on_remote_managers!
        Manager.replicate_to_slaves('destroy', self.to_xml(:skip_instruct => true, :only => :id) )
    end

    def create_on_remote_managers!
        Manager.replicate_to_slaves('create', self.to_xml(:skip_instruct => true) )
    end

    def update_on_remote_managers!
        Manager.replicate_to_slaves('update', self.to_xml(:skip_instruct => true) )
    end

end
