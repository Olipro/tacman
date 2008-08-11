class CreateUsers < ActiveRecord::Migration
  def self.up

    # password histories
    create_table :password_histories do |t|
      t.integer :user_id
      t.boolean :is_enable, :default => false
      t.string :password_hash
      t.date :expires_on

      t.timestamps
    end

    # departments
    create_table :departments do |t|
      t.string :name
      t.timestamps
    end

    # last logins
    create_table :user_last_logins do |t|
      t.integer :user_id
      t.datetime :last_login_at
    end

    # users
    create_table :users do |t|
      t.integer :department_id
      t.boolean :allow_web_login, :default => true
      t.boolean :disable_aaa_log_import, :default => false
      t.boolean :disabled, :default => false
      t.string :email
      t.integer :enable_password_lifespan
      t.integer :login_password_lifespan
      t.text :notes
      t.string :real_name
      t.string :role, :default => 'user'
      t.string :salt
      t.string :username
      t.integer :password_history_length

      t.timestamps
    end


    # admin user
    user = User.new(:username => 'admin', :login_password_lifespan => 0, :enable_password_lifespan => 0)
    user.admin!
    user.save!
    user.set_password('password','password',false)
    user.set_password('password','password',true)
  end

  def self.down
    drop_table :password_histories
    drop_table :departments
    drop_table :user_last_logins
    drop_table :users
  end

end
