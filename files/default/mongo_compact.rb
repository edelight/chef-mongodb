#!/opt/chef/embedded/bin/ruby
#
# run this script with no arguments and it will iterate over all mongo databases
# on localhost and compact every collection.  run it with -c to run it
# continuously from cron. run it with --help to see other options.
#

require 'mongo'
require 'optparse'
require 'daemons'

module ParseOps
  class Compact
    # Run compact on every collection in every database

    REPLICATION_WINDOW = 1800  # more than 30 minutes means we're behind

    SLEEP_INTERVAL = 300
    RECONNECT_INTERVAL = 120
    RECONNECT_RETRIES = 30

    def initialize()
      make_mongo_connection()
      @start_time = Time.now.utc
    end

    class MyDBCollections
      include Enumerable

      attr_accessor :connection

      def initialize(compacter, connection, force_master, db_names)
        @compacter = compacter
        @connection = connection
        @collection_names = []
        @database_names = db_names || Array.new(@connection.database_names)

        exit 0 if !force_master && connection.db.command({'isMaster'=>1})['ismaster']

        # NOTE - this map can take a while to build and can end up being quite large
        # for example it can be around 25MB on the parse replica set
        puts "#{Time.now.utc} preloading all collection names, this may take some time..."
        @db_collections = {}
        @database_names.each do |db_name|
          puts "#{Time.now.utc} preloading for #{db_name}"
          retry_count = 0
          begin
            db = @connection[db_name]
            @db_collections[db_name] = db.collection_names
          rescue Mongo::ConnectionFailure => err
            raise if (retry_count += 1) >= RECONNECT_RETRIES
            puts "Mongo connection failure: #{err.message}.  Reconnecting after #{RECONNECT_INTERVAL}s"
            sleep RECONNECT_INTERVAL
            retry
          end
        end
        puts "#{Time.now.utc} done preloading collection names"
      end

      def each
        while db_name = @database_names.first
          db = @connection[db_name]
          @collection_names = Array.new(@db_collections[db_name]) if @collection_names.empty?
          while collection_name = @collection_names.first
            yield [db, collection_name]
            @collection_names.shift
          end
          @database_names.shift
        end
      end
    end

    class MyFileCollections
      include Enumerable

      def initialize(connection, filename)
        @connection = connection
        @infile = open(filename)
        @behind = false
      end

      def each
        while line = @infile.gets
          db_name, collection_name = line.split(',')
          if db_name && collection_name
            db_name.strip!
            collection_name.strip!
            db = @connection[db_name]
            yield [db, collection_name]
          else
            puts "ERROR: invalid line in collections file: '#{line}'"
          end
        end
      end
    end

    def run(options = {})
      if options[:continuous]
        @pidfile = Daemons::PidFile.new(options[:rundir], File.basename($0), false)
        return if already_running?
        @pidfile.pid = Process.pid
        progress_file = File.join(options[:rundir], "progress.csv")
        options[:file] = progress_file unless options[:file] || !File.exists?(progress_file)
      end

      if options[:file]
        collections = MyFileCollections.new(@connection, options[:file])
      else
        collections = MyDBCollections.new(self, @connection, options[:force_master], options[:databases])
      end

      i = 0
      collections.each do |db, collection_name|
        while replication_behind? && !options[:ignore_replication]
          puts "replication behind, sleeping for #{SLEEP_INTERVAL}s"
          sleep SLEEP_INTERVAL
        end
        print "#{Time.now.utc} [collection #{i += 1}] "
        compact_collection(db, collection_name)
      end
      puts "done! time elapsed: #{Time.now.utc - @start_time}s. completed #{i} compactions"
    rescue Interrupt, StandardError => err
      progress_file ||= "/tmp/mongo_compact_remaining_#{Time.now.utc.to_s.tr(' ', '_')}.csv"
      puts "\n\nERROR: #{err.class}('#{err.message}') : \n#{err.backtrace.join("\n")}" unless err.class == Interrupt
      puts "\ndumping to file '#{progress_file}'..."
      outfile = open(progress_file, "w")
      remaining = 0
      collections.each do |db, collection_name|
        outfile.puts "#{db.name}, #{collection_name}"
        remaining += 1
      end
      outfile.close()
      puts "done!  completed #{i} compactions, #{remaining} remaining."
      continuous_flag = options[:continuous] ? " -c" : ""
      if options[:rundir] != "/var/run/mongo_compact/" || progress_file != "/var/run/mongo_compact/progress.csv"
        puts "to resume, run: #{$0}#{continuous_flag} -f '#{progress_file}'"
      else
        puts "to resume, run: #{$0}#{continuous_flag}"
      end
    else
      # if there's a progress file and we completed it uninterrupted, then clean it up
      File.unlink(progress_file) if progress_file && File.exists?(progress_file)
    ensure
      @pidfile.cleanup if @pidfile
    end

    def compact_collection(db, collection_name, retry_count=RECONNECT_RETRIES)
      print "db(#{db.name}).command({:compact => #{collection_name}}) => "
      db.command({:compact => collection_name})
      puts "success!"
    rescue Mongo::OperationFailure => err
      case err.error_code
      when 14027
        puts "ignoring system namespace in #{db.name}: #{collection_name}"
      when 13661
        puts "ignoring capped collection in #{db.name}: #{collection_name}"
      when 13660
        puts "ignoring dropped collection in #{db.name}: #{collection_name}"
      else
        puts "skipping #{db.name}: #{collection_name} -- errmsg: #{err.result['errmsg']}"
      end
    rescue Mongo::ConnectionFailure => err
      raise if (retry_count -= 1) <= 0
      puts "Mongo connection failure: #{err.message}.  Reconnecting after #{RECONNECT_INTERVAL}s"
      sleep RECONNECT_INTERVAL
      @connection = @compacter.make_mongo_connection()
      @collections.connection = @connection
      retry
    end

    def replication_behind?
      self_stats = @connection['admin'].command({ :replSetGetStatus => 1 })["members"].select { |member| member['self'] }[0]
      replication_timestamp = self_stats["optimeDate"]
      window = REPLICATION_WINDOW
      window /= 2 if @behind # wait until we're at least half caught up before resuming
      @behind = Time.now.utc - replication_timestamp > window
    rescue Mongo::OperationFailure => err
      # don't worry about it if replication isn't enabled on this host
      false
    end

    def make_mongo_connection()
      @connection = Mongo::Connection.new('localhost', 27017, {:slave_ok => true})
    end

    def already_running?
      @pidfile && @pidfile.exist? && @pidfile.pid != Process.pid
    end
  end  # class Compact
end  # module ParseOps

if __FILE__ == $0
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"

    options[:rundir] = "/var/run/mongo_compact/"
    opts.on("-f", "--file FILE", "take list of collections from FILE") { |filename| options[:file] = filename }
    opts.on("--[no-]replication-check", "enable/disable checking replication lag") { |flag| options[:ignore_replication] = !flag }
    opts.on("--force-master", "force the script to run on a master node for testing") { options[:force_master] = true }
    opts.on("-c", "--continuous", "enable continuous compaction mode") { options[:continuous] = true }
    opts.on("-r", "--rundir DIR", "save pid pid and collections in progress into DIR, only has effect when --continuous is specified.  defaults to #{options[:rundir]}") { |dir| options[:rundir] = dir }
    opts.on("-d", "--databases DBLIST", "only compact collections within DBLIST (comma separated), not used if --file is specified") { |dblist| options[:databases] = dblist.split(',') }
  end.parse!

  ParseOps::Compact.new.run options
end

