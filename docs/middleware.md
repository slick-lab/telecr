# Middleware

Middleware allows you to intercept and modify updates before they reach your handlers. It's perfect for cross-cutting concerns like logging, authentication, sessions, and rate limiting.

## How Middleware Works

Middleware forms a chain that processes updates in order:

```
Update → Middleware 1 → Middleware 2 → ... → Handlers → Response
```

Each middleware can:
- Modify the context
- Short-circuit the chain (stop processing)
- Pass control to the next middleware

## Using Built-in Middleware

### Session Middleware

Stores user-specific data across messages:

```crystal
require "telecr/session"

bot.use(Telecr::Session::Middleware.new)

bot.command("count") do |ctx|
  count = ctx.session["count"].as_i? || 0
  count += 1
  ctx.session["count"] = count
  ctx.reply("Count: #{count}")
end
```

### Rate Limiting Middleware

Prevents abuse by limiting request frequency:

```crystal
require "telecr/plugins/rate_limit"

bot.use(Telecr::Plugins::RateLimit.new(
  user: {max: 5, per: 10},   # 5 requests per 10 seconds per user
  chat: {max: 20, per: 60},  # 20 requests per minute per chat
  global: {max: 100, per: 1} # 100 requests per second globally
))
```

### File Upload Middleware

Handles file uploads with Shrine:

```crystal
require "telecr/plugins/upload"

shrine = Shrine.new
shrine.storage = Shrine::Storage::FileSystem.new("uploads")

bot.use(Telecr::Plugins::Upload.new(shrine: shrine))

bot.on(:message) do |ctx|
  if file = ctx.state[:uploaded_file]?
    ctx.reply("File saved: #{file.url}")
  end
end
```

## Creating Custom Middleware

Create a class that inherits from `Telecr::Core::Middleware`:

```crystal
class LoggingMiddleware < Telecr::Core::Middleware
  def call(ctx : Telecr::Core::Context, next_mw : Telecr::Core::Context ->)
    start_time = Time.monotonic

    puts "Processing update #{ctx.update.update_id} from #{ctx.from.try(&.username)}"

    # Call the next middleware/handler
    next_mw.call(ctx)

    duration = Time.monotonic - start_time
    puts "Processed in #{duration.total_milliseconds.round(2)}ms"
  end
end

bot.use(LoggingMiddleware.new)
```

## Middleware Order Matters

Middleware is executed in the order it's added:

```crystal
# Good order: logging first, then rate limiting, then sessions
bot.use(LoggingMiddleware.new)
bot.use(RateLimitMiddleware.new)
bot.use(SessionMiddleware.new)

# Bad order: sessions before rate limiting (wasted work)
bot.use(SessionMiddleware.new)
bot.use(RateLimitMiddleware.new)
```

## Short-Circuiting

Stop processing by not calling `next_mw.call(ctx)`:

```crystal
class AuthMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    unless authorized?(ctx)
      ctx.reply("Access denied!")
      return  # Don't call next_mw
    end

    next_mw.call(ctx)
  end
end
```

## Modifying Context

Middleware can modify the context before passing it along:

```crystal
class UserMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    # Add user info to state
    if user = ctx.from
      ctx.state[:user_id] = user.id
      ctx.state[:is_admin] = admin_user?(user.id)
    end

    next_mw.call(ctx)
  end
end
```

## Async Middleware

For I/O operations, use async patterns:

```crystal
class DatabaseMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    # Load user data asynchronously
    user_data = load_user_data(ctx.from.id)
    ctx.state[:user_data] = user_data

    next_mw.call(ctx)
  end
end
```

## Error Handling

Handle errors in middleware:

```crystal
class SafeMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    begin
      next_mw.call(ctx)
    rescue ex
      puts "Middleware error: #{ex.message}"
      # Continue processing or re-raise
    end
  end
end
```

## Middleware State

Middleware instances persist across requests:

```crystal
class CounterMiddleware < Telecr::Core::Middleware
  @count = 0

  def call(ctx, next_mw)
    @count += 1
    ctx.state[:request_count] = @count

    next_mw.call(ctx)
  end
end
```

## Built-in Middleware Reference

### Session::Middleware

- **Purpose**: Persistent user sessions
- **Options**: Custom store (defaults to MemoryStore)
- **State**: `ctx.session` - Hash(String, JSON::Any)

### Plugins::RateLimit

- **Purpose**: Rate limiting
- **Options**: user, chat, global limits
- **Behavior**: Blocks requests exceeding limits

### Plugins::Upload

- **Purpose**: File upload handling
- **Options**: Shrine instance, auto-download
- **State**: `ctx.state[:uploaded_file]` - Uploaded file info

## Performance Considerations

- Keep middleware fast
- Avoid blocking operations
- Use connection pooling for databases
- Cache expensive computations

## Testing Middleware

Test middleware in isolation:

```crystal
middleware = MyMiddleware.new
ctx = Telecr::Core::Context.new(update, bot)

called = false
middleware.call(ctx) do |final_ctx|
  called = true
  # Assertions here
end

assert called
```

## Common Patterns

### Authentication

```crystal
class AuthMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    return ctx.reply("Login required") unless logged_in?(ctx)

    next_mw.call(ctx)
  end
end
```

### Request Logging

```crystal
class RequestLogger < Telecr::Core::Middleware
  def call(ctx, next_mw)
    puts "[#{Time.utc}] #{ctx.update.update_type} from #{ctx.from.try(&.id)}"
    next_mw.call(ctx)
  end
end
```

### Context Enrichment

```crystal
class ContextEnricher < Telecr::Core::Middleware
  def call(ctx, next_mw)
    ctx.state[:timestamp] = Time.utc
    ctx.state[:user_agent] = "TelecrBot/1.0"

    next_mw.call(ctx)
  end
end
```

## Edge Cases

### Middleware Exceptions

If middleware raises an exception, it bubbles up to the error handler.

### Context Modification

Be careful not to overwrite important context data.

### Memory Leaks

Don't store large objects in middleware instance variables.

### Thread Safety

Middleware may be called concurrently in webhook mode.

### Initialization Order

Initialize middleware that depend on each other in the correct order.