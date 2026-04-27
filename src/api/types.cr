require "json"

module Telecr
  module Types
    # Base class leveraging JSON::Serializable for performance
    abstract class BaseType
      include JSON::Serializable
      include JSON::Serializable::Unmapped # Keeps extra fields in @_unmapped hash if needed

      # Maintains compatibility for debugging
      def to_h : Hash(String, JSON::Any)
        JSON.parse(self.to_json).as_h
      end

      def inspect(io : IO) : Nil
        io << "#<" << self.class.name << " " << self.to_json << ">"
      end
    end

    class User < BaseType
      property id : Int64
      property is_bot : Bool
      property first_name : String
      property last_name : String?
      property username : String?
      property language_code : String?
      property is_premium : Bool?
      property added_to_attachment_menu : Bool?

      # Existing helper functionality
      def full_name : String
        [first_name, last_name].compact.join(" ")
      end

      def mention : String
        if user_name = username
          "@#{user_name}"
        else
          first_name
        end
      end

      def to_s(io : IO) : Nil
        io << full_name
      end
    end

    class Chat < BaseType
      property id : Int64

      @[JSON::Field(key: "type")]
      property chat_type : String

      property title : String?
      property username : String?
      property first_name : String?
      property last_name : String?
      property is_forum : Bool?

      def private? : Bool
        chat_type == "private"
      end

      def group? : Bool
        chat_type == "group"
      end

      def supergroup? : Bool
        chat_type == "supergroup"
      end

      def channel? : Bool
        chat_type == "channel"
      end

      def to_s(io : IO) : Nil
        io << (title || username || "Chat ##{id}")
      end
    end

    class MessageEntity < BaseType
      @[JSON::Field(key: "type")]
      property entity_type : String
      property offset : Int32
      property length : Int32
      property url : String?
      property user : User?
      property language : String?
      property custom_emoji_id : String?
    end

    class Message < BaseType
      property message_id : Int64
      property message_thread_id : Int32?
      property from : User?
      property sender_chat : Chat?
      property date : Int64
      property chat : Chat
      property text : String?
      property entities : Array(MessageEntity)?
      property caption : String?
      property caption_entities : Array(MessageEntity)?
      property reply_to_message : Message?
      property via_bot : User?

      # API 9.5/9.6 Additions
      property is_topic_message : Bool?
      property managed_bot_created : ManagedBotCreated?

      # Media fields
      property audio : JSON::Any?
      property document : JSON::Any?
      property photo : Array(JSON::Any)?
      property sticker : JSON::Any?
      property video : JSON::Any?
      property voice : JSON::Any?
      property video_note : JSON::Any?

      def time : Time
        Time.unix(date)
      end

      def command? : Bool
        return false unless (txt = text) && (ents = entities)
        ents.any? { |e| e.entity_type == "bot_command" }
      end

      def command_name : String?
        return nil unless command? && (txt = text) && (ents = entities)
        cmd_ent = ents.find { |e| e.entity_type == "bot_command" }
        return nil unless cmd_ent

        cmd = txt[cmd_ent.offset, cmd_ent.length]
        cmd.lstrip('/').split('@').first
      end

      def command_args : String?
        return nil unless command? && (txt = text) && (ents = entities)
        cmd_ent = ents.find { |e| e.entity_type == "bot_command" }
        return nil unless cmd_ent

        args_start = cmd_ent.offset + cmd_ent.length
        return nil if args_start >= txt.size
        txt[args_start..-1].strip
      end

      def reply? : Bool
        !reply_to_message.nil?
      end

      def has_media? : Bool
        !!(audio || document || photo || video || voice || video_note || sticker)
      end
    end

    class CallbackQuery < BaseType
      property id : String
      property from : User
      property message : Message?
      property inline_message_id : String?
      property chat_instance : String
      property data : String?
      property game_short_name : String?

      def from_user? : Bool
        true
      end # Always has a 'from'
      def message? : Bool
        !message.nil?
      end

      def inline_message? : Bool
        !inline_message_id.nil?
      end
    end

    class PollOption < BaseType
      property text : String
      property voter_count : Int32
      property persistent_id : String? # API 9.6
    end

    class Poll < BaseType
      property id : String
      property question : String
      property options : Array(PollOption)
      property total_voter_count : Int32
      property is_closed : Bool
      property is_anonymous : Bool
      property type : String
      property allows_multiple_answers : Bool
      property correct_option_id : Int32?
      property explanation : String?
      property allows_revoting : Bool? # API 9.6
      property description : String?   # API 9.6
    end

    # Root Update Object
    class Update < BaseType
      property update_id : Int64
      property message : Message?
      property edited_message : Message?
      property channel_post : Message?
      property edited_channel_post : Message?
      property inline_query : JSON::Any?
      property chosen_inline_result : JSON::Any?
      property callback_query : CallbackQuery?
      property shipping_query : JSON::Any?
      property pre_checkout_query : JSON::Any?
      property poll : Poll?
      property poll_answer : JSON::Any?
      property my_chat_member : JSON::Any?
      property chat_member : JSON::Any?
      property chat_join_request : JSON::Any?

      # API 9.6 addition
      property managed_bot : ManagedBotUpdated?

      def update_type : Symbol
        return :message if message
        return :edited_message if edited_message
        return :callback_query if callback_query
        return :channel_post if channel_post
        return :managed_bot if managed_bot
        # ... add others as needed
        :unknown
      end

      def from : User?
        message.try(&.from) ||
          callback_query.try(&.from) ||
          edited_message.try(&.from)
      end
    end

    # Supporting Classes for 9.6
    class ManagedBotCreated < BaseType; end

    class ManagedBotUpdated < BaseType; end
  end
end
