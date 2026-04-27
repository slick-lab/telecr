# Keyboards

Keyboards add interactive buttons to your bot's messages. Telecr supports both reply keyboards (shown below the chat input) and inline keyboards (shown below messages).

## Reply Keyboards

Reply keyboards appear below the message input field and stay visible until dismissed.

### Basic Reply Keyboard

```crystal
keyboard = Telecr.keyboard do |k|
  k.row(
    k.text("Yes"),
    k.text("No")
  )
end

ctx.reply("Choose an option:", reply_markup: keyboard.to_h)
```

### Advanced Reply Keyboard

```crystal
keyboard = Telecr.keyboard do |k|
  k.row(
    k.text("Option 1"),
    k.text("Option 2"),
    k.text("Option 3")
  )
  k.row(
    k.request_contact("Share Contact"),
    k.request_location("Share Location")
  )
  k.row(
    k.request_poll("Create Poll")
  )
  k.resize           # Make keyboard smaller
  k.one_time         # Hide after one use
  k.selective        # Show only to mentioned users
  k.placeholder("Choose wisely...")  # Input placeholder
end

ctx.reply("What would you like to do?", reply_markup: keyboard.to_h)
```

### Keyboard Options

- `resize`: Makes keyboard compact
- `one_time`: Hides keyboard after one use
- `selective`: Shows only when user is mentioned
- `persistent`: Keeps keyboard visible (API 9.6+)
- `placeholder`: Input field placeholder text

### Button Types

#### Text Button
```crystal
k.text("Click me")
```

#### Contact Request
```crystal
k.request_contact("Share Contact")
```

#### Location Request
```crystal
k.request_location("Share Location")
```

#### Poll Request
```crystal
k.request_poll("Create Poll")           # Any poll type
k.request_poll("Quiz", poll_type: "quiz")  # Specific type
```

#### Web App
```crystal
k.web_app("Open App", "https://myapp.com")
```

### Removing Keyboards

```crystal
# Remove keyboard
ctx.reply("Keyboard removed", reply_markup: Telecr.remove_keyboard)

# Remove with selective option
ctx.reply("Removed for you", reply_markup: Telecr.remove_keyboard(selective: true))
```

## Inline Keyboards

Inline keyboards appear below messages and can be edited.

### Basic Inline Keyboard

```crystal
keyboard = Telecr.inline do |k|
  k.row(
    k.callback("Yes", "yes"),
    k.callback("No", "no")
  )
end

ctx.reply("Are you sure?", reply_markup: keyboard.to_h)
```

### Complex Inline Keyboard

```crystal
keyboard = Telecr.inline do |k|
  k.row(
    k.callback("👍 Like", "like"),
    k.callback("👎 Dislike", "dislike")
  )
  k.row(
    k.url("Visit Website", "https://example.com"),
    k.web_app("Open App", "https://myapp.com")
  )
  k.row(
    k.switch_inline("Search", "query"),
    k.pay("Pay Now")
  )
end

ctx.reply("What do you think?", reply_markup: keyboard.to_h)
```

### Handling Callback Queries

```crystal
bot.on(:callback_query) do |ctx|
  data = ctx.data

  case data
  when "yes"
    ctx.answer("You said yes!")
    # Update message if needed
    ctx.edit_text("You chose: Yes")
  when "no"
    ctx.answer("You said no!")
    ctx.edit_text("You chose: No")
  when "like"
    ctx.answer("Thanks for liking!", show_alert: true)
  end
end
```

### Button Types

#### Callback Button
Triggers a callback query to your bot:
```crystal
k.callback("Button Text", "callback_data")
```

#### URL Button
Opens a URL in the user's browser:
```crystal
k.url("Visit Site", "https://example.com")
```

#### Web App Button
Opens a web app within Telegram:
```crystal
k.web_app("Open App", "https://myapp.com")
```

#### Inline Query Switch
Opens inline query interface:
```crystal
k.switch_inline("Search", "query")  # In any chat
k.switch_inline("Search", "query", current_chat: true)  # In current chat
```

#### Pay Button
For payment integrations:
```crystal
k.pay("Pay $10")
```

## Editing Keyboards

Update keyboards after creation:

```crystal
# Remove keyboard from message
bot.on(:callback_query) do |ctx|
  if ctx.data == "done"
    ctx.edit_markup(reply_markup: {})  # Empty markup removes keyboard
  end
end
```

## Keyboard Builder API

### ReplyBuilder Methods

- `row(*buttons)` - Add a row of buttons
- `resize(bool)` - Resize keyboard
- `one_time(bool)` - One-time keyboard
- `selective(bool)` - Selective visibility
- `persistent(bool)` - Persistent keyboard
- `placeholder(text)` - Input placeholder

### InlineBuilder Methods

- `row(*buttons)` - Add a row of buttons
- `add(button)` - Add single button row

### Button Creation Methods

All builders include button creation methods:

- `text(content, style?, emoji_id?)`
- `callback(text, data, style?, emoji_id?)`
- `url(text, url, style?, emoji_id?)`
- `web_app(text, url, style?, emoji_id?)`
- `request_contact(text, style?, emoji_id?)`
- `request_location(text, style?, emoji_id?)`
- `request_poll(text, poll_type?, style?, emoji_id?)`
- `switch_inline(text, query, current_chat?, style?, emoji_id?)`
- `pay(text, style?, emoji_id?)`

## Styling and Emojis

API 9.6+ supports custom styling and emoji icons:

```crystal
keyboard = Telecr.inline do |k|
  k.row(
    k.callback("❤️ Like", "like", style: "primary", emoji_id: "custom_emoji_id"),
    k.callback("💔 Dislike", "dislike", style: "destructive")
  )
end
```

## Best Practices

### Keep it Simple
- Limit to 1-3 rows
- Use clear, concise button text
- Group related actions

### Handle All Callbacks
- Always handle all possible callback data
- Provide feedback with `ctx.answer()`
- Update message text/markup as needed

### User Experience
- Use consistent button layouts
- Provide clear next steps
- Handle back/cancel actions

### Performance
- Inline keyboards are faster than reply keyboards
- Use callback queries for dynamic content
- Avoid large keyboards on mobile

## Edge Cases

### Keyboard Persistence

Reply keyboards persist until removed or replaced:

```crystal
# This replaces the current keyboard
ctx.reply("New options:", reply_markup: new_keyboard.to_h)

# This removes it
ctx.reply("Done", reply_markup: Telecr.remove_keyboard)
```

### Callback Query Limits

- Callback data limited to 64 bytes
- Use short identifiers, store complex data in sessions

### Message Editing

Only bot messages can be edited:

```crystal
bot.on(:callback_query) do |ctx|
  # This only works if the callback is from a bot message
  ctx.edit_text("Updated text")
end
```

### Inline Message Callbacks

Callbacks from inline messages (when bot is used via @mention):

```crystal
bot.on(:callback_query) do |ctx|
  if ctx.callback_query.inline_message_id
    # Handle inline message callback
    # Note: cannot edit inline messages
  else
    # Handle regular message callback
  end
end
```

### Keyboard Size Limits

- Maximum 100 buttons per message
- Telegram may truncate very large keyboards

### Unicode and Emojis

Full Unicode support including custom emojis:

```crystal
k.callback("🚀 Launch", "launch")
k.callback("Custom", "data", emoji_id: "5368324170671202286")
```

### Selective Keyboards

Only show keyboards to specific users:

```crystal
keyboard = Telecr.keyboard do |k|
  k.row(k.text("Admin Only"))
  k.selective
end

# Only shows to replied-to user
ctx.reply("Admin command:", reply_markup: keyboard.to_h, reply_to_message_id: message_id)
```

### One-time Keyboards

Hide after first use:

```crystal
keyboard = Telecr.keyboard do |k|
  k.row(k.text("Confirm"))
  k.one_time
end
```

### Placeholder Text

Guide user input:

```crystal
keyboard = Telecr.keyboard do |k|
  k.row(k.text("Search"))
  k.placeholder("Enter search term...")
end
```

## Troubleshooting

### Keyboard Not Showing

- Check chat type (some keyboards don't work in channels)
- Verify bot permissions
- Ensure proper JSON formatting

### Callbacks Not Working

- Verify callback data matches handler
- Check for typos in data strings
- Ensure bot is running and connected

### Keyboard Too Wide

- Use `resize` option
- Reduce button count per row
- Test on mobile devices