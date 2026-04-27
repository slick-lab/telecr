# Echo Bot Example

A simple bot that echoes back messages.

```crystal
require "telecr"

bot = Telecr.new(ENV["BOT_TOKEN"])

# Echo text messages
bot.on(:message) do |ctx|
  if text = ctx.text
    ctx.reply("You said: #{text}")
  end
end

# Echo photos
bot.on(:message) do |ctx|
  if ctx.message.photo
    ctx.reply("Nice photo! 📸")
  end
end

bot.start_polling
```

## Running the Example

1. Set your bot token:
```bash
export BOT_TOKEN="your_bot_token_here"
```

2. Run the bot:
```crystal
crystal run echo_bot.cr
```

3. Send messages to your bot - it will echo them back!