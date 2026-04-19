# session/middleware.cr - Integrates session storage into the bot chain

module Telecr
  module Session
    # Session Middleware automatically loads and saves user data.
    # It injects the session hash into the Context for easy access.
    class Middleware < Core::Middleware
      getter store : MemoryStore

      def initialize(store : MemoryStore? = nil)
        @store = store || MemoryStore.new
      end 

      def call(ctx : Core::Context, next_mw : Core::Context ->)
        user_id = get_user_id(ctx)
        
        # If we can't identify the user (e.g. anonymous channel post), just move on
        return next_mw.call(ctx) unless user_id

        # Load session from store (returns Hash(String, JSON::Any))
        # We assume Context has a `session` property of type Hash(String, JSON::Any)
        ctx.session = @store.get(user_id).try(&.as_h) || {} of String => JSON::Any
        
        begin
          # Pass control to the next middleware/handler
          next_mw.call(ctx)
        ensure
          # Persist any changes made to ctx.session back to the store
          @store.set(user_id, JSON::Any.new(ctx.session))
        end
      end
      
      # Extract a unique identifier for the session key.
      # Default is the User ID, but could be modified to Chat ID for group-sessions.
      private def get_user_id(ctx) : String?
        ctx.from.try(&.id.to_s)
      end
    end
  end
end