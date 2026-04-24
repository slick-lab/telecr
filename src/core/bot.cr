# bot.cr - Main bot class for Telecr
require "../api/*"
require "json"
require "log"

module Telecr 
  module Core
    class Bot
      getter client : Telecr::Api::Client
      getter composer : Composer
      getter running : Bool = false
      getter webhook_server : Webhook::Server?
      getter webhook_path : String?
      
      # For long polling
      @offset : Int64 = 0
      @logger = Log.for("telecr.bot")
      @handlers = HandlerCollection.new
      @error_handler : Proc(Exception, Context?, Nil)? = nil

      def initialize(token : String)
        @client = Api::Client.new(token)
        @composer = Composer.new
      end 
      
      # Start bot in polling mode
      def start_polling 
        @running = true 
        @logger.info { "Telecr bot started in polling mode" }
        spawn do 
          poll_loop
        end 
      end 
      
      # Start bot in webhook mode
      def start_webhook(path : String = "/webhook", port : Int32? = nil)
        @webhook_path = path
        @webhook_server = Webhook::Server.new(self, port: port)
        @webhook_server.try(&.run)
        @webhook_server.try(&.set_webhook)
        @webhook_server
      end

      def set_webhook(url : String? = nil, secret_token : String? = nil)
        params = {} of String => String
        params["url"] = url if url
        params["secret_token"] = secret_token if secret_token
        @client.call("setWebhook", params)
      end

      # New for API 9.6: Managed Bot Handler
      def managed_bot(&block : Context ->)
        on(:managed_bot) do |ctx|
          block.call(ctx)
        end
      end

      # New for API 9.6: User Profile Audios
      def get_user_profile_audios(user_id : Int64, offset : Int32? = nil, limit : Int32? = nil)
        params = { "user_id" => user_id.to_s }
        params["offset"] = offset.to_s if offset
        params["limit"] = limit.to_s if limit
        
        result = @client.call("getUserProfileAudios", params)
        # Use from_json to convert the API result hash into the typed object
        Types::UserProfileAudios.from_json(result.to_json)
      end

      # Preserving existing Command Logic
      def command(name : String, &block : Context ->)
        pattern = %r{^/#{Regex.escape(name)}(?:@\w+)?(?:\s+(.+))?$}i
        on(:message) do |ctx|
          if (msg = ctx.message) && (txt = msg.text)
            if match_data = txt.match(pattern)
              ctx.match = match_data
              ctx.state[:command_args] = match_data[1]?
              block.call(ctx)
            end
          end
        end 
      end 

      def hears(pattern : Regex | String, &block : Context ->)
        on(:message) do |ctx|
          if (msg = ctx.message) && (txt = msg.text)
            if match_data = txt.match(pattern)
              ctx.match = match_data
              block.call(ctx)
            end
          end
        end 
      end 

      def on(type : Symbol, **filters, &block : Context ->)
        @handlers.add(type.to_s, filters, block)
      end 

      # Process raw data (JSON String or Hash-like)
      def process(data : String)
        update = Types::Update.from_json(data)
        process_update(update)
      end

      def process(data : Hash | JSON::Any)
        update = Types::Update.from_json(data.to_json)
        process_update(update)
      end

      private def poll_loop
        while @running
          begin 
            # Client returns JSON::Any array of updates
            raw_updates = @client.get_updates(offset: @offset, timeout: 30)
            
            if raw_updates && raw_updates.as_a?
              raw_updates.as_a.each do |u_data|
                # Convert each element to our typed Update object
                update = Types::Update.from_json(u_data.to_json)
                process_update(update)
                @offset = update.update_id + 1
              end
            end
          rescue ex : Exception
            @logger.error { "Poll loop error: #{ex.message}" }
            sleep 1
          end
        end
      end

      private def process_update(update : Types::Update)
        # Type-safe logging using properties
        if msg = update.message
          user_info = msg.from.try(&.username) || "unknown"
          @logger.debug { "Update ##{update.update_id} from @#{user_info}" }
        end
        
        ctx = Context.new(update, self)
        
        begin 
          run_middleware_chain(ctx) do |final_ctx|
            dispatch_to_handlers(final_ctx)
          end 
        rescue ex : Exception 
          handle_error(ex, ctx)
        end 
      end

      private def run_middleware_chain(ctx, &final : Context ->)
        @composer.run(ctx, &final)
      end 
      
      private def dispatch_to_handlers(ctx)
        if handler = @handlers.find_match(ctx)
          handler.call(ctx)
        end
      end 

      private def handle_error(ex, ctx)
        if handler = @error_handler
          handler.call(ex, ctx)
        else
          @logger.error { "Unhandled Error: #{ex.message}\n#{ex.backtrace.join("\n")}" }
        end 
      end

      # Standard bot methods...
      def shutdown
        @running = false
        stop_webhook
      end

      def stop_webhook
        @webhook_server.try(&.stop)
        @webhook_server = nil
      end
    end
  end
end