# Error Handling

Comprehensive error handling is crucial for robust Telegram bots. Telecr provides multiple layers of error handling to ensure your bot remains stable and responsive.

## Global Error Handler

Catch all unhandled errors:

```crystal
bot.error do |error, ctx|
  puts "Error: #{error.message}"
  puts error.backtrace.join("\n")

  if ctx
    ctx.reply("Sorry, something went wrong. Please try again.")
  end
end
```

## Handler-Level Error Handling

Handle errors within specific handlers:

```crystal
bot.command("risky") do |ctx|
  begin
    dangerous_operation()
    ctx.reply("Success!")
  rescue ex : SpecificError
    ctx.reply("Specific error occurred")
  rescue ex : Exception
    ctx.reply("General error occurred")
  end
end
```

## Middleware Error Handling

Handle errors in middleware chains:

```crystal
class SafeMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    begin
      next_mw.call(ctx)
    rescue ex : Exception
      puts "Middleware error: #{ex.message}"
      # Decide whether to continue or re-raise
    end
  end
end
```

## Network Errors

Handle Telegram API failures:

```crystal
bot.on(:message) do |ctx|
  begin
    ctx.reply("Response")
  rescue ex : HTTP::Error
    puts "Network error: #{ex.message}"
    # Retry logic or fallback
  end
end
```

## Rate Limit Errors

Handle rate limiting gracefully:

```crystal
class CustomRateLimit < Telecr::Plugins::RateLimit
  def rate_limit_response(ctx)
    # Check if this is a critical operation
    if critical_command?(ctx)
      # Allow critical operations through
      increment_counters(ctx)
      return call_next_middleware(ctx)
    end

    # Standard rate limit response
    ctx.reply("⏳ Please wait before sending another request.")
  end
end
```

## File Upload Errors

Handle file operation failures:

```crystal
bot.on(:document) do |ctx|
  begin
    file_path = ctx.download_file(doc.file_id, "downloads/file")
    process_file(file_path)
  rescue ex : File::Error
    ctx.reply("Failed to save file: #{ex.message}")
  rescue ex : Exception
    ctx.reply("Error processing file")
  ensure
    # Clean up temporary files
    File.delete(file_path) if file_path && File.exists?(file_path)
  end
end
```

## Session Errors

Handle session storage failures:

```crystal
class ResilientSessionMiddleware < Telecr::Session::Middleware
  def call(ctx, next_mw)
    begin
      super
    rescue ex : Exception
      puts "Session error: #{ex.message}"
      # Continue without session
      next_mw.call(ctx)
    end
  end
end
```

## Validation Errors

Validate input before processing:

```crystal
bot.command("set_age") do |ctx|
  args = ctx.command_args
  unless args
    ctx.reply("Usage: /set_age <number>")
    return
  end

  age = args.to_i?
  unless age && age > 0 && age < 150
    ctx.reply("Please provide a valid age")
    return
  end

  ctx.session["age"] = age
  ctx.reply("Age set to #{age}")
end
```

## Timeout Handling

Handle long-running operations:

```crystal
require "timeout"

bot.command("long_task") do |ctx|
  ctx.reply("Starting long task...")

  begin
    Timeout.timeout(25.seconds) do  # Leave buffer for webhook timeout
      result = perform_long_task()
      ctx.reply("Task completed: #{result}")
    end
  rescue Timeout::Error
    ctx.reply("Task timed out")
  end
end
```

## Database Errors

Handle database connection issues:

```crystal
class DatabaseMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    begin
      # Get database connection
      db = get_db_connection()
      ctx.state[:db] = db

      next_mw.call(ctx)
    rescue ex : DB::Error
      puts "Database error: #{ex.message}"
      ctx.reply("Database temporarily unavailable")
    ensure
      # Return connection to pool
      db.close if db
    end
  end
end
```

## Webhook Errors

Handle webhook-specific errors:

```crystal
# Webhook timeout (30 seconds)
bot.on(:message) do |ctx|
  # Quick response
  ctx.reply("Processing...")

  # Slow work in background
  spawn do
    begin
      result = slow_processing()
      ctx.reply("Result: #{result}")
    rescue ex : Exception
      puts "Background processing error: #{ex.message}"
    end
  end
end
```

## JSON Parsing Errors

Handle malformed update data:

```crystal
bot.process(data)  # This can raise JSON::Error

# Or handle in error handler
bot.error do |error, ctx|
  case error
  when JSON::Error
    puts "Invalid JSON received"
  else
    puts "Other error: #{error.message}"
  end
end
```

## File System Errors

Handle disk space and permission issues:

```crystal
def safe_download(ctx, file_id, filename)
  # Check disk space
  stat = File.stat("downloads/")
  available_space = stat.available_space
  if available_space < 10_000_000  # 10MB
    raise "Insufficient disk space"
  end

  # Create directory if needed
  Dir.mkdir_p("downloads")

  # Download with error handling
  ctx.download_file(file_id, "downloads/#{filename}")
end

bot.on(:document) do |ctx|
  begin
    safe_download(ctx, doc.file_id, "file")
    ctx.reply("Download complete")
  rescue ex : Exception
    ctx.reply("Download failed: #{ex.message}")
  end
end
```

## Memory Errors

Handle out-of-memory situations:

```crystal
# Monitor memory usage
class MemoryMonitor < Telecr::Core::Middleware
  def call(ctx, next_mw)
    before = GC.stats.heap_size

    next_mw.call(ctx)

    after = GC.stats.heap_size
    if after - before > 100_000_000  # 100MB increase
      puts "High memory usage detected"
      GC.collect
    end
  end
end
```

## Custom Error Classes

Define application-specific errors:

```crystal
class BotError < Exception
  getter code : String

  def initialize(@code, message)
    super(message)
  end
end

class ValidationError < BotError
  def initialize(field, value)
    super("VALIDATION_ERROR", "Invalid #{field}: #{value}")
  end
end

class PermissionError < BotError
  def initialize(action)
    super("PERMISSION_DENIED", "Not allowed to #{action}")
  end
end
```

## Error Recovery

Implement retry logic for transient errors:

```crystal
def with_retry(attempts = 3, &block)
  attempts.times do |i|
    begin
      return yield
    rescue ex : Exception
      if i == attempts - 1
        raise ex
      end
      sleep 2 ** i  # Exponential backoff
    end
  end
end

bot.on(:message) do |ctx|
  with_retry do
    unreliable_api_call()
    ctx.reply("Success")
  end
end
```

## Logging Errors

Comprehensive error logging:

```crystal
require "log"

class ErrorLogger < Telecr::Core::Middleware
  def call(ctx, next_mw)
    begin
      next_mw.call(ctx)
    rescue ex : Exception
      Log.error(exception: ex) do
        "Error processing update #{ctx.update.update_id} from user #{ctx.from.try(&.id)}"
      end
      raise ex
    end
  end
end

bot.use(ErrorLogger.new)
```

## User-Friendly Messages

Convert technical errors to user messages:

```crystal
ERROR_MESSAGES = {
  "DB_CONNECTION_ERROR" => "Service temporarily unavailable",
  "FILE_TOO_LARGE" => "File is too large (max 20MB)",
  "INVALID_FORMAT" => "Unsupported file format",
  "RATE_LIMITED" => "Too many requests, please wait"
}

bot.error do |error, ctx|
  if bot_error = error.as?(BotError)
    user_message = ERROR_MESSAGES[bot_error.code]? || "An error occurred"
    ctx.try(&.reply(user_message))
  else
    ctx.try(&.reply("Something went wrong"))
  end
end
```

## Testing Error Scenarios

Test error handling:

```crystal
describe "Error handling" do
  it "handles network errors gracefully" do
    # Mock network failure
    allow(HTTP::Client).to receive(:post).and_raise(HTTP::Error.new("Connection failed"))

    ctx = create_context
    bot.process_update(ctx.update)

    # Verify error response was sent
    expect(ctx).to have_received(:reply).with("Service temporarily unavailable")
  end
end
```

## Monitoring and Alerts

Monitor error rates:

```crystal
class ErrorMonitor
  @errors = [] of {Time, Exception}

  def record(error : Exception)
    @errors << {Time.utc, error}
    cleanup_old_errors
  end

  def error_rate : Float64
    recent_errors = @errors.select { |time, _| time > 1.hour.ago }
    recent_errors.size.to_f / 3600  # errors per second
  end

  private def cleanup_old_errors
    @errors.reject! { |time, _| time < 24.hours.ago }
  end
end

monitor = ErrorMonitor.new

bot.error do |error, ctx|
  monitor.record(error)

  if monitor.error_rate > 0.1  # More than 0.1 errors/second
    alert_admin("High error rate detected!")
  end
end
```

## Graceful Degradation

Continue operating when components fail:

```crystal
class DegradingMiddleware < Telecr::Core::Middleware
  @cache_available = true

  def call(ctx, next_mw)
    # Try cache first
    if @cache_available
      begin
        result = get_from_cache(ctx)
        return result if result
      rescue ex
        puts "Cache unavailable: #{ex.message}"
        @cache_available = false
      end
    end

    # Fallback to direct processing
    next_mw.call(ctx)
  end
end
```

## Circuit Breaker Pattern

Prevent cascading failures:

```crystal
class CircuitBreaker
  def initialize(@failure_threshold = 5, @recovery_timeout = 60.seconds)
    @failures = 0
    @last_failure_time = Time::UNIX_EPOCH
    @state = :closed
  end

  def call(&block)
    case @state
    when :open
      if Time.utc - @last_failure_time > @recovery_timeout
        @state = :half_open
      else
        raise "Circuit breaker is open"
      end
    end

    begin
      result = yield
      on_success
      result
    rescue ex
      on_failure
      raise ex
    end
  end

  private def on_success
    @failures = 0
    @state = :closed
  end

  private def on_failure
    @failures += 1
    @last_failure_time = Time.utc

    if @failures >= @failure_threshold
      @state = :open
    end
  end
end
```

## Common Error Patterns

### Database Connection Pool Exhaustion

```crystal
# Use connection pooling
class PooledDatabaseMiddleware < Telecr::Core::Middleware
  @@pool = DB::Pool.new(max_size: 10) do
    DB.open(ENV["DATABASE_URL"])
  end

  def call(ctx, next_mw)
    @@pool.checkout do |db|
      ctx.state[:db] = db
      next_mw.call(ctx)
    end
  end
end
```

### File Handle Leaks

```crystal
# Ensure file handles are closed
bot.on(:document) do |ctx|
  file_path = ctx.download_file(doc.file_id)

  begin
    File.open(file_path) do |file|
      process_file(file)
    end
  ensure
    File.delete(file_path) if file_path
  end
end
```

### Memory Leaks in Sessions

```crystal
# Clean up large session data
class SessionCleaner < Telecr::Core::Middleware
  def call(ctx, next_mw)
    next_mw.call(ctx)

    # Remove temporary data
    ctx.session.delete("temp_data")

    # Limit session size
    if ctx.session.to_json.size > 10_000  # 10KB
      # Archive old data or remove non-essential items
      cleanup_session(ctx.session)
    end
  end
end
```

### Race Conditions

```crystal
# Use locks for shared resources
@@mutex = Mutex.new

bot.command("shared_resource") do |ctx|
  @@mutex.synchronize do
    # Access shared resource safely
    shared_counter += 1
    ctx.reply("Counter: #{shared_counter}")
  end
end
```

## Error Response Codes

Map errors to appropriate HTTP status codes for webhooks:

```crystal
# In webhook handler
begin
  bot.process(update)
  response.status = 200
rescue ex : ValidationError
  response.status = 400
rescue ex : PermissionError
  response.status = 403
rescue ex : Exception
  response.status = 500
end
```

## Debugging Errors

Debugging techniques:

```crystal
# Add debug information to errors
bot.error do |error, ctx|
  error_info = {
    error: error.message,
    backtrace: error.backtrace.first(5),
    update_id: ctx.try(&.update.update_id),
    user_id: ctx.try(&.from.try(&.id)),
    timestamp: Time.utc
  }

  File.open("error_log.json", "a") do |f|
    f.puts error_info.to_json
  end
end
```

## Best Practices

1. **Always handle errors**: Never let errors go unhandled
2. **Log errors**: Record errors for debugging
3. **User-friendly messages**: Don't expose technical details to users
4. **Graceful degradation**: Continue operating when possible
5. **Retry transient errors**: Network and DB errors often resolve themselves
6. **Monitor error rates**: Set up alerts for high error rates
7. **Test error scenarios**: Include error cases in tests
8. **Fail fast**: Don't continue processing after critical errors
9. **Clean up resources**: Always free resources in ensure blocks
10. **Use custom errors**: Define specific error types for better handling