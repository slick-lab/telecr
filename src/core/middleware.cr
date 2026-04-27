# core/middleware.cr - Base class for all middleware

module Telecr
  module Core
    # Abstract base class that all middleware must inherit from.
    #
    # Middleware allows you to intercept and process updates before they reach
    # your handlers. Common use cases include:
    # - Logging and Analytics
    # - Authentication and Authorization
    # - Session Management
    # - Rate Limiting
    abstract class Middleware
      # Execute the middleware logic.
      #
      # To continue the chain, call `next_mw.call(ctx)`.
      # To stop the execution (short-circuit), simply do not call `next_mw`.
      #
      # @param ctx [Context] The current context wrapping the Telegram Update.
      # @param next_mw [Proc(Context, Nil)] The next middleware or final handler in the chain.
      abstract def call(ctx : Context, next_mw : Context ->)
    end
  end
end
