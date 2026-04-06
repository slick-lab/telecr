
# Echo Bot Example

This example demonstrates how to create a simple echo bot using Telecr.  
The bot replies with the same text message it receives from the user.

---

## Installation

Add Telecr to your `shard.yml`:

```yaml
dependencies:
  telecr:
    github: slick-lab/telecr
    version: ~> 1.0.0
```

Then run:

```bash
shards install
```

---

## Code Example

```crystal
require "telecr"

# Initialize bot with your token
bot = Telecr.new("YOUR_BOT_TOKEN")

# Echo handler: replies with the same text
bot.on(:message) do |ctx|
  if ctx.message.text?
    ctx.reply("You said: #{ctx.message.text}")
  end
end

# Start polling
bot.run
```

---

## Running the Bot

1. Replace `YOUR_BOT_TOKEN` with your actual bot token from BotFather.
2. Run the bot:
   ```bash
   crystal run echo_bot.cr
   ```
3. Send any message to your bot in Telegram — it will reply with the same text.

---

## Notes
- Works with polling mode by default.  
- works with webhook 

---

**Tip:** This is the simplest bot pattern. From here, you can add commands, middleware, or keyboards to expand functionality.
