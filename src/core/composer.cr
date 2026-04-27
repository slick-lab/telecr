# composer.cr - Middleware chain executor for Telecr
# Handles running middleware in order and passing control to next

module Telecr
  module Core
    # Composer runs a chain of middleware and finally executes a handler.
    # Updated to be more efficient with Crystal's Proc handling.
    class Composer
      @middleware = [] of Middleware

      def initialize
      end

      # Add middleware to the chain
      def use(middleware : Middleware)
        @middleware << middleware
        self
      end

      # Overload to allow adding middleware as a block for quicker development
      def use(&block : Context, (Context ->) ->)
        use(AdHocMiddleware.new(block))
      end

      # Run the middleware chain and final handler
      def run(ctx : Context, &final : Context ->)
        return final.call(ctx) if @middleware.empty?

        # Build the chain and execute
        build_chain(final).call(ctx)
      end

      def empty? : Bool
        @middleware.empty?
      end

      def size : Int32
        @middleware.size
      end

      def clear
        @middleware.clear
      end

      # Build the middleware chain by wrapping each layer.
      # This uses a recursive closure approach which is standard for Onion-style middleware.
      private def build_chain(final : Context ->) : (Context ->)
        @middleware.reverse_each.reduce(final) do |next_mw, current_mw|
          ->(ctx : Context) { current_mw.call(ctx, next_mw) }
        end
      end
    end

    # Base class for all middleware
    abstract class Middleware
      abstract def call(ctx : Context, next_mw : Context ->)
    end

    # Helper class to allow proc-based middleware
    private class AdHocMiddleware < Middleware
      def initialize(@proc : Context, (Context ->) ->)
      end

      def call(ctx : Context, next_mw : Context ->)
        @proc.call(ctx, next_mw)
      end
    end
  end
end
