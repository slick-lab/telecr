# markup/inline.cr - Inline keyboard markup builders for Telecr
require "json"

module Telecr
  module Markup
    # InlineButtons provides helper methods to generate button hashes.
    # Updated to support custom emoji icons and styles (API 9.6).
    module InlineButtons
      private def base_button(text : String, style : String? = nil, emoji_id : String? = nil)
        btn = {"text" => JSON::Any.new(text)}
        btn["style"] = JSON::Any.new(style) if style
        btn["icon_custom_emoji_id"] = JSON::Any.new(emoji_id) if emoji_id
        btn
      end

      def callback(text : String, data : String, style : String? = nil, emoji_id : String? = nil)
        base_button(text, style, emoji_id).tap { |b| b["callback_data"] = JSON::Any.new(data) }
      end

      def url(text : String, url : String, style : String? = nil, emoji_id : String? = nil)
        base_button(text, style, emoji_id).tap { |b| b["url"] = JSON::Any.new(url) }
      end

      def web_app(text : String, url : String, style : String? = nil, emoji_id : String? = nil)
        base_button(text, style, emoji_id).tap do |b|
          b["web_app"] = JSON::Any.new({"url" => JSON::Any.new(url)})
        end
      end

      def switch_inline(text : String, query : String = "", current_chat : Bool = false, style : String? = nil, emoji_id : String? = nil)
        key = current_chat ? "switch_inline_query_current_chat" : "switch_inline_query"
        base_button(text, style, emoji_id).tap { |b| b[key] = JSON::Any.new(query) }
      end

      def pay(text : String, style : String? = nil, emoji_id : String? = nil)
        base_button(text, style, emoji_id).tap { |b| b["pay"] = JSON::Any.new(true) }
      end
    end

    # Builder class for creating keyboards using a DSL
    class InlineBuilder
      include InlineButtons

      def initialize
        @rows = [] of Array(Hash(String, JSON::Any))
      end

      # Adds a new row to the keyboard.
      # Usage: row(callback("Yes", "y"), callback("No", "n"))
      def row(*buttons)
        @rows << buttons.to_a
        self
      end

      # Helper for single-button rows
      def add(button)
        @rows << [button]
        self
      end

      def build : InlineKeyboard
        InlineKeyboard.new(@rows)
      end
    end

    # Representation of the InlineKeyboardMarkup
    class InlineKeyboard
      getter rows : Array(Array(Hash(String, JSON::Any)))

      def initialize(@rows)
      end

      # Formats the keyboard for the Telegram API
      def to_h
        {
          "inline_keyboard" => @rows.map do |row|
            row.map { |btn| btn }
          end,
        }
      end

      def to_json(json : JSON::Builder)
        to_h.to_json(json)
      end
    end

    # Factory method for the DSL
    def self.inline(& : InlineBuilder ->) : InlineKeyboard
      builder = InlineBuilder.new
      yield builder
      builder.build
    end
  end
end
