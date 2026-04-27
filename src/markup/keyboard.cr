# markup/keyboard.cr - Reply keyboard markup builders for Telecr
require "json"

module Telecr
  module Markup
    # ReplyButtons provides methods for creating individual keyboard buttons.
    # Supports style and custom emoji icons introduced in API 9.x.
    module ReplyButtons
      private def base_button(text : String, style : String? = nil, emoji_id : String? = nil)
        btn = {"text" => JSON::Any.new(text)}
        btn["style"] = JSON::Any.new(style) if style
        btn["icon_custom_emoji_id"] = JSON::Any.new(emoji_id) if emoji_id
        btn
      end

      def text(content : String, style : String? = nil, emoji_id : String? = nil)
        base_button(content, style, emoji_id)
      end

      def request_contact(text : String, style : String? = nil, emoji_id : String? = nil)
        base_button(text, style, emoji_id).tap { |b| b["request_contact"] = JSON::Any.new(true) }
      end

      def request_location(text : String, style : String? = nil, emoji_id : String? = nil)
        base_button(text, style, emoji_id).tap { |b| b["request_location"] = JSON::Any.new(true) }
      end

      def request_poll(text : String, poll_type : String? = nil, style : String? = nil, emoji_id : String? = nil)
        base_button(text, style, emoji_id).tap do |b|
          poll_data = poll_type ? {"type" => JSON::Any.new(poll_type)} : {} of String => JSON::Any
          b["request_poll"] = JSON::Any.new(poll_data)
        end
      end

      def web_app(text : String, url : String, style : String? = nil, emoji_id : String? = nil)
        base_button(text, style, emoji_id).tap do |b|
          b["web_app"] = JSON::Any.new({"url" => JSON::Any.new(url)})
        end
      end
    end

    class ReplyBuilder
      include ReplyButtons

      def initialize
        @rows = [] of Array(Hash(String, JSON::Any))
        @options = {
          "resize_keyboard"   => JSON::Any.new(true),
          "one_time_keyboard" => JSON::Any.new(false),
          "selective"         => JSON::Any.new(false),
        }
      end

      def row(*buttons)
        @rows << buttons.to_a
        self
      end

      def resize(v = true)
        @options["resize_keyboard"] = JSON::Any.new(v); self
      end

      def one_time(v = true)
        @options["one_time_keyboard"] = JSON::Any.new(v); self
      end

      def selective(v = true)
        @options["selective"] = JSON::Any.new(v); self
      end

      def persistent(v = true)
        @options["is_persistent"] = JSON::Any.new(v); self
      end

      def placeholder(text : String)
        @options["input_field_placeholder"] = JSON::Any.new(text)
        self
      end

      def build : ReplyKeyboard
        ReplyKeyboard.new(@rows, @options)
      end
    end

    class ReplyKeyboard
      getter rows : Array(Array(Hash(String, JSON::Any)))
      getter options : Hash(String, JSON::Any)

      def initialize(@rows, @options)
      end

      def to_h
        res = @options.dup
        res["keyboard"] = JSON::Any.new(@rows.map do |row|
          JSON::Any.new(row.map { |btn| JSON::Any.new(btn) })
        end)
        res
      end

      def to_json(json : JSON::Builder)
        to_h.to_json(json)
      end
    end

    def self.keyboard(& : ReplyBuilder ->) : ReplyKeyboard
      builder = ReplyBuilder.new
      yield builder
      builder.build
    end
  end
end
