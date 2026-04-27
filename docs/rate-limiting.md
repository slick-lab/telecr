# Rate Limiting

Rate limiting prevents abuse by controlling how often users, chats, or the entire bot can send requests. Telecr includes a built-in rate limiting middleware that integrates seamlessly with your bot.

## Basic Setup

```crystal
require "telecr/plugins/rate_limit"

bot.use(Telecr::Plugins::RateLimit.new(
  user: {max: 5, per: 10},   # 5 requests per 10 seconds per user
  chat: {max: 20, per: 60},  # 20 requests per minute per chat
  global: {max: 100, per: 1} # 100 requests per second globally
))
```

## Configuration Options

### User Limits

Limit individual user activity:

```crystal
user: {max: 10, per: 30}  # 10 requests per 30 seconds
```

### Chat Limits

Limit activity in groups/channels:

```crystal
chat: {max: 50, per: 120}  # 50 requests per 2 minutes
```

### Global Limits

Limit total bot activity:

```crystal
global: {max: 200, per: 1}  # 200 requests per second
```

### Combined Limits

Use multiple limits together:

```crystal
bot.use(Telecr::Plugins::RateLimit.new(
  user: {max: 3, per: 5},     # Strict per-user
  chat: {max: 30, per: 60},   # Moderate per-chat
  global: {max: 500, per: 1}  # Loose global
))
```

## How It Works

The middleware tracks requests using counters with time-to-live (TTL):

- **User counters**: `user:{user_id}` - expires after `per` seconds
- **Chat counters**: `chat:{chat_id}` - expires after `per` seconds
- **Global counter**: `global` - expires after `per` seconds

When a limit is exceeded, requests are blocked with a default message.

## Custom Responses

Customize the rate limit response:

```crystal
class CustomRateLimit < Telecr::Plugins::RateLimit
  def rate_limit_response(ctx : Core::Context)
    remaining = calculate_remaining_time(ctx)
    ctx.reply("⏳ Too many requests! Try again in #{remaining} seconds.")
  end
end

bot.use(CustomRateLimit.new(user: {max: 5, per: 10}))
```

## Selective Rate Limiting

Apply rate limiting only to certain updates:

```crystal
class SelectiveRateLimit < Telecr::Plugins::RateLimit
  def should_rate_limit?(ctx : Core::Context) : Bool
    # Don't rate limit commands
    return false if ctx.message.try(&.command?)

    # Don't rate limit callbacks
    return false if ctx.callback_query

    # Rate limit everything else
    true
  end
end
```

## Whitelisting

Allow certain users to bypass limits:

```crystal
class WhitelistRateLimit < Telecr::Plugins::RateLimit
  WHITELIST = [123456789, 987654321]  # User IDs

  def should_rate_limit?(ctx : Core::Context) : Bool
    return false if ctx.from.try { |u| WHITELIST.includes?(u.id) }
    super
  end
end
```

## Dynamic Limits

Adjust limits based on context:

```crystal
class DynamicRateLimit < Telecr::Plugins::RateLimit
  def initialize
    super(
      user: {max: 10, per: 30},
      chat: {max: 50, per: 60}
    )
  end

  def check_limit(type : Symbol, key : String, ctx : Core::Context) : Bool
    # Premium users get higher limits
    if type == :user && premium_user?(ctx)
      limit_config = {max: 50, per: 30}
    else
      limit_config = @options[type]?
    end

    return false unless limit_config

    counter = @counters[type].get(key)
    current = counter ? counter.to_s.to_i : 0
    current >= limit_config[:max]
  end
end
```

## Monitoring Rate Limits

Track rate limit hits:

```crystal
class MonitoringRateLimit < Telecr::Plugins::RateLimit
  getter hits = 0

  def rate_limit_response(ctx : Core::Context)
    @hits += 1
    super
  end

  def report
    puts "Rate limit hits: #{@hits}"
  end
end
```

## Storage Backends

By default, rate limit counters use `MemoryStore`. For persistence across restarts:

```crystal
# File-based storage
store = Telecr::Session::FileStore.new("rate_limits/")
rate_limit = Telecr::Plugins::RateLimit.new(
  user: {max: 5, per: 10},
  store: store
)
```

## Advanced Configuration

### Burst Handling

Allow short bursts but maintain average rate:

```crystal
# Allow 10 requests immediately, then 1 per second
burst_limit = Telecr::Plugins::RateLimit.new(
  user: {max: 10, per: 1}
)
```

### Sliding Windows

Use sliding window algorithm for more precise rate limiting:

```crystal
class SlidingWindowRateLimit < Telecr::Plugins::RateLimit
  def check_limit(type : Symbol, key : String, ctx : Core::Context) : Bool
    # Implementation would track timestamps of requests
    # and check how many fall within the time window
    # This is more complex but more accurate
  end
end
```

## Rate Limit Headers

For webhook mode, you might want to include rate limit info:

```crystal
class HeaderRateLimit < Telecr::Plugins::RateLimit
  def call(ctx : Core::Context, next_mw : Core::Context ->)
    # Add headers to webhook response
    if ctx.bot.webhook_server
      # This would require extending the webhook response
      # to include rate limit headers
    end

    super
  end
end
```

## Integration with Other Middleware

Rate limiting works well with other middleware:

```crystal
# Order matters: logging first, then rate limiting, then sessions
bot.use(LoggingMiddleware.new)
bot.use(RateLimitMiddleware.new)
bot.use(SessionMiddleware.new)
bot.use(AuthMiddleware.new)
```

## Performance Considerations

- In-memory counters are fast but don't survive restarts
- File-based storage is persistent but slower
- Database storage scales better but adds latency
- Consider Redis for high-traffic bots

## Edge Cases

### Clock Skew

Handle server time changes:

```crystal
# Use monotonic time for counters
def increment_counters(ctx : Core::Context)
  now = Time.monotonic.to_i

  # Use monotonic time for TTL calculations
end
```

### Distributed Bots

For multiple bot instances, use shared storage:

```crystal
# Redis for distributed rate limiting
require "redis"

class RedisRateLimit < Telecr::Plugins::RateLimit
  def initialize(@redis : Redis::Client, **options)
    super(**options)
  end

  def check_limit(type : Symbol, key : String, ctx : Core::Context) : Bool
    redis_key = "ratelimit:#{type}:#{key}"
    current = @redis.incr(redis_key)

    if current == 1
      @redis.expire(redis_key, @options[type][:per])
    end

    current > @options[type][:max]
  end
end
```

### Rate Limit Bypass

Handle attempts to bypass rate limits:

```crystal
# Detect rapid fire attempts
class AntiSpamRateLimit < Telecr::Plugins::RateLimit
  def should_rate_limit?(ctx : Core::Context) : Bool
    # Check for suspicious patterns
    if suspicious_activity?(ctx)
      return true  # Always rate limit suspicious activity
    end

    super
  end
end
```

### Graceful Degradation

Handle rate limit storage failures:

```crystal
class ResilientRateLimit < Telecr::Plugins::RateLimit
  def check_limit(type : Symbol, key : String, ctx : Core::Context) : Bool
    begin
      super
    rescue ex : Exception
      # Log error but allow request
      puts "Rate limit check failed: #{ex.message}"
      false
    end
  end
end
```

## Testing Rate Limits

Test rate limiting behavior:

```crystal
describe "Rate limiting" do
  it "blocks excessive requests" do
    bot = Telecr.new("token")
    bot.use(Telecr::Plugins::RateLimit.new(user: {max: 2, per: 10}))

    # First two requests should succeed
    ctx1 = create_context(user_id: 123)
    bot.process_update(ctx1.update)

    ctx2 = create_context(user_id: 123)
    bot.process_update(ctx2.update)

    # Third should be blocked
    ctx3 = create_context(user_id: 123)
    bot.process_update(ctx3.update)

    # Verify rate limit response was sent
  end
end
```

## Common Patterns

### API Rate Limiting

```crystal
# Stricter limits for API-like commands
api_commands = ["/search", "/lookup", "/query"]

class ApiRateLimit < Telecr::Plugins::RateLimit
  def should_rate_limit?(ctx : Core::Context) : Bool
    return false unless ctx.message.try(&.command?)

    command = ctx.message.command_name
    return true if api_commands.includes?("/#{command}")

    false
  end
end

bot.use(ApiRateLimit.new(user: {max: 1, per: 5}))  # 1 API call per 5 seconds
```

### Group Management

```crystal
# Special limits for group management commands
group_commands = ["/ban", "/kick", "/mute"]

class GroupRateLimit < Telecr::Plugins::RateLimit
  def should_rate_limit?(ctx : Core::Context) : Bool
    return false unless ctx.chat.try(&.group?)
    return false unless ctx.message.try(&.command?)

    command = ctx.message.command_name
    return true if group_commands.includes?("/#{command}")

    false
  end
end
```

### Premium Features

```crystal
# Higher limits for premium users
class PremiumRateLimit < Telecr::Plugins::RateLimit
  PREMIUM_USERS = [123, 456]

  def check_limit(type : Symbol, key : String, ctx : Core::Context) : Bool
    if type == :user && PREMIUM_USERS.includes?(ctx.from.id)
      # 10x higher limits for premium
      limit_config = {max: @options[:user][:max] * 10, per: @options[:user][:per]}
    else
      limit_config = @options[type]?
    end

    return false unless limit_config

    # Check limit with config
    counter = @counters[type].get(key)
    current = counter ? counter.to_s.to_i : 0
    current >= limit_config[:max]
  end
end
```

## Monitoring and Alerts

Set up monitoring for rate limit effectiveness:

```crystal
class MonitoredRateLimit < Telecr::Plugins::RateLimit
  @stats = {
    total_requests: 0,
    blocked_requests: 0,
    top_abusers: {} of Int64 => Int32
  }

  def call(ctx : Core::Context, next_mw : Core::Context ->)
    @stats[:total_requests] += 1

    if should_rate_limit?(ctx) && limit_exceeded?(ctx)
      @stats[:blocked_requests] += 1

      if user_id = ctx.from.try(&.id)
        @stats[:top_abusers][user_id] ||= 0
        @stats[:top_abusers][user_id] += 1
      end

      return rate_limit_response(ctx)
    end

    increment_counters(ctx)
    next_mw.call(ctx)
  end

  def report
    puts "Rate Limit Stats:"
    puts "Total requests: #{@stats[:total_requests]}"
    puts "Blocked: #{@stats[:blocked_requests]}"
    puts "Block rate: #{(@stats[:blocked_requests].to_f / @stats[:total_requests] * 100).round(2)}%"

    puts "Top abusers:"
    @stats[:top_abusers].each do |user_id, count|
      puts "User #{user_id}: #{count} blocks"
    end
  end
end
```