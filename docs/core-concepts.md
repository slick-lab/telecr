# Core Concepts

Understanding the fundamental concepts of Telecr will help you build better bots.

## Bot Instance

The `Telecr::Core::Bot` is the main entry point for your bot. It manages:

- Connection to Telegram API
- Handler registration
- Middleware chain
- Polling or webhook mode

```crystal
bot = Telecr.new("TOKEN")
```

## Context

Every update from Telegram is wrapped in a `Context` object that provides:

- Access to the raw update data
- Helper methods for responding
- State management
- User and chat information

```crystal
bot.command("info") do |ctx|
  user = ctx.from
  chat = ctx.chat
  ctx.reply("User: #{user.full_name}, Chat: #{chat.title}")
end
```

## Updates and Handlers

Telegram sends updates for various events. Handlers determine how your bot responds:

- `command`: Bot commands (e.g., /start)
- `hears`: Pattern matching on message text
- `on`: Generic event handlers

## Middleware System

Middleware allows intercepting and modifying updates before they reach handlers:

```crystal
class LoggingMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    puts "Received update: #{ctx.update.update_id}"
    next_mw.call(ctx)
  end
end

bot.use(LoggingMiddleware.new)
```

## Update Types

Telecr handles all Telegram update types:

- Messages (text, media, commands)
- Callback queries (inline button presses)
- Inline queries
- Chat member updates
- Polls and poll answers
- And more...

## Error Handling

Use error handlers to catch and respond to exceptions:

```crystal
bot.error do |error, ctx|
  puts "Error: #{error.message}"
  ctx.try(&.reply("Something went wrong!"))
end
```

## Threading and Concurrency

- Polling runs in a background fiber
- Webhook requests are handled concurrently
- Middleware and handlers should be thread-safe
- Use `spawn` for background tasks

## State Management

Context provides several state mechanisms:

- `ctx.state`: Per-request state (Hash(Symbol, JSON::Any))
- `ctx.session`: Persistent user sessions (requires Session middleware)
- Instance variables on the bot or middleware

## Type Safety

Telecr uses Crystal's type system extensively:

- All Telegram API types are strongly typed
- JSON parsing is validated at compile time
- Method signatures prevent common errors

## Performance Considerations

- Updates are processed asynchronously
- Memory usage scales with concurrent users
- Database sessions require careful management
- Rate limiting prevents API abuse

## Edge Cases

### Missing User Information

Some updates (like channel posts) don't have a `from` user:

```crystal
bot.on(:channel_post) do |ctx|
  if user = ctx.from
    # Handle user messages
  else
    # Handle anonymous posts
  end
end
```

### Large Updates

Handle large messages or media appropriately:

```crystal
bot.on(:message) do |ctx|
  if ctx.text && ctx.text.size > 4096
    ctx.reply("Message too long!")
    next
  end
  # Process message
end
```

### Concurrent Updates

Updates may arrive out of order. Use `update_id` for sequencing if needed.

### Bot Permissions

Ensure your bot has necessary permissions for actions like:
- Sending messages
- Managing chats
- Handling payments
- etc.

### Rate Limits

Telegram has rate limits. Use the RateLimit middleware to prevent hitting them.