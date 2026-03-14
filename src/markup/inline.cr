# markup/inline.cr - Inline keyboard markup builders for Telecr

module Telecr
  module Markup
    # ===== Inline Keyboard Helpers =====
    
    module InlineButtons
      # Create a callback button
      def callback(text, data, style : String? = nil, icon_custom_emoji_id : String? = nil)
        result = {} of String => JSON::Any
        result["text"] = JSON::Any.new(text)
        result["callback_data"] = JSON::Any.new(data)
        if style
          result["style"] = JSON::Any.new(style)
        end
        if icon_custom_emoji_id
          result["icon_custom_emoji_id"] = JSON::Any.new(icon_custom_emoji_id)
        end
        result
      end
      
      # Create a URL button
      def url(text, url, style : String? = nil, icon_custom_emoji_id : String? = nil)
        result = {} of String => JSON::Any
        result["text"] = JSON::Any.new(text)
        result["url"] = JSON::Any.new(url)
        if style
          result["style"] = JSON::Any.new(style)
        end
        if icon_custom_emoji_id
          result["icon_custom_emoji_id"] = JSON::Any.new(icon_custom_emoji_id)
        end
        result
      end
      
      # Create switch inline button
      def switch_inline(text, query : String? = nil, style : String? = nil, icon_custom_emoji_id : String? = nil)
        result = {} of String => JSON::Any
        result["text"] = JSON::Any.new(text)
        if query
          result["switch_inline_query"] = JSON::Any.new(query)
        else
          result["switch_inline_query"] = JSON::Any.new("")
        end
        if style
          result["style"] = JSON::Any.new(style)
        end
        if icon_custom_emoji_id
          result["icon_custom_emoji_id"] = JSON::Any.new(icon_custom_emoji_id)
        end
        result
      end
      
      # Create switch inline current chat button
      def switch_inline_current_chat(text, query : String? = nil, style : String? = nil, icon_custom_emoji_id : String? = nil)
        result = {} of String => JSON::Any
        result["text"] = JSON::Any.new(text)
        if query
          result["switch_inline_query_current_chat"] = JSON::Any.new(query)
        else
          result["switch_inline_query_current_chat"] = JSON::Any.new("")
        end
        if style
          result["style"] = JSON::Any.new(style)
        end
        if icon_custom_emoji_id
          result["icon_custom_emoji_id"] = JSON::Any.new(icon_custom_emoji_id)
        end
        result
      end
      
      # Create game button
      def callback_game(text, game_short_name, style : String? = nil, icon_custom_emoji_id : String? = nil)
        result = {} of String => JSON::Any
        result["text"] = JSON::Any.new(text)
        result["callback_game"] = JSON::Any.new({"game_short_name" => game_short_name})
        if style
          result["style"] = JSON::Any.new(style)
        end
        if icon_custom_emoji_id
          result["icon_custom_emoji_id"] = JSON::Any.new(icon_custom_emoji_id)
        end
        result
      end
      
      # Create pay button
      def pay(text, style : String? = nil, icon_custom_emoji_id : String? = nil)
        result = {} of String => JSON::Any
        result["text"] = JSON::Any.new(text)
        result["pay"] = JSON::Any.new(true)
        if style
          result["style"] = JSON::Any.new(style)
        end
        if icon_custom_emoji_id
          result["icon_custom_emoji_id"] = JSON::Any.new(icon_custom_emoji_id)
        end
        result
      end
      
      # Create web app button
      def web_app(text, url : String? = nil, style : String? = nil, icon_custom_emoji_id : String? = nil)
        result = {} of String => JSON::Any
        result["text"] = JSON::Any.new(text)
        if url
          result["web_app"] = JSON::Any.new({"url" => url})
        end
        if style
          result["style"] = JSON::Any.new(style)
        end
        if icon_custom_emoji_id
          result["icon_custom_emoji_id"] = JSON::Any.new(icon_custom_emoji_id)
        end
        result
      end
      
      # Create login button
      def login(text, url, style : String? = nil, icon_custom_emoji_id : String? = nil, **options)
        result = {} of String => JSON::Any
        result["text"] = JSON::Any.new(text)
        
        login_url = {"url" => url}
        options.each do |k, v|
          login_url[k.to_s] = v.to_s
        end
        result["login_url"] = JSON::Any.new(login_url)
        
        if style
          result["style"] = JSON::Any.new(style)
        end
        if icon_custom_emoji_id
          result["icon_custom_emoji_id"] = JSON::Any.new(icon_custom_emoji_id)
        end
        result
      end
    end
    
    # Builder class for inline keyboards
    class InlineBuilder
      include InlineButtons
      
      def initialize
        @rows = [] of Array(Hash(String, JSON::Any))
      end
      
      # Add a row of buttons
      def row(*buttons)
        converted = buttons.to_a.map do |btn|
          btn
        end
        @rows << converted
        self
      end
      
      # Build the final keyboard
      def build
        InlineKeyboard.new(@rows)
      end
    end
    
    # Inline keyboard representation
    class InlineKeyboard
      getter rows : Array(Array(Hash(String, JSON::Any)))
      
      def initialize(@rows)
      end
      
      # Convert to hash for Telegram API
      def to_h
        result = {} of String => JSON::Any
        result["inline_keyboard"] = JSON::Any.new(@rows.map do |row|
          JSON::Any.new(row.map do |btn|
            JSON::Any.new(btn)
          end)
        end)
        result
      end
      
      # Convert to JSON
      def to_json(*args)
        to_h.to_json(*args)
      end
    end
    
    # Factory method for creating inline keyboards
    def self.inline(&block : InlineBuilder ->)
      builder = InlineBuilder.new
      block.call(builder)
      builder.build
    end
  end
end