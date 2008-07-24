class ArchiverWorker < BackgrounDRb::MetaWorker
    set_worker_name :archiver_worker

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    # shoud be ran at midnight each day
    def daily_archive
        local_manager = Manager.local

        # archive logs
        if (!local_manager.slave?)
            last = SystemLogArchive.find(:first, :order => "archived_on desc")
            (last.archived_on..Date.today-1).each {|x| SystemLogArchive.archive}
        end

        # cleanup db and old archive files
        SystemLogArchive.cleanup_logs!
        SystemLogArchive.cleanup_archives!

        # cleanup db and old archive files
        Configuration.find(:all).each do |configuration|
            configuration.cleanup_logs!
            configuration.cleanup_archives!
        end
    end

end

