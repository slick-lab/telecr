# composer.cr - Middleware chain executor for Telecr
# Handles running middleware in order and passing control to next

module Telecr
  module Core
    # Composer runs a chain of middleware and finally executes a handler
    #
    # Middleware are added via #use and executed in the order they were added.
    # Each middleware receives a context and a "next" function to call.
    # Middleware can:
    # - Modify the context before passing to next
    # - Perform actions after next returns
    # - Stop the chain by not calling next
    class Composer
      # Initialize with empty middleware stack
      def initialize
        @middleware = [] of Middleware
      end
      
      # Add middleware to the chain
      #
      # @param middleware [Middleware] The middleware instance to add
      # @return [self] For method chaining
      def use(middleware : Middleware)
        @middleware << middleware
        self
      end
      
      # Run the middleware chain and final handler
      #
      # @param ctx [Context] The context to pass through the chain
      # @param final [Proc(Context ->)] The final handler to execute
      # @return [Any] The result from the chain/handler
      def run(ctx : Context, &final : Context ->)
        # If no middleware, just run final handler
        return final.call(ctx) if @middleware.empty?
        
        # Build and execute the chain
        chain = build_chain(final)
        chain.call(ctx)
      end
      
      # Check if any middleware is registered
      def empty? : Bool
        @middleware.empty?
      end
      
      # Get number of registered middleware
      def size : Int32
        @middleware.size
      end
      
      # Clear all middleware
      def clear
        @middleware.clear
      end
      
     
      
      # Build the middleware chain by wrapping each layer
      #
      # This creates a callable object that runs middleware in reverse order.
      # The last middleware added runs closest to the final handler.
      #
      # @param final [Proc(Context ->)] The final handler
      # @return [Proc(Context ->)] The complete chain
      private def build_chain(final : Context ->)
        # Start with the final handler
        chain = final
        
        # Wrap each middleware around the chain (from last to first)
        @middleware.reverse_each do |middleware|
          # Capture current chain in a closure
          current = chain
          
          # Create new wrapper that runs this middleware then continues
          chain = ->(ctx : Context) {
            # Call middleware with context and next function
            middleware.call(ctx, current)
          }
        end
        
        chain
      end
    end
    
    # Base class for all middleware
    #
    # All middleware must inherit from this class and implement #call
    abstract class Middleware
      # Execute this middleware
      #
      # @param ctx [Context] The context to process
      # @param next_mw [Proc(Context ->)] The next middleware in chain
      # @return [Any] The result from the rest of the chain
      abstract def call(ctx : Context, next_mw : Context ->)
    end
  end
end