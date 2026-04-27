# Handlers

Handlers determine how your bot responds to different types of updates from Telegram.

## Command Handlers

Command handlers respond to bot commands (messages starting with `/`).

```crystal
bot.command("start") do |ctx|
  ctx.reply("Welcome to my bot!")
end

bot.command("help") do |ctx|
  ctx.reply("/start - Start the bot\n/help - Show this help")
end
```

### Command Arguments

Commands can have arguments:

```crystal
bot.command("echo") do |ctx|
  args = ctx.command_args
  if args
    ctx.reply(args)
  else
    ctx.reply("Usage: /echo <message>")
  end
end
```

### Command Matching

Commands support:
- `/command` - Basic command
- `/command@botname` - Commands for specific bots in groups
- `/command args` - Commands with arguments

## Hears Handlers

Hears handlers match message text using regex patterns:

```crystal
# Match "hello" case-insensitively
bot.hears(/hello/i) do |ctx|
  ctx.reply("Hi there!")
end

# Match email addresses
bot.hears(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/) do |ctx|
  ctx.reply("I detected an email address!")
end
```

### Regex Options

- `i` - Case insensitive
- `m` - Multiline
- `x` - Extended (ignore whitespace)

## Generic Event Handlers

Use `on` for specific update types:

```crystal
# Handle callback queries from inline keyboards
bot.on(:callback_query) do |ctx|
  data = ctx.data
  case data
  when "yes"
    ctx.answer("You said yes!")
  when "no"
    ctx.answer("You said no!")
  end
end

# Handle photo messages
bot.on(:message) do |ctx|
  if ctx.message.photo
    ctx.reply("Nice photo!")
  end
end
```

## Handler Priority and Order

Handlers are checked in registration order. First match wins:

```crystal
bot.hears(/hello/) do |ctx|
  ctx.reply("Formal greeting")
end

bot.hears(/hello/i) do |ctx|
  ctx.reply("Casual greeting")  # This will never match
end
```

## Conditional Handlers

Use filters to handle updates only under certain conditions:

```crystal
# Only respond in private chats
bot.command("secret", chat_type: "private") do |ctx|
  ctx.reply("This is a secret!")
end

# Only respond to specific users
bot.command("admin", from: {id: 123456789}) do |ctx|
  ctx.reply("Admin command executed")
end
```

## Handler Context

All handlers receive a `Context` object with:

- `ctx.update` - Raw Telegram update
- `ctx.message` - Message object (if applicable)
- `ctx.from` - User who sent the update
- `ctx.chat` - Chat where update occurred
- `ctx.text` - Message text
- `ctx.match` - Regex match data

## Async Handlers

Handlers run synchronously by default. For long operations:

```crystal
bot.command("long_task") do |ctx|
  spawn do
    # Long running operation
    result = some_expensive_operation()
    ctx.reply("Result: #{result}")
  end
  ctx.reply("Processing...")  # Immediate response
end
```

## Error Handling in Handlers

Handle errors within handlers:

```crystal
bot.command("risky") do |ctx|
  begin
    risky_operation()
    ctx.reply("Success!")
  rescue ex
    ctx.reply("Error: #{ex.message}")
  end
end
```

Or use global error handlers:

```crystal
bot.error do |error, ctx|
  ctx.try(&.reply("Something went wrong"))
end
```

## Handler Removal

Handlers cannot be removed once added. Restart the bot to change handlers.

## Performance Tips

- Keep handlers fast (respond within 30 seconds for webhooks)
- Use regex sparingly for complex patterns
- Cache expensive operations
- Use middleware for cross-cutting concerns

## Edge Cases

### Empty Messages

Handle messages with no text:

```crystal
bot.on(:message) do |ctx|
  unless ctx.text
    # Handle photos, documents, etc.
  end
end
```

### Edited Messages

Handle message edits:

```crystal
bot.on(:edited_message) do |ctx|
  ctx.reply("Message edited!")
end
```

### Channel Posts

Anonymous channel posts have no `from` user:

```crystal
bot.on(:channel_post) do |ctx|
  if ctx.from
    # User post
  else
    # Anonymous channel post
  end
end
```

### Bot Commands in Groups

In groups, commands may be `@botname`:

```crystal
bot.command("start") do |ctx|
  # This matches /start and /start@mybot
end
```

### Multiple Bots

If running multiple bots, use different tokens and instances.

### Unicode and Emojis

Regex patterns work with Unicode:

```crystal
bot.hears(/🚀/) do |ctx|
  ctx.reply("Rocket detected!")
end
```

### Long Messages

Telegram limits message length to 4096 characters:

```crystal
bot.on(:message) do |ctx|
  if ctx.text && ctx.text.size > 4000
    ctx.reply("Message too long to process")
  end
end
```

### Flooding

Use rate limiting middleware to prevent spam.