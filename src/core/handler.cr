module Telecr
  module Core
    # Value type for filters - updated for Crystal 1.15+ compatibility
    alias FilterValue = String | Int32 | Int64 | Bool | Regex | Symbol | Nil

    # Handler struct - optimized for fast matching
    struct Handler
      getter filters : Hash(String, FilterValue)
      getter proc : Context ->
      property call_count : Int32 = 0
      getter created_at : Time = Time.utc

      def initialize(@filters : Hash(String, FilterValue), @proc : Context ->)
      end

      def call(ctx : Context)
        @call_count += 1
        @proc.call(ctx)
      end

      # Performance: Returns true if all filters pass
      def matches?(ctx : Context) : Bool
        return true if @filters.empty?

        @filters.all? do |key, value|
          case key
          when "text"         then matches_text?(ctx, value)
          when "chat_type"    then matches_chat_type?(ctx, value)
          when "command"      then matches_command?(ctx, value)
          when "location"     then !ctx.message.try(&.location).nil?
          when "contact"      then !ctx.message.try(&.contact).nil?
          when "web_app_data" then !ctx.message.try(&.web_app_data).nil?
          when "business_id"  then ctx.business_connection_id == value
          else
            handle_dynamic_filter(ctx, key, value)
          end
        end
      end

      private def matches_text?(ctx, pattern) : Bool
        return false unless text = ctx.text
        case pattern
        when Regex  then text.match?(pattern)
        when String then text.includes?(pattern)
        else             false
        end
      end

      private def matches_chat_type?(ctx, type) : Bool
        ctx.chat.try(&.chat_type) == type.to_s
      end

      private def matches_command?(ctx, cmd_name) : Bool
        ctx.command? && ctx.command_name == cmd_name.to_s
      end

      def handle_dynamic_filter(ctx : Context, key : String, value : FilterValue) : Bool
        case key
        when "user_id"  then ctx.user_id == value
        when "chat_id"  then ctx.chat_id == value
        when "is_reply" then ctx.reply? == value
        else                 false
        end
      end
    end

    class HandlerCollection
      def initialize
        @handlers = {} of String => Array(Handler)
      end

      def add(type : String, filters : Hash(Symbol, FilterValue), proc : Context ->)
        # Convert Symbol keys to String for the Handler
        string_filters = {} of String => FilterValue
        filters.each { |k, v| string_filters[k.to_s] = v }

        @handlers[type] ||= [] of Handler
        @handlers[type] << Handler.new(string_filters, proc)
      end

      def find_match(ctx : Context) : Handler?
        type = ctx.update_type.to_s # Uses the symbol from Types::Update

        @handlers[type]?.try &.each do |handler|
          return handler if handler.matches?(ctx)
        end

        nil
      end

      def stats
        @handlers.transform_values do |handlers|
          {
            "count"       => handlers.size,
            "total_calls" => handlers.sum(&.call_count),
          }
        end
      end
    end
  end
end
