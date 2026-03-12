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
      getter running : Bool             # Bot running state
      
      # Initialize a new bot with your Telegram token
      def initialize(token : String)
        @client = Api::Client.new(token)
        @composer = Composer.new
        @running : Bool = false
        # Store handlers for different update types
        @handlers = HandlerCollection.new

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
        on(:message, text: pattern) do |ctx|
          ctx.match = ctx.message.text.match(pattern)
          ctx.state[:command_args] = ctx.match[1] if ctx.match
          block.call(ctx)
        end 
      end 
      
      # Register a handler for messages matching a pattern
      def hears(pattern, &block)
        on(:message, text: pattern) do |ctx|
          ctx.match = ctx.message.text.match(pattern)
          block.call(ctx)
        end 
      end 
      
      # Generic handler registration
      def on(type, **filters, &block)
       @handlers.add(type.to_s, filters, block)
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
          handle_error(error, ctx)
        end 
      end
      
      def run_middleware_chain(ctx, &final)
      @composer.run(ctx, &final)
      end 
      
      def dispatch_to_handlers(ctx)
       if handler = @handlers.find_match(ctx)
       handler.call(ctx)
      end
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