# Getting Started with Telecr

This guide will help you create your first Telegram bot using Telecr.

## Prerequisites

- Crystal 1.0.0 or later
- A Telegram bot token (get one from [@BotFather](https://t.me/botfather))

## Installation

Add Telecr to your `shard.yml`:

```yaml
dependencies:
  telecr:
    github: slick-lab/telecr
    version: ~> 1.0.0
```

Install dependencies:

```bash
shards install
```

## Your First Bot

Create a file `bot.cr`:

```crystal
require "telecr"

# Create a bot instance with your token
bot = Telecr.new("YOUR_BOT_TOKEN")

# Handle the /start command
bot.command("start") do |ctx|
  ctx.reply("Hello! I'm your first Telecr bot! 🚀")
end

# Handle any message containing "hello"
bot.hears(/hello/i) do |ctx|
  ctx.reply("Hi there! 👋")
end

# Start polling for updates
bot.start_polling
```

Run your bot:

```bash
crystal run bot.cr
```

## Next Steps

- Learn about [handlers](handlers.md) for more ways to respond to messages
- Explore [keyboards](keyboards.md) for interactive buttons
- Set up [middleware](middleware.md) for advanced features like sessions
- Deploy with [webhooks](webhooks.md) for production

## Common Issues

### Bot doesn't respond

1. Check your bot token is correct
2. Ensure the bot is running and not crashed
3. Verify internet connectivity
4. Check Telegram Bot API status

### "Connection refused" errors

- Your bot token might be invalid
- Telegram API might be down (rare)
- Network firewall blocking requests

### Bot responds slowly

- First message after startup may be slow due to DNS resolution
- Consider using webhooks for production instead of polling

## Environment Variables

You can use environment variables for configuration:

```bash
export TELECR_BOT_TOKEN="your_bot_token_here"
```

Then in code:

```crystal
token = ENV["TELECR_BOT_TOKEN"]
bot = Telecr.new(token)
```

## Development Tips

- Use `crystal run --debug bot.cr` for debug builds
- Add logging: `require "log"; Log.setup(:debug)`
- Test with [@userinfobot](https://t.me/userinfobot) to get your user ID
- Use polling for development, webhooks for production