# Sessions

Sessions allow you to store user-specific data that persists across messages and bot restarts. This is essential for multi-step conversations, user preferences, and stateful interactions.

## Basic Session Usage

```crystal
require "telecr/session"

# Add session middleware
bot.use(Telecr::Session::Middleware.new)

bot.command("start") do |ctx|
  ctx.session["name"] = ctx.from.first_name
  ctx.reply("Hello, #{ctx.session["name"]}!")
end

bot.command("remember") do |ctx|
  name = ctx.session["name"]?
  if name
    ctx.reply("I remember you, #{name}!")
  else
    ctx.reply("I don't know your name yet. Use /start first.")
  end
end
```

## Session Data Types

Sessions store `JSON::Any` values, which can represent:

```crystal
# Strings
ctx.session["name"] = "John"

# Numbers
ctx.session["age"] = 25
ctx.session["score"] = 95.5

# Booleans
ctx.session["is_admin"] = true

# Arrays
ctx.session["favorites"] = ["pizza", "code", "cats"]

# Objects/Hashes
ctx.session["preferences"] = {"theme" => "dark", "lang" => "en"}

# Access with type safety
name = ctx.session["name"].as_s
age = ctx.session["age"].as_i
favorites = ctx.session["favorites"].as_a.map(&.as_s)
```

## Session Stores

### Memory Store (Default)

Stores data in memory - lost on restart:

```crystal
store = Telecr::Session::MemoryStore.new
bot.use(Telecr::Session::Middleware.new(store))
```

### File System Store

Persists to disk:

```crystal
store = Telecr::Session::FileStore.new("sessions/")
bot.use(Telecr::Session::Middleware.new(store))
```

### Custom Store

Implement your own store:

```crystal
class DatabaseStore < Telecr::Session::Store
  def get(key : String) : Hash(String, JSON::Any)?
    # Load from database
    db_result = db.query("SELECT data FROM sessions WHERE key = ?", key)
    if row = db_result.first?
      JSON.parse(row["data"].as_s).as_h
    end
  end

  def set(key : String, data : Hash(String, JSON::Any))
    # Save to database
    json_data = data.to_json
    db.exec("INSERT OR REPLACE INTO sessions (key, data) VALUES (?, ?)", key, json_data)
  end
end

bot.use(Telecr::Session::Middleware.new(DatabaseStore.new))
```

## Session Keys

By default, sessions use the user ID as the key. You can customize this:

```crystal
# Per-user sessions (default)
# Key: user_id

# Per-chat sessions
class ChatSessionMiddleware < Telecr::Session::Middleware
  private def get_user_id(ctx) : String?
    ctx.chat.try(&.id.to_s)  # Use chat ID instead of user ID
  end
end

# Combined user-chat sessions
class UserChatSessionMiddleware < Telecr::Session::Middleware
  private def get_user_id(ctx) : String?
    "#{ctx.from.try(&.id)}-#{ctx.chat.try(&.id)}"
  end
end
```

## Session Expiration

Set TTL for session data:

```crystal
store = Telecr::Session::MemoryStore.new
store.default_ttl = 24.hours  # Expire after 24 hours

bot.use(Telecr::Session::Middleware.new(store))
```

## Multi-Step Conversations

Use sessions for wizards and forms:

```crystal
bot.command("setup") do |ctx|
  ctx.session["step"] = "name"
  ctx.reply("What's your name?")
end

bot.on(:message) do |ctx|
  next unless ctx.session["step"]? == "name"

  name = ctx.text
  ctx.session["name"] = name
  ctx.session["step"] = "age"
  ctx.reply("Nice to meet you, #{name}! How old are you?")
end

bot.on(:message) do |ctx|
  next unless ctx.session["step"]? == "age"

  age = ctx.text.to_i?
  if age && age > 0
    ctx.session["age"] = age
    ctx.session.delete("step")
    ctx.reply("Setup complete! You're #{age} years old.")
  else
    ctx.reply("Please enter a valid age.")
  end
end
```

## User Preferences

Store and retrieve user settings:

```crystal
bot.command("settings") do |ctx|
  keyboard = Telecr.inline do |k|
    k.row(
      k.callback("Theme: #{ctx.session["theme"]? || "light"}", "toggle_theme"),
      k.callback("Language: #{ctx.session["lang"]? || "en"}", "change_lang")
    )
  end

  ctx.reply("Settings:", reply_markup: keyboard.to_h)
end

bot.on(:callback_query) do |ctx|
  case ctx.data
  when "toggle_theme"
    current = ctx.session["theme"]? || "light"
    new_theme = current == "light" ? "dark" : "light"
    ctx.session["theme"] = new_theme
    ctx.answer("Theme changed to #{new_theme}")
    # Update message...
  end
end
```

## Shopping Cart Example

```crystal
bot.command("cart") do |ctx|
  cart = ctx.session["cart"].as_a? || [] of JSON::Any
  if cart.empty?
    ctx.reply("Your cart is empty")
  else
    total = cart.sum { |item| item["price"].as_f }
    items = cart.map { |item| "#{item["name"]}: $#{item["price"]}" }.join("\n")
    ctx.reply("Cart:\n#{items}\nTotal: $#{total}")
  end
end

bot.command("add") do |ctx|
  args = ctx.command_args
  if args && args.includes?(" ")
    name, price_str = args.split(" ", 2)
    price = price_str.to_f?

    if price && price > 0
      cart = ctx.session["cart"].as_a? || [] of JSON::Any
      cart << {"name" => name, "price" => price}
      ctx.session["cart"] = cart
      ctx.reply("Added #{name} for $#{price}")
    else
      ctx.reply("Invalid price")
    end
  else
    ctx.reply("Usage: /add <item> <price>")
  end
end
```

## Session Cleanup

Remove old or unnecessary session data:

```crystal
bot.command("reset") do |ctx|
  ctx.session.clear
  ctx.reply("Session reset!")
end

# Clean up specific keys
bot.command("logout") do |ctx|
  ctx.session.delete("user_token")
  ctx.session.delete("login_time")
  ctx.reply("Logged out")
end
```

## Session Migration

Handle session data changes between versions:

```crystal
class MigrationMiddleware < Telecr::Core::Middleware
  def call(ctx, next_mw)
    # Migrate old session format
    if ctx.session["old_key"]?
      ctx.session["new_key"] = ctx.session["old_key"]
      ctx.session.delete("old_key")
    end

    next_mw.call(ctx)
  end
end

bot.use(MigrationMiddleware.new)
```

## Performance Considerations

- Keep session data small
- Use efficient serialization
- Cache frequently accessed data
- Clean up expired sessions

## Security

- Don't store sensitive data in sessions
- Use encryption for sensitive session stores
- Validate session data on access
- Implement session fixation protection

## Edge Cases

### Concurrent Access

Handle race conditions in concurrent environments:

```crystal
# Use locks for critical sections
bot.command("transfer") do |ctx|
  # This could cause issues if called simultaneously
  balance = ctx.session["balance"].as_f
  amount = 10.0

  if balance >= amount
    ctx.session["balance"] = balance - amount
    # Transfer logic...
  end
end
```

### Session Loss

Handle cases where sessions are lost:

```crystal
bot.on(:message) do |ctx|
  unless ctx.session["initialized"]?
    # Re-initialize session
    ctx.session["initialized"] = true
    ctx.session["balance"] = 100.0
  end
end
```

### Large Sessions

Split large data or use external storage:

```crystal
# Instead of storing large objects
ctx.session["user_data_id"] = user_data_id

# Load from database when needed
user_data = load_user_data(ctx.session["user_data_id"])
```

### Session Key Conflicts

Avoid key conflicts:

```crystal
# Use namespaced keys
ctx.session["user:name"] = "John"
ctx.session["user:email"] = "john@example.com"
ctx.session["cart:items"] = []
ctx.session["cart:total"] = 0
```

### Type Safety

Handle type mismatches gracefully:

```crystal
def get_balance(ctx) : Float64
  ctx.session["balance"]?.try(&.as_f?) || 0.0
end

def set_balance(ctx, amount : Float64)
  ctx.session["balance"] = amount
end
```

### Session Serialization Errors

Handle JSON serialization issues:

```crystal
begin
  ctx.session["complex_object"] = my_object
rescue ex : JSON::Error
  # Fallback to string representation
  ctx.session["complex_object"] = my_object.to_s
end
```

## Testing Sessions

Test session behavior:

```crystal
describe "Session middleware" do
  it "persists data across messages" do
    # Simulate two messages from same user
    ctx1 = create_context(user_id: 123)
    ctx1.session["test"] = "value"

    ctx2 = create_context(user_id: 123)
    ctx2.session["test"].should eq "value"
  end
end
```

## Database Schema Example

For database-backed sessions:

```sql
CREATE TABLE sessions (
  key TEXT PRIMARY KEY,
  data TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sessions_updated ON sessions(updated_at);
```

## Redis Store Example

Using Redis for sessions:

```crystal
require "redis"

class RedisStore < Telecr::Session::Store
  def initialize(@redis : Redis::Client)
  end

  def get(key : String) : Hash(String, JSON::Any)?
    json = @redis.get("session:#{key}")
    json ? JSON.parse(json).as_h : nil
  end

  def set(key : String, data : Hash(String, JSON::Any))
    @redis.set("session:#{key}", data.to_json, ex: 24.hours.to_i)
  end
end
```

## Monitoring Sessions

Track session usage:

```crystal
class SessionMonitor < Telecr::Core::Middleware
  @stats = {} of String => Int32

  def call(ctx, next_mw)
    user_id = ctx.from.try(&.id.to_s)
    if user_id
      @stats[user_id] ||= 0
      @stats[user_id] += 1
    end

    next_mw.call(ctx)
  end

  def report
    puts "Session stats: #{@stats}"
  end
end
```