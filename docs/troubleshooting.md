# Troubleshooting

Common issues and their solutions when working with Telecr.

## Bot Not Responding

### Check Bot Token

**Problem**: Bot doesn't respond to messages.

**Symptoms**:
- No response to /start
- Commands ignored
- Polling/webhook not working

**Solutions**:

1. Verify token is correct:
```bash
curl "https://api.telegram.org/bot<YOUR_TOKEN>/getMe"
```

2. Check token format (should start with bot ID)

3. Ensure token has no extra spaces/characters

### Network Connectivity

**Problem**: Bot can't connect to Telegram API.

**Symptoms**:
- "Connection refused" errors
- Timeout errors
- HTTP errors

**Solutions**:

1. Check internet connection
2. Verify no firewall blocking requests
3. Try different network
4. Check Telegram API status: https://status.telegram.org/

### Bot Permissions

**Problem**: Bot can't perform certain actions.

**Symptoms**:
- Can't send messages
- Can't manage chats
- Media upload fails

**Solutions**:

1. Check bot permissions in chat
2. Re-add bot to chat with proper permissions
3. Verify bot was created with correct permissions

## Polling Issues

### Updates Not Received

**Problem**: Polling doesn't get new messages.

**Symptoms**:
- Bot appears online but doesn't respond
- No errors in logs
- Updates seem to be missed

**Solutions**:

1. Check polling is started:
```crystal
bot.start_polling
```

2. Verify token is valid

3. Check for exceptions in polling loop

4. Add logging to see if updates are received:
```crystal
bot.on(:message) do |ctx|
  puts "Received message: #{ctx.text}"
end
```

### High CPU Usage

**Problem**: Polling uses too much CPU.

**Symptoms**:
- High CPU usage
- System slowdown
- Battery drain on laptops

**Solutions**:

1. Use webhooks instead of polling for production
2. Increase polling timeout (default 30s is fine)
3. Add sleep between failed requests
4. Check for infinite loops in handlers

## Webhook Issues

### Webhook Not Set

**Problem**: Webhook URL not registered with Telegram.

**Symptoms**:
- Webhook server running but no updates received
- Polling works but webhook doesn't

**Solutions**:

1. Check webhook URL is accessible:
```bash
curl https://yourdomain.com/webhook
```

2. Verify SSL certificate is valid
3. Set webhook manually:
```crystal
bot.set_webhook(url: "https://yourdomain.com/webhook")
```

4. Check webhook info:
```bash
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"
```

### SSL Certificate Errors

**Problem**: Invalid SSL certificate for webhook.

**Symptoms**:
- "SSL certificate error" in logs
- Webhook registration fails
- Updates not delivered

**Solutions**:

1. Use valid certificate (not self-signed for production)
2. Check certificate expiration
3. Verify certificate matches domain
4. Use cloud platform SSL (Heroku, etc.)

### Timeout Errors

**Problem**: Webhook requests timeout.

**Symptoms**:
- 504 Gateway Timeout
- Slow response times
- Incomplete processing

**Solutions**:

1. Keep responses under 30 seconds
2. Move slow operations to background:
```crystal
bot.on(:message) do |ctx|
  ctx.reply("Processing...")

  spawn do
    slow_operation()
    ctx.reply("Done!")
  end
end
```

3. Use `ctx.typing` for long operations

## Handler Issues

### Handlers Not Triggering

**Problem**: Registered handlers don't execute.

**Symptoms**:
- Commands not recognized
- Regex patterns not matching
- Event handlers ignored

**Solutions**:

1. Check handler registration order (first match wins)
2. Verify regex patterns:
```crystal
# Test regex
pattern = /hello/i
puts "hello".match(pattern)  # Should not be nil
```

3. Check command format (must start with /)
4. Add logging to see if handlers are reached

### Context Issues

**Problem**: Context object missing expected data.

**Symptoms**:
- `ctx.message` is nil
- `ctx.from` is nil
- Session data not available

**Solutions**:

1. Check update type:
```crystal
bot.on(:message) do |ctx|
  puts "Update type: #{ctx.update.update_type}"
  puts "Message: #{ctx.message}"
end
```

2. Handle different update types appropriately
3. Check for anonymous messages (no `from` user)

## Session Issues

### Sessions Not Persisting

**Problem**: Session data lost between messages.

**Symptoms**:
- Session data disappears
- User preferences not saved
- State not maintained

**Solutions**:

1. Ensure session middleware is added:
```crystal
bot.use(Telecr::Session::Middleware.new)
```

2. Check store configuration (file/DB)
3. Verify session keys are strings:
```crystal
ctx.session["key"] = "value"  # Correct
ctx.session[:key] = "value"   # Wrong - use strings
```

4. Check for session store errors

### Session Data Corruption

**Problem**: Session data becomes invalid.

**Symptoms**:
- JSON parsing errors
- Type errors when accessing session
- Lost session data

**Solutions**:

1. Validate session data:
```crystal
age = ctx.session["age"]?.try(&.as_i?) || 0
```

2. Handle migration between versions
3. Clear corrupted sessions:
```crystal
begin
  data = ctx.session["key"]
rescue
  ctx.session.delete("key")
end
```

## Media/File Issues

### Download Failures

**Problem**: File downloads fail.

**Symptoms**:
- "File not found" errors
- Download timeouts
- Corrupted files

**Solutions**:

1. Check file ID is valid
2. Verify file still exists on Telegram
3. Handle large files appropriately
4. Add retry logic for network errors

### Upload Failures

**Problem**: Media uploads fail.

**Symptoms**:
- Upload timeouts
- File size errors
- Invalid file format errors

**Solutions**:

1. Check file size limits (20MB for documents)
2. Verify file format is supported
3. Use proper MIME types
4. Handle network timeouts

## Rate Limiting Issues

### False Positives

**Problem**: Legitimate requests blocked.

**Symptoms**:
- Users blocked unexpectedly
- Rate limits too strict

**Solutions**:

1. Adjust rate limit settings:
```crystal
bot.use(Telecr::Plugins::RateLimit.new(
  user: {max: 10, per: 30}  # More lenient
))
```

2. Exclude certain commands from rate limiting
3. Use different limits for different user types

### Rate Limits Too Loose

**Problem**: Not enough protection against abuse.

**Symptoms**:
- High server load
- Spam getting through

**Solutions**:

1. Tighten rate limits
2. Add per-chat limits
3. Implement progressive delays

## Database Issues

### Connection Errors

**Problem**: Database connections fail.

**Symptoms**:
- "Connection refused" errors
- Timeout errors
- Pool exhaustion

**Solutions**:

1. Check database server is running
2. Verify connection string
3. Use connection pooling
4. Implement retry logic

### Migration Errors

**Problem**: Database schema issues.

**Symptoms**:
- Table not found errors
- Column missing errors
- Type mismatch errors

**Solutions**:

1. Run database migrations
2. Check schema matches code expectations
3. Handle schema changes gracefully

## Memory Issues

### Memory Leaks

**Problem**: Memory usage grows over time.

**Symptoms**:
- Increasing memory usage
- Out of memory errors
- Performance degradation

**Solutions**:

1. Check for object retention in closures
2. Clean up temporary files
3. Use streaming for large files
4. Monitor GC stats

### High Memory Usage

**Problem**: Bot uses too much memory.

**Symptoms**:
- Large memory footprint
- GC pauses
- System slowdown

**Solutions**:

1. Process updates asynchronously
2. Use streaming downloads
3. Limit concurrent operations
4. Profile memory usage

## Performance Issues

### Slow Responses

**Problem**: Bot responds slowly.

**Symptoms**:
- Delayed responses
- Timeout errors
- Poor user experience

**Solutions**:

1. Optimize database queries
2. Cache frequently accessed data
3. Use background processing for slow operations
4. Profile performance bottlenecks

### High Latency

**Problem**: High response times.

**Symptoms**:
- Slow command responses
- Delayed media processing

**Solutions**:

1. Use webhooks instead of polling
2. Optimize middleware chain
3. Reduce database round trips
4. Use connection pooling

## Logging Issues

### Missing Logs

**Problem**: No log output.

**Symptoms**:
- Silent failures
- Hard to debug issues

**Solutions**:

1. Enable logging:
```crystal
require "log"
Log.setup(:debug)
```

2. Check log level configuration
3. Verify log output destination

### Too Much Logging

**Problem**: Log files grow too large.

**Symptoms**:
- Large log files
- Disk space issues
- Slow log searches

**Solutions**:

1. Adjust log levels
2. Use log rotation
3. Filter sensitive information
4. Use structured logging

## Testing Issues

### Test Failures

**Problem**: Tests don't pass.

**Symptoms**:
- Assertion failures
- Mocking issues
- Integration test failures

**Solutions**:

1. Check test setup
2. Verify mock objects
3. Test in isolation
4. Use proper test data

### Flaky Tests

**Problem**: Tests pass/fail randomly.

**Symptoms**:
- Intermittent failures
- Hard to reproduce issues

**Solutions**:

1. Avoid timing-dependent tests
2. Use proper synchronization
3. Mock external dependencies
4. Run tests multiple times

## Deployment Issues

### Environment Variables

**Problem**: Configuration not working in production.

**Symptoms**:
- Bot token not found
- Database connections fail
- Wrong environment settings

**Solutions**:

1. Check environment variable names
2. Verify values are set correctly
3. Use proper quoting for special characters
4. Debug with print statements

### Port Conflicts

**Problem**: Port already in use.

**Symptoms**:
- "Address already in use" errors
- Server won't start

**Solutions**:

1. Check what process is using the port:
```bash
lsof -i :3000
```

2. Use different port
3. Kill conflicting process
4. Use port 0 for auto-assignment

### SSL Issues

**Problem**: SSL configuration problems.

**Symptoms**:
- Certificate errors
- HTTPS not working
- Mixed content warnings

**Solutions**:

1. Verify certificate files exist
2. Check certificate validity
3. Use correct file paths
4. Test SSL configuration locally

## Common Error Messages

### "Invalid bot token"

**Cause**: Incorrect or expired bot token
**Solution**: Get new token from @BotFather

### "Chat not found"

**Cause**: Bot not in chat or chat doesn't exist
**Solution**: Add bot to chat, check chat ID

### "Message is too long"

**Cause**: Message exceeds 4096 characters
**Solution**: Split long messages or use files

### "File is too big"

**Cause**: File exceeds Telegram limits
**Solution**: Compress files or use external storage

### "Too many requests"

**Cause**: Rate limit exceeded
**Solution**: Implement rate limiting, use delays

### "Webhook URL is already set"

**Cause**: Another webhook is active
**Solution**: Remove existing webhook first

## Debugging Tools

### Telegram Bot API Debugging

```bash
# Test API access
curl "https://api.telegram.org/bot<TOKEN>/getMe"

# Check webhook status
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"

# Send test message
curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -d "chat_id=<CHAT_ID>&text=Test"
```

### Local Debugging

```crystal
# Add debug logging
bot.on(:message) do |ctx|
  puts "DEBUG: #{ctx.update.to_json}"
end

# Test handlers in isolation
handler = bot.handlers.find_match(ctx)
puts "Matching handler: #{handler}"
```

### Performance Profiling

```crystal
require "benchmark"

bot.on(:message) do |ctx|
  time = Benchmark.measure do
    # Your code here
  end
  puts "Processing time: #{time.total}"
end
```

## Getting Help

### Community Resources

- GitHub Issues: Report bugs and request features
- Crystal Forum: General Crystal discussion
- Telegram Bot Community: Bot development discussions

### Debug Information

When reporting issues, include:

1. Crystal version: `crystal --version`
2. Telecr version
3. Full error message and backtrace
4. Code snippet causing the issue
5. Steps to reproduce
6. Expected vs actual behavior

### Minimal Reproduction

Create minimal code that reproduces the issue:

```crystal
require "telecr"

bot = Telecr.new("TOKEN")

# Minimal reproduction code here

bot.start_polling
```

This helps isolate the problem and get faster help.