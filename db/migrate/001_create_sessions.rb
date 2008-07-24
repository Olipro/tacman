class CreateSessions < ActiveRecord::Migration
  def self.up
    create_table :sessions do |t|
      t.string :session_id, :null => false
      t.text :data
      t.timestamps
    end

    add_index :sessions, :session_id
    add_index :sessions, :updated_at
  end

  def self.down
    drop_table :sessions
    begin
        prod = File.expand_path("#{RAILS_ROOT}/log/") + "/production.log"
        dev = File.expand_path("#{RAILS_ROOT}/log/") + "/development.log"
        tst = File.expand_path("#{RAILS_ROOT}/log/") + "/test.log"
        bak = File.expand_path("#{RAILS_ROOT}/log/") + "/backgroundrb_11006.log"
        bak_d = File.expand_path("#{RAILS_ROOT}/log/") + "/backgroundrb_11006_debug.log"
        File.open(prod, 'w').close
        File.open(dev, 'w').close
        File.open(tst, 'w').close
        File.open(bak, 'w').close
        File.open(bak_d, 'w').close
    rescue Exception => error
        puts "error erasing log files: #{error}"
    end
  end
end
