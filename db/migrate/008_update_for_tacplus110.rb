class UpdateForTacplus110 < ActiveRecord::Migration
  def self.up

   create_table :dynamic_avpairs do |t|
      t.integer :author_avpair_entry_id
      t.string :obj_type  # shell_command_av, network_av
      t.string :attr
      t.string :delimiter

      t.timestamps
    end

   create_table :dynamic_avpair_values do |t|
      t.integer :dynamic_avpair_id
      t.integer :network_object_group_id
      t.integer :shell_command_object_group_id

      t.timestamps
    end

    TacacsDaemon.find(:all).each do |t|
        dir = "/var/tacman/public/graphs/tacacs_daemons/#{t.serial}"
        begin
            FileUtils.mkdir(dir)
        rescue Exception => err
            puts("Error creating directory #{dir}}: #{err}")
        end
    end

  end

  def self.down
    drop_table :dynamic_avpair_values
    drop_table :dynamic_avpairs

    TacacsDaemon.find(:all).each do |t|
        dir = "/var/tacman/public/graphs/tacacs_daemons/#{t.serial}"
        begin
            FileUtils.remove_entry_secure(dir)
        rescue Exception => err
            puts("Error deleting directory #{dir}}: #{err}")
        end
    end

  end
end