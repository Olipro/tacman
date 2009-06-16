class AddRrdtool < ActiveRecord::Migration
  def self.up
    FileUtils.mkdir( File.expand_path("#{RAILS_ROOT}/log/rrd") )
    FileUtils.mkdir( File.expand_path("#{RAILS_ROOT}/log/rrd/tacacs_daemons") )
    FileUtils.mkdir( File.expand_path("#{RAILS_ROOT}/public/graphs") )
    FileUtils.mkdir( File.expand_path("#{RAILS_ROOT}/public/graphs/tacacs_daemons") )

    add_column(:tacacs_daemons, :rrd_file, :string)
    add_column(:tacacs_daemons, :daily_graph, :string)
    add_column(:tacacs_daemons, :weekly_graph, :string)
    add_column(:tacacs_daemons, :monthly_graph, :string)
    add_column(:tacacs_daemons, :yearly_graph, :string)

    TacacsDaemon.find(:all).each do |td|
        file = File.expand_path("#{RAILS_ROOT}/log/rrd/tacacs_daemons") + "/#{td.serial}.rrd"
        args = "create #{file} --start #{Time.now.to_i} DS:connections:GAUGE:600:U:U " +
               "RRA:AVERAGE:0.5:1:288  RRA:AVERAGE:0.5:24:84  RRA:AVERAGE:0.5:288:797"
        `rrdtool #{args}`

        td.update_attributes(:rrd_file => file,
                             :daily_graph => File.expand_path("#{RAILS_ROOT}/public/graphs/tacacs_daemons/#{td.serial}-daily.jpg"),
                             :weekly_graph => File.expand_path("#{RAILS_ROOT}/public/graphs/tacacs_daemons/#{td.serial}-weekly.jpg"),
                             :monthly_graph => File.expand_path("#{RAILS_ROOT}/public/graphs/tacacs_daemons/#{td.serial}-monthly.jpg"),
                             :yearly_graph => File.expand_path("#{RAILS_ROOT}/public/graphs/tacacs_daemons/#{td.serial}-yearly.jpg"))
    end

  end

  def self.down
    remove_column(:tacacs_daemons, :rrd_file)
    remove_column(:tacacs_daemons, :daily_graph)
    remove_column(:tacacs_daemons, :weekly_graph)
    remove_column(:tacacs_daemons, :monthly_graph)
    remove_column(:tacacs_daemons, :yearly_graph)

    FileUtils.remove_entry_secure( File.expand_path("#{RAILS_ROOT}/log/rrd") )
    FileUtils.remove_entry_secure( File.expand_path("#{RAILS_ROOT}/public/graphs") )
  end
end