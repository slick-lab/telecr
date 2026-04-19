# memory_store.cr - In-memory session store with TTL and disk backup
require "json"

module Telecr
  module Session
    # MemoryStore stores session data in RAM with expiration.
    # Updated for 2026 performance standards.
    class MemoryStore
      @store = {} of String => JSON::Any
      @ttls = {} of String => Time
      @last_cleanup = Time.utc
      @last_backup = Time.utc

      def initialize(
        @default_ttl : Int32 = 300,
        @cleanup_interval : Int32 = 300,
        @backup_path : String? = nil,
        @backup_interval : Int32 = 60
      )
        load_from_disk if @backup_path && File.exists?(@backup_path.not_nil!)
      end

      # Store a value with optional TTL
      def set(key, value : JSON::Any, ttl : Int32? = nil) : JSON::Any
        auto_cleanup
        key_s = key.to_s
        
        @store[key_s] = value
        @ttls[key_s] = Time.utc + (ttl || @default_ttl).seconds
        
        auto_backup
        value
      end

      # Retrieve a value by key
      def get(key) : JSON::Any?
        key_s = key.to_s
        return nil unless @store.has_key?(key_s)

        if expired?(key_s)
          delete(key_s)
          return nil
        end

        @store[key_s]
      end

      # Increment a numeric value (Atomic-lite for fibers)
      def increment(key, amount = 1, ttl = nil) : Int64
        key_s = key.to_s
        current = get(key_s)
        
        # Extract numeric value safely
        val = current.try(&.as_i64?) || current.try(&.as_s?.try(&.to_i64?)) || 0_i64
        new_val = val + amount
        
        set(key_s, JSON::Any.new(new_val), ttl)
        new_val
      end

      # Remove all expired entries (Safely)
      def cleanup
        now = Time.utc
        expired_keys = [] of String
        
        @ttls.each do |key, expires|
          expired_keys << key if now > expires
        end

        expired_keys.each do |key|
          @store.delete(key)
          @ttls.delete(key)
        end
        
        @last_cleanup = now
      end

      # Atomic backup to disk
      def backup!
        return unless path = @backup_path
        
        # Prepare serializable format
        data = {
          "store"     => @store,
          "ttls"      => @ttls.transform_values(&.to_unix),
          "timestamp" => Time.utc.to_unix
        }

        dir = File.dirname(path)
        Dir.mkdir_p(dir) unless Dir.exists?(dir)

        # Write to temp file then rename (prevents corruption during crashes)
        temp_path = "#{path}.tmp"
        File.open(temp_path, "w") { |f| data.to_json(f) }
        File.rename(temp_path, path)
        
        @last_backup = Time.utc
      end

      # Restore from disk with validation
      def restore!
        return unless (path = @backup_path) && File.exists?(path)
        
        begin
          raw_data = File.open(path) { |f| JSON.parse(f) }
          
          @store.clear
          @ttls.clear

          raw_data["store"].as_h.each { |k, v| @store[k] = v }
          raw_data["ttls"].as_h.each do |k, v| 
            @ttls[k] = Time.unix(v.as_i64)
          end
        rescue e : Exception
          Log.error { "Failed to restore session backup: #{e.message}" }
        end
      end

      private def expired?(key : String) : Bool
        @ttls[key]? ? (Time.utc > @ttls[key]) : false
      end

      private def auto_cleanup
        cleanup if (Time.utc - @last_cleanup).total_seconds > @cleanup_interval
      end

      private def auto_backup
        backup! if @backup_path && (Time.utc - @last_backup).total_seconds > @backup_interval
      end
    end
  end
end