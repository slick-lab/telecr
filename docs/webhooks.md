# Webhooks

Webhooks provide instant delivery of updates to your bot, making it more responsive than polling. They're essential for production deployments and work well with platforms like Heroku, Railway, and cloud functions.

## Basic Webhook Setup

```crystal
bot = Telecr.new("YOUR_BOT_TOKEN")

# Configure webhook
bot.start_webhook(
  path: "/webhook",
  port: ENV["PORT"]?.try(&.to_i) || 3000
)

# Your bot handlers here
bot.command("start") do |ctx|
  ctx.reply("Hello from webhook bot!")
end
```

## Webhook URL Configuration

Telegram requires HTTPS for webhooks. Set the webhook URL:

```crystal
# Manual URL setting
bot.set_webhook(url: "https://yourdomain.com/webhook")

# Auto-configuration (when using start_webhook)
bot.start_webhook(path: "/bot", port: 443)
# Automatically sets webhook to https://yourdomain.com/bot
```

## Environment Variables

Use environment variables for configuration:

```bash
export TELECR_WEBHOOK_URL="https://mybot.example.com"
export PORT=3000
```

```crystal
bot.start_webhook(
  path: "/webhook",
  port: ENV["PORT"].to_i
)
```

## SSL Configuration

### Automatic SSL (Cloud Platforms)

For Heroku, Railway, Render, etc.:

```crystal
bot.start_webhook(
  path: "/webhook",
  port: ENV["PORT"].to_i,
  ssl: :cloud  # SSL handled by platform
)
```

### Manual SSL

Using your own certificates:

```crystal
bot.start_webhook(
  path: "/webhook",
  port: 443,
  ssl: {
    cert_path: "/path/to/cert.pem",
    key_path: "/path/to/key.pem"
  }
)
```

### Development SSL

Generate self-signed certificates for local development:

```bash
# Generate certificates
crystal bin/telecr-ssl.cr yourdomain.com

# This creates .telecr-ssl config file
```

```crystal
bot.start_webhook(
  path: "/webhook",
  port: 8443,
  ssl: true  # Uses .telecr-ssl config
)
```

## Webhook Verification

Telegram signs webhook requests. Verify them:

```crystal
bot.start_webhook(
  path: "/webhook",
  secret_token: "your_secret_token"
)

# Requests without matching X-Telegram-Bot-Api-Secret-Token header are rejected
```

## Error Handling

Handle webhook errors gracefully:

```crystal
bot.error do |error, ctx|
  puts "Webhook error: #{error.message}"
  # Don't reply here - webhook responses should be fast
end
```

## Health Checks

Add health check endpoints:

```crystal
# Automatic health check at /health and /healthz
bot.start_webhook(path: "/webhook")  # Health checks enabled by default

# Custom health check
bot.start_webhook(path: "/webhook", health_check: false)

# Manual health endpoint
get "/health" do
  "OK"
end
```

## Timeout Handling

Webhooks have strict timeouts. Keep responses fast:

```crystal
bot.on(:message) do |ctx|
  # Fast response first
  ctx.reply("Processing...")

  # Do slow work asynchronously
  spawn do
    result = slow_operation()
    ctx.reply("Result: #{result}")
  end
end
```

## Concurrent Processing

Webhooks handle multiple requests concurrently:

```crystal
# Each webhook request runs in its own fiber
bot.on(:message) do |ctx|
  # This is safe - no shared state issues
  process_message(ctx)
end
```

## Scaling Considerations

### Multiple Instances

For high traffic, run multiple bot instances:

```crystal
# Instance 1
bot1 = Telecr.new("TOKEN")
bot1.start_webhook(path: "/webhook/1", port: 3001)

# Instance 2
bot2 = Telecr.new("TOKEN")
bot2.start_webhook(path: "/webhook/2", port: 3002)

# Load balancer distributes requests
```

### Database Connections

Use connection pooling for databases:

```crystal
# Each instance gets its own connection pool
bot.use(DatabaseMiddleware.new(pool_size: 10))
```

## Deployment Examples

### Heroku

```crystal
# Procfile
web: crystal run --release bot.cr

# bot.cr
bot.start_webhook(
  path: "/webhook",
  port: ENV["PORT"].to_i,
  ssl: :cloud
)
```

### Docker

```dockerfile
FROM crystallang/crystal:latest

WORKDIR /app
COPY . .

RUN shards build --release

EXPOSE 3000
CMD ["./bin/bot"]
```

```crystal
bot.start_webhook(
  path: "/webhook",
  port: 3000,
  ssl: :cloud
)
```

### Railway

```crystal
# Railway provides PORT and HTTPS automatically
bot.start_webhook(
  path: "/webhook",
  port: ENV["PORT"].to_i,
  ssl: :cloud
)
```

### AWS Lambda

```crystal
def handler(event : JSON::Any, context : JSON::Any) : JSON::Any
  update = Types::Update.from_json(event.to_json)
  bot.process(update)

  {"statusCode" => 200, "body" => "OK"}
end

# Set webhook to your Lambda URL
bot.set_webhook(url: "https://your-lambda-url.amazonaws.com/webhook")
```

## Security

### Secret Tokens

Always use secret tokens:

```crystal
secure_token = Random::Secure.hex(32)
bot.start_webhook(
  path: "/webhook",
  secret_token: secure_token
)
```

### IP Whitelisting

Restrict to Telegram's IP ranges:

```crystal
TELEGRAM_IPS = [
  "149.154.160.0/20",
  "91.108.4.0/22"
  # Add all ranges from https://core.telegram.org/bots/webhooks
]

class IPFilterMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    client_ip = get_client_ip(ctx)

    unless TELEGRAM_IPS.any? { |range| ip_in_range?(client_ip, range) }
      return error_response("Unauthorized IP")
    end

    next_mw.call(ctx)
  end
end
```

### Request Validation

Validate webhook payloads:

```crystal
bot.on_webhook_request do |request|
  # Validate request before processing
  unless valid_telegram_request?(request)
    return error_response(403)
  end
end
```

## Monitoring

### Request Logging

Log webhook requests:

```crystal
class WebhookLogger < Telecr::Core::Middleware
  def call(ctx, next_mw)
    start = Time.monotonic

    puts "[#{Time.utc}] Webhook from #{ctx.from.try(&.username)}"

    next_mw.call(ctx)

    duration = Time.monotonic - start
    puts "Processed in #{duration.total_milliseconds.round(2)}ms"
  end
end

bot.use(WebhookLogger.new)
```

### Performance Metrics

Track webhook performance:

```crystal
class WebhookMetrics < Telecr::Core::Middleware
  @requests = 0
  @errors = 0
  @avg_response_time = 0.0

  def call(ctx, next_mw)
    start = Time.monotonic
    @requests += 1

    begin
      next_mw.call(ctx)
    rescue ex
      @errors += 1
      raise ex
    ensure
      duration = Time.monotonic - start
      @avg_response_time = (@avg_response_time + duration.total_milliseconds) / 2
    end
  end

  def stats
    {
      requests: @requests,
      errors: @errors,
      error_rate: @errors.to_f / @requests,
      avg_response_time: @avg_response_time
    }
  end
end
```

## Troubleshooting

### Webhook Not Receiving Updates

1. Check webhook URL is accessible
2. Verify SSL certificate is valid
3. Ensure secret token matches
4. Check bot token is correct

### Timeout Errors

1. Keep webhook responses under 30 seconds
2. Move slow operations to background jobs
3. Use `ctx.typing` for long operations

### SSL Errors

1. Use valid certificates (not self-signed for production)
2. Check certificate paths
3. Verify certificate matches domain

### High Error Rates

1. Add proper error handling
2. Monitor memory usage
3. Check for infinite loops
4. Validate input data

## Advanced Configuration

### Custom HTTP Server

For advanced HTTP configuration:

```crystal
server = HTTP::Server.new([
  HTTP::ErrorHandler.new,
  HTTP::LogHandler.new,
  WebhookHandler.new(bot)
])

server.bind_tcp("0.0.0.0", 3000)
server.listen
```

### Middleware Integration

Webhooks work with all middleware:

```crystal
bot.use(SessionMiddleware.new)
bot.use(RateLimitMiddleware.new)
bot.use(AuthMiddleware.new)

bot.start_webhook(path: "/webhook")
```

### Graceful Shutdown

Handle shutdown signals:

```crystal
bot.start_webhook(path: "/webhook")

Signal::INT.trap do
  puts "Shutting down..."
  bot.shutdown
  exit
end

sleep
```

## Migration from Polling

### Gradual Migration

Run both polling and webhooks during transition:

```crystal
# Start webhook
bot.start_webhook(path: "/webhook")

# Keep polling as backup
spawn do
  bot.start_polling
end
```

### Testing Webhook Setup

Test webhook locally:

```bash
# Use ngrok for local testing
ngrok http 3000

# Set webhook to ngrok URL
curl "https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://abc123.ngrok.io/webhook"
```

## Best Practices

1. **Use HTTPS**: Always use HTTPS for webhooks
2. **Fast Responses**: Keep responses under 30 seconds
3. **Error Handling**: Handle all errors gracefully
4. **Monitoring**: Monitor webhook health and performance
5. **Security**: Use secret tokens and validate requests
6. **Scaling**: Design for horizontal scaling
7. **Testing**: Test webhook setup thoroughly
8. **Documentation**: Document your webhook endpoints

## Common Issues

### "Webhook URL is already set"

```crystal
# Remove existing webhook
bot.set_webhook(url: "")

# Then set new one
bot.set_webhook(url: "https://new-url.com/webhook")
```

### "SSL certificate error"

- Use valid certificates
- Check certificate expiration
- Verify certificate matches domain

### "Timeout error"

```crystal
# Use background processing
bot.on(:message) do |ctx|
  ctx.reply("Processing...")

  spawn do
    # Slow operation
    sleep 30
    ctx.reply("Done!")
  end
end
```

### Memory Leaks

- Clean up resources properly
- Use connection pooling
- Monitor memory usage
- Restart instances periodically

### Race Conditions

- Use locks for shared state
- Design for concurrent access
- Test with multiple simultaneous requests