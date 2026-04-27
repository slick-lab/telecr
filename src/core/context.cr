module Telecr
  module Core
    class Context
      # Core properties
      property update : Types::Update
      property bot : Bot
      # Shared state between middlewares - using JSON::Any for flexibility
      property state : Hash(Symbol, JSON::Any)
      # Match data from pattern matching (command/hears)
      property match : Regex::MatchData?
      # Session data for this user
      property session : Hash(String, JSON::Any)
      property typing_active : Bool = false

      def initialize(@update : Types::Update, @bot : Bot)
        @state = {} of Symbol => JSON::Any
        @session = {} of String => JSON::Any
        @match = nil
        @typing_active = false
      end

      # ===== Update Type Accessors =====

      def message : Types::Message?
        @update.message || @update.edited_message || @update.channel_post
      end

      def callback_query : Types::CallbackQuery?
        @update.callback_query
      end

      def inline_query : JSON::Any? # If you have a typed InlineQuery, swap this
        @update.inline_query
      end

      # API 9.6: Access managed bot updates
      def managed_bot : Types::ManagedBotUpdated?
        @update.managed_bot
      end

      # Get the user who sent this update
      def from : Types::User?
        @update.from # Uses the helper we added to Types::Update
      end

      # Get the chat where this update occurred
      def chat : Types::Chat?
        if msg = self.message
          msg.chat
        elsif cq = self.callback_query
          cq.message.try(&.chat)
        end
      end

      # API 9.6: Business connection ID for Enterprise bots
      def business_connection_id : String?
        if msg = self.message
          # Assuming business_connection_id is added to Types::Message
          # msg.business_connection_id
        end
      end

      def data : String?
        @update.callback_query.try(&.data)
      end

      # ===== Message Properties =====

      def message_id : Int64?
        self.message.try(&.message_id)
      end

      def text : String?
        self.message.try(&.text)
      end

      def command? : Bool
        self.message.try(&.command?) || false
      end

      def command_name : String?
        self.message.try(&.command_name)
      end

      def command_args : String?
        self.message.try(&.command_args)
      end

      def reply? : Bool
        self.message.try(&.reply?) || false
      end

      def replied_message : Types::Message?
        self.message.try(&.reply_to_message)
      end

      # ===== Response Methods =====

      # Send a text message to the current chat
      def reply(text : String, **options)
        if chat_obj = self.chat
          params = {"chat_id" => chat_obj.id, "text" => text}

          # Handle API 9.6 message threading
          if !options.has_key?(:message_thread_id) && (thread_id = self.message.try(&.message_thread_id))
            params["message_thread_id"] = thread_id
          end

          options.each { |k, v| params[k.to_s] = v }
          @bot.client.call("sendMessage", params)
        end
      end

      # API 9.6: Native streaming draft support
      def reply_draft(text : String, **options)
        if chat_obj = self.chat
          params = {"chat_id" => chat_obj.id, "text" => text}
          options.each { |k, v| params[k.to_s] = v }
          @bot.client.call("sendMessageDraft", params)
        end
      end

      def edit_text(text : String, **options)
        if (msg = self.message) && (chat_obj = self.chat)
          params = {
            "chat_id"    => chat_obj.id,
            "message_id" => msg.message_id,
            "text"       => text,
          }
          options.each { |k, v| params[k.to_s] = v }
          @bot.client.call("editMessageText", params)
        end
      end

      def answer(text : String? = nil, show_alert : Bool = false, **options)
        if cq = self.callback_query
          params = {"callback_query_id" => cq.id, "show_alert" => show_alert}
          params["text"] = text if text
          options.each { |k, v| params[k.to_s] = v }
          @bot.client.call("answerCallbackQuery", params)
        end
      end

      # ===== Media & Files =====

      def photo(photo, caption : String? = nil, **options)
        send_media("sendPhoto", "photo", photo, caption, **options)
      end

      def document(doc, caption : String? = nil, **options)
        send_media("sendDocument", "document", doc, caption, **options)
      end

      private def send_media(method : String, key : String, file, caption : String?, **options)
        return unless chat_obj = self.chat
        params = {"chat_id" => chat_obj.id}
        params["caption"] = caption if caption
        options.each { |k, v| params[k.to_s] = v }

        if file_object?(file)
          @bot.client.upload(method, params.merge({key => file}))
        else
          @bot.client.call(method, params.merge({key => file}))
        end
      end

      # ===== Long Running Actions =====

      def with_typing(&)
        @typing_active = true
        # Send typing every 4.5 seconds (Telegram times out at 5s)
        spawn do
          while @typing_active
            self.send_chat_action("typing")
            sleep 4.5
          end
        end

        begin
          yield
        ensure
          @typing_active = false
        end
      end

      def send_chat_action(action : String)
        if chat_obj = self.chat
          @bot.client.call("sendChatAction", {"chat_id" => chat_obj.id, "action" => action})
        end
      end

      # ===== Utils =====

      private def file_object?(obj) : Bool
        obj.is_a?(File) || obj.is_a?(IO)
      end

      def user_id : Int64?
        self.from.try(&.id)
      end

      def chat_id : Int64?
        self.chat.try(&.id)
      end
    end
  end
end
