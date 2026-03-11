# bot.cr - Main bot class for Telecr
# Handles message routing, middleware, and bot lifecycle

require "./api/*"

module Telecr 
  module Core
    # Main bot class that users interact with
    class Bot
      # Core components
      getter client : Api::Client      # Handles Telegram API calls
      getter composer : Composer       # Manages middleware chain
      getter middleware : Middleware   # Middleware instance
      getter running : Bool             # Bot running state
      
      # Initialize a new bot with your Telegram token
      def initialize(token : String)
        @client = Api::Client.new(token)
        @composer = Composer.new
        @running : Bool = false
        # Store handlers for different update types
        @handlers = {
          "message" => [],
          "callback_query" => [],
          "inline_query" => [],
          "chat_member" => [],
          "poll" => [],
          "pre_checkout_query" => [],
          "shipping_query" => [],
          "poll_answer" => [],
          "chat_join_request" => [],
          "chat_boost" => [],
          "removed_chat_boost" => [],
          "message_reaction" => [],
          "message_reaction_count" => []
        } of String => Array(Handler)
        @offset = 0                       # For long polling
        @logger = Logger.new(STDOUT)      # Logging
        @error_handler = nil               # Custom error handler
      end 
      
      # Start bot in polling mode (runs in background)
      def start_polling 
        @running = true 
        spawn do 
          poll_loop
        end 
      end 
      
      # TODO: Implement webhook support
      def start_webhook(path : String)
      end 
      
      # Gracefully stop the bot
      def shutdown
        return unless @running 
        @logger.info "shutting down bot"
        @running = false 
        sleep 0.1
      end 
      
      # Register a command handler (e.g. /start)
      def command(name : String, &block)
        pattern = %r{^/#{Regex.escape(name)}(?:@\w+)?(?:\s+(.+))?$}i
        on(:message, text = pattern) do |ctx|
          ctx.match = ctx.message.text.match(pattern)
          ctx.state[:command_args] = ctx.match[1] if ctx.match
          block.call(ctx)
        end 
      end 
      
      # Register a handler for messages matching a pattern
      def hears(pattern, &block)
        on(:message, text = pattern) do |ctx|
          ctx.match = ctx.message.text.match(pattern)
          block.call(ctx)
        end 
      end 
      
      # Generic handler registration
      def on(type, filters = {} of String => Value, &block)
        @handlers[type] << {filters: filters, handler: block}
      end 
      
      # Handle contact sharing
      def contact(**options, &block)
        on(:message, contact: true) do |ctx|
          block.call(ctx)
        end
      end 
      
      # Handle poll answers
      def poll_answer(&block)
        on(:poll_answer) do |ctx|
          block.call(ctx)
        end 
      end 
      
      # Handle pre-checkout queries
      def pre_checkout_query(&block)
        on(:pre_checkout_query) do |ctx|
          block.call(ctx)
        end 
      end 
      
      # Handle shipping queries
      def shipping_query(&block) 
        on(:shipping_query) do |ctx| 
          block.call(ctx) 
        end 
      end 
      
      # Handle chat join requests
      def chat_join_request(&block)
        on(:chat_join_request) do |ctx|
          block.call(ctx)
        end
      end

      # Handle chat boosts
      def chat_boost(&block)
        on(:chat_boost) do |ctx|
          block.call(ctx)
        end
      end

      # Handle removed chat boosts
      def removed_chat_boost(&block)
        on(:removed_chat_boost) do |ctx|
          block.call(ctx)
        end
      end

      # Handle message reactions
      def message_reaction(&block)
        on(:message_reaction) do |ctx|
          block.call(ctx)
        end
      end

      # Handle message reaction counts
      def message_reaction_count(&block)
        on(:message_reaction_count) do |ctx|
          block.call(ctx)
        end
      end
      
      # Handle web app data
      def web_app_data(&block) 
        on(:message, web_app_data: true) do |ctx|
          block.call(ctx) 
        end 
      end 
      
      # Set bot profile photo
      def set_my_profile_photo(photo, **options)
        @client.call('setMyProfilePhoto', {
          photo: photo
        }.merge(options))
      end 

      # Remove bot profile photo
      def remove_my_profile_photo
        @client.call('removeMyProfilePhoto', {})
      end 

      # Get user's profile audios
      def get_user_profile_audios(user_id : String, **options)
        result = @client.call('getUserProfileAudios', {
          user_id: user_id
        }.merge(options))
        return nil unless result && result['audio']
        Types::UserProfileAudios.new(result)
      end

      # Create a forum topic
      def create_forum_topic(chat_id, name, **options)
        @client.call('createForumTopic', {
          chat_id: chat_id,
          name: name
        }.merge(options))
      end 

      # Handle location messages
      def location(&block)
        on(:message, location: true) do |ctx|
          block.call(ctx) 
        end 
      end 
      
      # Add middleware to the chain
      def use(middleware, *args, &block)
        @middleware << [middleware, args, block]
        self
      end
      
      # Set custom error handler
      def error(&block)
        @error_handler = block
      end
      
      # Set webhook with optional callback
      def set_webhook(url, **options, &callback)
        if callback
          @client.call!('setWebhook', { url: url }.merge(options), &callback)
        else
          @client.call('setWebhook', { url: url }.merge(options))
        end
      end

      # Delete webhook with optional callback
      def delete_webhook(&callback)
        if callback
          @client.call!('deleteWebhook', {}, &callback)
        else
          @client.call('deleteWebhook', {})
        end
      end

      # Get webhook info with optional callback
      def get_webhook_info(&callback)
        if callback
          @client.call!('getWebhookInfo', {}, &callback)
        else
          @client.call('getWebhookInfo', {})
        end
      end
      
      # Process raw update data (useful for webhooks)
      def process(update_data)
        update = Types::Update.new(update_data)
        process_update(update)
      end
      
      private

# Main polling loop that runs in background fiber
# Continuously fetches updates from Telegram
    def poll_loop
      while @running
       begin 
      # Fetch updates from Telegram
      updates = @client.get_updates(
        offset: @offset,
        timeout: 30,
        limit: 100
      )
      
      # Process any updates received
      if updates && updates.as_a.any?
        updates.as_a.each do |u_data|
          update = Types::Update.new(u_data.as_h)
          process_update(update)
        end
        
        # Update offset to acknowledge processed updates
        last_update = updates.as_a.last
        @offset = last_update["update_id"].as_i64 + 1
        @logger.debug("Poll offset now #{@offset}")
      end
    rescue error
      # Log error and continue polling
      @logger.error("Poll loop error: #{error.message}")
      sleep 1
    end
  end
end

# Process a single update from Telegram
# Routes to appropriate handlers through middleware chain
def process_update(update : Types::Update)
  # Log command usage for debugging
  if msg = update.message
    if text = msg.text
      user = msg.from
      cmd = text.split.first
      @logger.info("#{cmd} : #{user.try(&.username)}")
    end
  end
  
  # Create context for this update
    ctx = Context.new(update, self)
      
      begin 
 
    # Run middleware chain then dispatch to handlers
         run_middleware_chain(ctx) do |context|
            dispatch_to_handlers(context)
          end 
        rescue error 
          handle_errors(ctx, error)
        end 
      end
      
      def run_middleware_chain(ctx, &final)
        build = build_middleware_chain
        build.call(ctx, &final)
      end 
      
      def build_middleware_chain
        
        yield 
      end 
      
      
      def dispatch_to_handlers(ctx)
        update_type = detect_update_type(ctx.update)
        handlers = @handlers[update_type] || []
        
        handlers.each do |handler|
          if matches_filters?(ctx, handler[:filters])
            handler[:handler].call(ctx)
            break
          end
        end
      end
      
      def detect_update_type(update)
        return :message if update.message
        return :callback_query if update.callback_query
        return :inline_query if update.inline_query
        return :chat_member if update.chat_member
        return :poll if update.poll
        return :pre_checkout_query if update.pre_checkout_query
        return :shipping_query if update.shipping_query
        return :poll_answer if update.poll_answer
        return :chat_join_request if update.chat_join_request
        return :chat_boost if update.chat_boost
        return :removed_chat_boost if update.removed_chat_boost 
        return :message_reaction if update.message_reaction
        return :message_reaction_count if update.message_reaction_count 
        :unknown
      end
      
      def matches_filters?(ctx, filters)
        return true if filters.empty?
        
        filters.all? do |key, value|
          case key
          when :text
            matches_text_filter(ctx, value)
          when :chat_type
            matches_chat_type_filter(ctx, value)
          when :command
            matches_command_filter(ctx, value)
          when :location 
            ctx.message&.location != nil 
          when :contact 
            ctx.message&.contact != nil 
          when :web_app_data 
            ctx.message&.web_app_data != nil
          else 
            if ctx.update.respond_to?(key)
              ctx.update.send(key) == value
            else 
              false 
            end 
          end
        end 
      end
      
      def matches_text_filter(ctx, pattern)
        return false unless ctx.message&.text
        
        if pattern.is_a?(Regexp)
          ctx.message.text.match?(pattern)
        else
          ctx.message.text.include?(pattern.to_s)
        end
      end
      
      def matches_chat_type_filter(ctx, type)
        return false unless ctx.chat
        ctx.chat.type == type.to_s
      end
      
      def matches_command_filter(ctx, command_name)
        return false unless ctx.message&.command?
        ctx.message.command_name == command_name.to_s
      end
      
      def handle_error(error, ctx = nil)
        if @error_handler
          @error_handler.call(error, ctx)
        else
          @logger.error("❌ Unhandled error: #{error.class}: #{error.message}")
          if ctx
            @logger.error("Context - User: #{ctx.from&.id}, Chat: #{ctx.chat&.id}")
          end
        end
      end
    end
  end
end