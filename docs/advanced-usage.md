# Advanced Usage & Edge Cases

This document covers advanced Telecr usage patterns and edge cases that developers may encounter.

## Advanced Handler Patterns

### Conditional Handlers

```crystal
# Only respond to messages from specific users
bot.on(:message) do |ctx|
  next unless ctx.from.try(&.id) == ADMIN_USER_ID
  # Admin-only logic
end

# Only respond in group chats
bot.command("admin", chat_type: "group") do |ctx|
  # Group admin commands
end

# Custom conditions
def during_business_hours?(ctx)
  now = Time.utc
  now.hour >= 9 && now.hour <= 17 && now.day != 0 && now.day != 6
end

bot.command("support") do |ctx|
  unless during_business_hours?(ctx)
    ctx.reply("Support is available 9 AM - 5 PM, Monday-Friday")
    return
  end
  # Handle support request
end
```

### Handler Chains

```crystal
# Multiple handlers can process the same update
bot.on(:message) do |ctx|
  # Log all messages
  log_message(ctx)
end

bot.hears(/hello/i) do |ctx|
  # Respond to greetings
  ctx.reply("Hi there!")
end

bot.hears(/bye/i) do |ctx|
  # Respond to farewells
  ctx.reply("Goodbye!")
end
```

### Dynamic Handlers

```crystal
# Register handlers based on configuration
COMMANDS = {"ping" => "pong", "hi" => "hello", "test" => "ok"}

COMMANDS.each do |cmd, response|
  bot.command(cmd) do |ctx|
    ctx.reply(response)
  end
end
```

## Advanced Context Usage

### Context State Management

```crystal
# Use context state for request-scoped data
class RequestLogger < Telecr::Core::Middleware
  def call(ctx, next_mw)
    ctx.state[:request_id] = Random::Secure.hex(8)
    ctx.state[:start_time] = Time.monotonic

    next_mw.call(ctx)

    duration = Time.monotonic - ctx.state[:start_time]
    log_request(ctx.state[:request_id], duration)
  end
end
```

### Context Enrichment

```crystal
class ContextEnricher < Telecr::Core::Middleware
  def call(ctx, next_mw)
    # Add user info
    if user = ctx.from
      ctx.state[:user_info] = fetch_user_info(user.id)
      ctx.state[:is_premium] = check_premium_status(user.id)
    end

    # Add chat info
    if chat = ctx.chat
      ctx.state[:chat_settings] = get_chat_settings(chat.id)
      ctx.state[:member_count] = get_member_count(chat.id)
    end

    next_mw.call(ctx)
  end
end
```

## Advanced Session Patterns

### Session Namespaces

```crystal
class SessionNamespace
  def initialize(@ctx : Telecr::Core::Context)
  end

  def [](key : String)
    @ctx.session["#{@namespace}:#{key}"]
  end

  def []=(key : String, value)
    @ctx.session["#{@namespace}:#{key}"] = value
  end

  def clear
    @ctx.session.each_key do |k|
      @ctx.session.delete(k) if k.starts_with?("#{@namespace}:")
    end
  end
end

# Usage
user_prefs = SessionNamespace.new(ctx, "user_prefs")
user_prefs["theme"] = "dark"
theme = user_prefs["theme"]
```

### Session Validation

```crystal
class SessionValidator < Telecr::Core::Middleware
  def call(ctx, next_mw)
    validate_session(ctx.session)
    next_mw.call(ctx)
  rescue ex : SessionError
    # Reset corrupted session
    ctx.session.clear
    ctx.reply("Session was corrupted and has been reset")
  end

  private def validate_session(session)
    # Validate session structure
    required_keys = ["user_id", "created_at"]
    required_keys.each do |key|
      unless session[key]?
        raise SessionError.new("Missing required session key: #{key}")
      end
    end
  end
end
```

### Session Compression

For large sessions:

```crystal
class SessionCompressor < Telecr::Session::Store
  def get(key : String) : Hash(String, JSON::Any)?
    if json = @store.get(key)
      # Decompress if needed
      decompress_session(json)
    end
  end

  def set(key : String, data : Hash(String, JSON::Any))
    compressed = compress_session(data)
    @store.set(key, compressed)
  end
end
```

## Advanced Keyboard Patterns

### Dynamic Keyboards

```crystal
def create_menu_keyboard(ctx)
  buttons = []

  # Always show these
  buttons << k.callback("Help", "help")
  buttons << k.callback("Settings", "settings")

  # Show admin options for admins
  if ctx.state[:is_admin]?
    buttons << k.callback("Admin Panel", "admin")
  end

  # Show premium options for premium users
  if ctx.state[:is_premium]?
    buttons << k.callback("Premium Features", "premium")
  end

  Telecr.inline do |k|
    k.row(*buttons)
  end
end
```

### Paginated Keyboards

```crystal
def create_paginated_keyboard(items, page = 0, per_page = 5)
  start_idx = page * per_page
  end_idx = start_idx + per_page
  page_items = items[start_idx...end_idx]

  Telecr.inline do |k|
    page_items.each do |item|
      k.callback(item.name, "select:#{item.id}")
    end

    # Navigation buttons
    nav_buttons = [] of Telecr::Markup::InlineButtons
    if page > 0
      nav_buttons << k.callback("⬅️ Previous", "page:#{page - 1}")
    end
    if end_idx < items.size
      nav_buttons << k.callback("Next ➡️", "page:#{page + 1}")
    end

    k.row(*nav_buttons) unless nav_buttons.empty?
  end
end
```

### Conditional Button States

```crystal
def create_task_keyboard(tasks)
  Telecr.inline do |k|
    tasks.each do |task|
      icon = task.completed ? "✅" : "⬜"
      text = "#{icon} #{task.title}"
      callback = task.completed ? "uncomplete:#{task.id}" : "complete:#{task.id}"
      k.callback(text, callback)
    end
  end
end
```

## Advanced Middleware Patterns

### Circuit Breaker Middleware

```crystal
class CircuitBreakerMiddleware < Telecr::Core::Middleware
  def initialize(@failure_threshold = 5, @timeout = 60.seconds)
    @failures = 0
    @last_failure = Time::UNIX_EPOCH
    @state = :closed
  end

  def call(ctx, next_mw)
    case @state
    when :open
      if Time.utc - @last_failure > @timeout
        @state = :half_open
      else
        raise CircuitBreakerError.new("Service unavailable")
      end
    end

    begin
      next_mw.call(ctx)
      on_success
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
    @last_failure = Time.utc

    if @failures >= @failure_threshold
      @state = :open
    end
  end
end
```

### Request Deduplication

```crystal
class DeduplicationMiddleware < Telecr::Core::Middleware
  def initialize
    @processed = Set(String).new
    @mutex = Mutex.new
  end

  def call(ctx, next_mw)
    request_id = generate_request_id(ctx)

    @mutex.synchronize do
      if @processed.includes?(request_id)
        return # Skip duplicate request
      end

      @processed.add(request_id)
    end

    begin
      next_mw.call(ctx)
    ensure
      # Clean up old request IDs after some time
      cleanup_old_requests
    end
  end
end
```

### Performance Monitoring

```crystal
class PerformanceMonitor < Telecr::Core::Middleware
  def call(ctx, next_mw)
    start_time = Time.monotonic
    start_memory = GC.stats.heap_size

    next_mw.call(ctx)

    end_time = Time.monotonic
    end_memory = GC.stats.heap_size

    duration = end_time - start_time
    memory_delta = end_memory - start_memory

    log_performance(ctx, duration, memory_delta)
  end
end
```

## Advanced Error Handling

### Structured Error Responses

```crystal
class ErrorHandler
  def handle(error : Exception, ctx : Telecr::Core::Context?)
    error_info = build_error_info(error, ctx)

    # Log structured error
    log_error(error_info)

    # Send user-friendly response
    if ctx
      send_error_response(ctx, error_info)
    end

    # Alert on critical errors
    alert_if_critical(error_info)
  end

  private def build_error_info(error, ctx)
    {
      error_type: error.class.name,
      message: error.message,
      backtrace: error.backtrace?.try(&.first(10)),
      update_id: ctx.try(&.update.update_id),
      user_id: ctx.try(&.from.try(&.id)),
      chat_id: ctx.try(&.chat.try(&.id)),
      timestamp: Time.utc,
      version: Telecr::VERSION
    }
  end
end
```

### Error Recovery Strategies

```crystal
class ResilientHandler
  def handle_with_recovery(ctx)
    attempts = 0
    max_attempts = 3

    begin
      attempts += 1
      perform_operation(ctx)
    rescue TemporaryError => ex
      if attempts < max_attempts
        sleep(2 ** attempts) # Exponential backoff
        retry
      else
        handle_permanent_failure(ctx, ex)
      end
    rescue PermanentError => ex
      handle_permanent_failure(ctx, ex)
    end
  end
end
```

## Advanced File Handling

### Streaming Downloads

```crystal
def stream_download(ctx, file_id, io : IO)
  # Get file info
  file_info = ctx.bot.client.call("getFile", {"file_id" => file_id})

  # Stream download
  ctx.bot.client.stream_download(file_info["file_path"].as_s, io)
end

# Usage
bot.on(:document) do |ctx|
  if doc = ctx.message.document
    File.open("downloads/#{doc.file_name}", "w") do |file|
      stream_download(ctx, doc.file_id, file)
    end
    ctx.reply("File downloaded!")
  end
end
```

### File Type Detection

```crystal
def detect_file_type(filename : String, content : Bytes) : String
  # Check magic bytes
  case content
  when .starts_with?("\xFF\xD8\xFF")
    "image/jpeg"
  when .starts_with?("\x89PNG")
    "image/png"
  when .starts_with?("GIF8")
    "image/gif"
  else
    # Fallback to extension
    mime_from_extension(filename)
  end
end
```

### Secure File Handling

```crystal
def secure_file_upload(ctx, file_id)
  # Validate file size
  file_info = get_file_info(file_id)
  if file_info.size > MAX_FILE_SIZE
    raise "File too large"
  end

  # Scan for viruses (if antivirus available)
  if virus_detected?(file_content)
    raise "Malicious file detected"
  end

  # Generate secure filename
  ext = File.extname(original_name)
  secure_name = "#{SecureRandom.hex(16)}#{ext}"

  # Save to secure location
  save_file(file_content, "uploads/#{secure_name}")
end
```

## Advanced Polling Techniques

### Adaptive Polling

```crystal
class AdaptivePoller
  def initialize(@bot, @min_timeout = 1, @max_timeout = 30)
    @current_timeout = 10
    @last_update = Time.utc
  end

  def poll_loop
    loop do
      updates = @bot.client.get_updates(timeout: @current_timeout)

      if updates.empty?
        # No updates, increase timeout
        @current_timeout = [@current_timeout + 1, @max_timeout].min
      else
        # Got updates, reset timeout
        @current_timeout = @min_timeout
        @last_update = Time.utc

        # Process updates
        process_updates(updates)
      end

      # Health check
      if Time.utc - @last_update > 5.minutes
        puts "No updates for 5 minutes, checking connection..."
      end
    end
  end
end
```

### Parallel Processing

```crystal
class ParallelProcessor
  def initialize(@bot, @workers = 4)
    @channel = Channel(Update).new(100)
    @workers = @workers.times.map do
      spawn { worker_loop }
    end
  end

  def process_updates(updates)
    updates.each do |update|
      @channel.send(update)
    end
  end

  private def worker_loop
    loop do
      update = @channel.receive
      process_single_update(update)
    end
  end
end
```

## Advanced Webhook Patterns

### Webhook Authentication

```crystal
class WebhookAuthenticator < Telecr::Core::Middleware
  def call(ctx, next_mw)
    # Verify request signature
    signature = ctx.state[:webhook_signature]?
    expected = generate_signature(ctx.update.to_json)

    unless secure_compare(signature, expected)
      raise "Invalid webhook signature"
    end

    next_mw.call(ctx)
  end
end
```

### Webhook Load Balancing

```crystal
# Multiple webhook endpoints for load balancing
webhook_servers = 3.times.map do |i|
  bot = Telecr.new(TOKEN)
  # Configure bot...

  server = bot.start_webhook(
    path: "/webhook/#{i}",
    port: 3000 + i
  )
end

# Load balancer distributes requests across /webhook/0, /webhook/1, /webhook/2
```

### Webhook Health Monitoring

```crystal
class WebhookHealthMonitor
  def initialize(@servers : Array(WebhookServer))
    @health_checks = {} of String => Bool
    spawn { monitor_loop }
  end

  private def monitor_loop
    loop do
      @servers.each do |server|
        health = check_server_health(server)
        @health_checks[server.id] = health

        if !health
          alert_unhealthy_server(server)
        end
      end

      sleep 30.seconds
    end
  end
end
```

## Performance Optimization

### Connection Pooling

```crystal
class ConnectionPoolMiddleware < Telecr::Core::Middleware
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

### Caching Strategies

```crystal
class CacheMiddleware < Telecr::Core::Middleware
  def initialize(@cache : Cache)
  end

  def call(ctx, next_mw)
    # Cache user data
    user_key = "user:#{ctx.from.id}"
    ctx.state[:user_data] = @cache.get(user_key) || fetch_and_cache_user(ctx.from.id)

    # Cache chat data
    chat_key = "chat:#{ctx.chat.id}"
    ctx.state[:chat_data] = @cache.get(chat_key) || fetch_and_cache_chat(ctx.chat.id)

    next_mw.call(ctx)
  end
end
```

### Memory Management

```crystal
class MemoryManager < Telecr::Core::Middleware
  def call(ctx, next_mw)
    before = GC.stats.heap_size

    next_mw.call(ctx)

    after = GC.stats.heap_size
    if after - before > 50_000_000  # 50MB increase
      GC.collect
    end
  end
end
```

## Security Considerations

### Input Validation

```crystal
def validate_input(text : String) : Bool
  # Length check
  return false if text.size > 4096

  # Content check
  return false if text =~ /<script/i  # No scripts
  return false if text =~ /javascript:/i  # No JS URLs

  true
end

bot.on(:message) do |ctx|
  unless validate_input(ctx.text)
    ctx.reply("Invalid input")
    return
  end
  # Process valid input
end
```

### Rate Limit Evasion Protection

```crystal
class RateLimitEvasionDetector < Telecr::Plugins::RateLimit
  def should_rate_limit?(ctx)
    # Check for rapid button mashing
    if ctx.update.callback_query?
      user_id = ctx.from.id
      now = Time.utc

      if @last_callback[user_id]? && now - @last_callback[user_id] < 0.1.seconds
        return true  # Too fast
      end

      @last_callback[user_id] = now
    end

    super
  end
end
```

### Secure Session Handling

```crystal
class SecureSession < Telecr::Session::Middleware
  def call(ctx, next_mw)
    # Validate session integrity
    if session_tampered?(ctx.session)
      ctx.session.clear
      ctx.reply("Session security violation detected")
      return
    end

    next_mw.call(ctx)

    # Sign session data
    sign_session(ctx.session)
  end
end
```

## Testing Advanced Features

### Integration Testing

```crystal
describe "Bot integration" do
  it "handles complex conversation flow" do
    # Simulate user interaction
    send_message("/start")
    expect_response("Welcome!")

    send_message("help")
    expect_response("Available commands:")

    # Test session persistence
    send_message("set name Alice")
    send_message("get name")
    expect_response("Your name is Alice")
  end
end
```

### Load Testing

```crystal
describe "Load testing" do
  it "handles high concurrency" do
    # Simulate multiple users
    users = 100.times.map { create_test_user }

    users.each do |user|
      spawn do
        10.times do
          send_message_from(user, "ping")
          expect_response("pong")
        end
      end
    end

    # Wait for all requests to complete
    Fiber.yield
  end
end
```

### Chaos Testing

```crystal
describe "Chaos testing" do
  it "handles network failures" do
    # Simulate network outage
    mock_network_failure

    send_message("test")
    # Should handle gracefully

    restore_network
    send_message("test")
    expect_response("Success")
  end
end
```

## Deployment Patterns

### Blue-Green Deployment

```crystal
# Deploy new version alongside old
# Route portion of traffic to new version
# Gradually increase traffic if stable
# Roll back if issues detected
```

### Canary Deployment

```crystal
# Deploy to small subset of users first
# Monitor error rates and performance
# Expand to more users if successful
```

### Rolling Deployment

```crystal
# Update instances one by one
# Ensure old and new versions can coexist
# Roll back individual instances if needed
```

## Monitoring and Observability

### Metrics Collection

```crystal
class MetricsCollector
  @@metrics = {
    requests_total: 0,
    errors_total: 0,
    response_time: 0.0,
    active_users: Set(Int64).new
  }

  def record_request(ctx, duration)
    @@metrics[:requests_total] += 1
    @@metrics[:response_time] = (@@metrics[:response_time] + duration) / 2
    @@metrics[:active_users].add(ctx.from.id)
  end

  def record_error
    @@metrics[:errors_total] += 1
  end
end
```

### Distributed Tracing

```crystal
class TracingMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    trace_id = SecureRandom.hex(16)
    ctx.state[:trace_id] = trace_id

    Log.info { "[#{trace_id}] Processing update #{ctx.update.update_id}" }

    start_span("bot_request", trace_id)
    next_mw.call(ctx)
    end_span

    Log.info { "[#{trace_id}] Request completed" }
  end
end
```

### Alerting

```crystal
class AlertManager
  def check_alerts(metrics)
    if metrics[:error_rate] > 0.05  # 5% error rate
      alert("High error rate detected: #{metrics[:error_rate]}")
    end

    if metrics[:response_time] > 5.0  # 5 second average
      alert("Slow response time: #{metrics[:response_time]}s")
    end
  end
end
```

This covers the most advanced usage patterns and edge cases for Telecr. The framework is designed to be flexible and extensible for complex bot applications.