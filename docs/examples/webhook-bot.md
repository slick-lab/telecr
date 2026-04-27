# Webhook Bot Example

A production-ready bot using webhooks for instant responses.

```crystal
require "telecr"

bot = Telecr.new(ENV["BOT_TOKEN"])

# Add middleware
bot.use(Telecr::Session::Middleware.new)
bot.use(Telecr::Plugins::RateLimit.new(
  user: {max: 5, per: 10},
  chat: {max: 20, per: 60}
))

# Commands
bot.command("start") do |ctx|
  ctx.reply("Hello! I'm running on webhooks 🚀")
end

bot.command("ping") do |ctx|
  ctx.reply("Pong! ⚡")
end

# Handle photos
bot.on(:message) do |ctx|
  if ctx.message.photo
    ctx.reply("Thanks for the photo! 📸")
  end
end

# Handle callback queries
bot.on(:callback_query) do |ctx|
  case ctx.data
  when "yes"
    ctx.answer("You said yes!")
  when "no"
    ctx.answer("You said no!")
  end
end

# Error handling
bot.error do |error, ctx|
  puts "Error: #{error.message}"
  ctx.try(&.reply("Something went wrong, please try again."))
end

# Webhook configuration
webhook_url = ENV["WEBHOOK_URL"]? || "https://yourdomain.com"
port = ENV["PORT"]?.try(&.to_i) || 3000

puts "Starting webhook server on port #{port}"
puts "Webhook URL: #{webhook_url}/webhook"

bot.start_webhook(
  path: "/webhook",
  port: port
)

# Graceful shutdown
Signal::INT.trap do
  puts "Shutting down..."
  bot.shutdown
  exit
end

# Keep the server running
sleep
```

## Deployment

### Heroku

1. Create `Procfile`:
```
web: crystal run webhook_bot.cr
```

2. Set environment variables:
```bash
heroku config:set BOT_TOKEN="your_token"
heroku config:set WEBHOOK_URL="https://your-app.herokuapp.com"
```

3. Deploy:
```bash
git push heroku main
```

### Docker

1. Create `Dockerfile`:
```dockerfile
FROM crystallang/crystal:latest

WORKDIR /app
COPY . .

RUN shards build --release

EXPOSE 3000
CMD ["./bin/webhook_bot"]
```

2. Build and run:
```bash
docker build -t webhook-bot .
docker run -p 3000:3000 -e BOT_TOKEN="your_token" webhook-bot
```

### Railway

1. Set environment variables in Railway dashboard
2. Deploy from GitHub
3. Railway automatically provides `PORT` and HTTPS

## Environment Variables

Required:
- `BOT_TOKEN`: Your Telegram bot token
- `PORT`: Port for webhook server (provided by hosting platform)

Optional:
- `WEBHOOK_URL`: Full webhook URL (for manual webhook setting)

## SSL Configuration

For production, ensure HTTPS:

- Heroku: Automatic SSL
- Railway: Automatic SSL
- Custom: Use valid SSL certificates

## Health Checks

The webhook server includes automatic health checks at `/health` and `/healthz`.

## Monitoring

Add logging for production monitoring:

```crystal
require "log"

Log.setup(:info, Log::IOBackend.new(formatter: Log::Formatter.new do |entry, io|
  io << entry.timestamp.to_s("%Y-%m-%d %H:%M:%S")
  io << " [" << entry.severity << "] "
  io << entry.message
end))

# Log all updates
bot.on(:message) do |ctx|
  Log.info { "Message from #{ctx.from.try(&.username)}: #{ctx.text}" }
end
```

## Scaling

For high-traffic bots:

1. Run multiple instances behind a load balancer
2. Use Redis for shared sessions
3. Implement database connection pooling
4. Add request queuing for rate limiting