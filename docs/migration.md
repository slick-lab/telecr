# Migration Guide

Upgrading Telecr versions and handling breaking changes.

## From 0.x to 1.0

### Breaking Changes

#### Bot Initialization

**Before:**
```crystal
bot = Telecr::Bot.new("TOKEN")
```

**After:**
```crystal
bot = Telecr.new("TOKEN")
```

#### Handler Registration

**Before:**
```crystal
bot.on_message do |ctx|
  # handler
end

bot.on_command("start") do |ctx|
  # handler
end
```

**After:**
```crystal
bot.on(:message) do |ctx|
  # handler
end

bot.command("start") do |ctx|
  # handler
end
```

#### Context Properties

**Before:**
```crystal
ctx.message.text
ctx.message.from.username
```

**After:**
```crystal
ctx.text
ctx.from.username
```

#### Keyboard Creation

**Before:**
```crystal
keyboard = Telecr::ReplyKeyboard.new
keyboard.add_button("Yes")
keyboard.add_button("No")
```

**After:**
```crystal
keyboard = Telecr.keyboard do |k|
  k.row(k.text("Yes"), k.text("No"))
end
```

#### Middleware Usage

**Before:**
```crystal
bot.middleware.add(SessionMiddleware.new)
```

**After:**
```crystal
bot.use(Telecr::Session::Middleware.new)
```

### Migration Steps

1. Update bot initialization
2. Change handler registrations
3. Update context property access
4. Rewrite keyboard creation code
5. Update middleware registration

## Session Data Migration

If upgrading with existing session data:

```crystal
class SessionMigrator < Telecr::Core::Middleware
  def call(ctx, next_mw)
    # Migrate old session format
    if ctx.session["old_format_data"]?
      # Transform old data to new format
      old_data = ctx.session["old_format_data"]
      ctx.session["new_format_data"] = transform_data(old_data)
      ctx.session.delete("old_format_data")
    end

    next_mw.call(ctx)
  end
end

bot.use(SessionMigrator.new)
```

## Configuration Changes

### Environment Variables

**Before:**
```crystal
token = ENV["TELEGRAM_BOT_TOKEN"]
```

**After:**
```crystal
token = ENV["BOT_TOKEN"] || ENV["TELEGRAM_BOT_TOKEN"]
```

### Webhook Configuration

**Before:**
```crystal
bot.configure_webhook(url: "https://...", port: 3000)
bot.start_webhook
```

**After:**
```crystal
bot.start_webhook(path: "/webhook", port: 3000)
```

## Code Examples Migration

### Simple Echo Bot

**Before:**
```crystal
require "telecr"

bot = Telecr::Bot.new(ENV["TELEGRAM_BOT_TOKEN"])

bot.on_message do |ctx|
  if text = ctx.message.text
    ctx.reply(text)
  end
end

bot.start_polling
```

**After:**
```crystal
require "telecr"

bot = Telecr.new(ENV["BOT_TOKEN"])

bot.on(:message) do |ctx|
  if text = ctx.text
    ctx.reply(text)
  end
end

bot.start_polling
```

### Keyboard Bot

**Before:**
```crystal
keyboard = Telecr::ReplyKeyboard.new
keyboard.add_row(["Yes", "No"])

bot.on_command("start") do |ctx|
  ctx.reply("Choose:", reply_markup: keyboard)
end
```

**After:**
```crystal
keyboard = Telecr.keyboard do |k|
  k.row(k.text("Yes"), k.text("No"))
end

bot.command("start") do |ctx|
  ctx.reply("Choose:", reply_markup: keyboard.to_h)
end
```

## Testing Migration

After migration, run your test suite:

```crystal
crystal spec
```

Update tests for new API:

```crystal
# Before
expect(ctx.message.text).to eq("hello")

# After
expect(ctx.text).to eq("hello")
```

## Common Issues After Migration

### "Undefined method" errors

- Check method names changed in 1.0
- Update to new context properties
- Verify middleware registration syntax

### Session data loss

- Implement migration middleware
- Backup session data before upgrade
- Test session persistence

### Handler not triggering

- Update handler registration syntax
- Check event type symbols
- Verify command matching logic

### Keyboard not working

- Update to new keyboard DSL
- Check button creation methods
- Verify markup serialization

## Rollback Plan

If migration fails:

1. Keep old version deployed
2. Test migration in staging
3. Have backup of session data
4. Plan rollback within deployment window

## Future Compatibility

Telecr 1.0+ follows semantic versioning:

- **Patch versions** (1.0.x): Bug fixes, no breaking changes
- **Minor versions** (1.x.0): New features, backward compatible
- **Major versions** (x.0.0): Breaking changes, migration required

## Getting Help

For migration issues:

1. Check this guide for your version transition
2. Search existing GitHub issues
3. Create new issue with migration details
4. Include before/after code examples

## Version History

### 1.0.0 (Current)
- Complete API redesign
- Improved type safety
- Better middleware system
- Enhanced keyboard DSL

### 0.5.0
- Initial webhook support
- Session middleware
- Rate limiting

### 0.1.0
- Basic bot functionality
- Polling support
- Simple command handling