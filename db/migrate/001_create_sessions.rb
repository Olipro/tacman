class CreateSessions < ActiveRecord::Migration
  def self.up
    create_table :sessions do |t|
      t.string :session_id, :null => false
      t.text :data
      t.timestamps
    end

    add_index :sessions, :session_id
    add_index :sessions, :updated_at

    begin
        prod = File.expand_path("#{RAILS_ROOT}/log/") + "/production.log"
        dev = File.expand_path("#{RAILS_ROOT}/log/") + "/development.log"
        tst = File.expand_path("#{RAILS_ROOT}/log/") + "/test.log"
        srv = File.expand_path("#{RAILS_ROOT}/log/") + "/server.log"
        FileUtils.touch(prod)
        FileUtils.touch(dev)
        FileUtils.touch(tst)
        FileUtils.touch(srv)
    rescue Exception => error
        puts "error erasing log files: #{error}"
    end
  end

  def self.down
    drop_table :sessions
    begin
    drop_table :bdrb_job_queues
    rescue
    end

    begin
        prod = File.expand_path("#{RAILS_ROOT}/log/") + "/production.log"
        dev = File.expand_path("#{RAILS_ROOT}/log/") + "/development.log"
        tst = File.expand_path("#{RAILS_ROOT}/log/") + "/test.log"
        srv = File.expand_path("#{RAILS_ROOT}/log/") + "/server.log"
        File.delete(prod) if ( File.exists?(prod) )
        File.delete(dev) if ( File.exists?(dev) )
        File.delete(tst) if ( File.exists?(tst) )
        File.delete(srv) if ( File.exists?(srv) )
        FileUtils.rm Dir.glob( File.expand_path("#{RAILS_ROOT}/log/backgroundrb*") )
    rescue Exception => error
        puts "error erasing log files: #{error}"
    end
  end
end
