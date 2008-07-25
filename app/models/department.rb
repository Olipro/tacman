class Department < ActiveRecord::Base

    has_many :configurations, :dependent => :nullify, :order => :name
    has_many :users, :dependent => :nullify, :order => :username

end
