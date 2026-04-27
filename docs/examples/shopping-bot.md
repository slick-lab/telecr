# Shopping Bot Example

A bot that manages shopping lists with sessions and keyboards.

```crystal
require "telecr"
require "telecr/session"

bot = Telecr.new(ENV["BOT_TOKEN"])

# Add session middleware
bot.use(Telecr::Session::Middleware.new)

# Start command
bot.command("start") do |ctx|
  keyboard = Telecr.keyboard do |k|
    k.row(k.text("🛒 View List"), k.text("➕ Add Item"))
    k.row(k.text("❌ Clear List"), k.text("📊 Stats"))
    k.one_time
  end

  ctx.reply("Welcome to Shopping Bot! Choose an action:", reply_markup: keyboard.to_h)
end

# Handle keyboard buttons
bot.on(:message) do |ctx|
  next unless ctx.text

  case ctx.text
  when "🛒 View List"
    show_list(ctx)
  when "➕ Add Item"
    ctx.session["awaiting_item"] = true
    ctx.reply("What item would you like to add?")
  when "❌ Clear List"
    ctx.session["shopping_list"] = [] of JSON::Any
    ctx.reply("Shopping list cleared! 🗑️")
  when "📊 Stats"
    show_stats(ctx)
  else
    handle_item_input(ctx)
  end
end

def show_list(ctx)
  list = ctx.session["shopping_list"].as_a? || [] of JSON::Any

  if list.empty?
    ctx.reply("Your shopping list is empty. Add some items! ➕")
  else
    items = list.map_with_index { |item, i| "#{i + 1}. #{item["name"]} (#{item["quantity"]})" }
    message = "🛒 Your Shopping List:\n\n#{items.join("\n")}"

    keyboard = Telecr.inline do |k|
      list.each_with_index do |item, i|
        k.callback("✅ #{item["name"]}", "complete:#{i}")
      end
    end

    ctx.reply(message, reply_markup: keyboard.to_h)
  end
end

def show_stats(ctx)
  list = ctx.session["shopping_list"].as_a? || [] of JSON::Any
  total_items = list.sum { |item| item["quantity"].as_i }
  unique_items = list.size

  ctx.reply("📊 List Statistics:\n• Total items: #{total_items}\n• Unique items: #{unique_items}")
end

def handle_item_input(ctx)
  return unless ctx.session["awaiting_item"]?

  item_name = ctx.text.strip
  if item_name.empty?
    ctx.reply("Please enter a valid item name.")
    return
  end

  # Ask for quantity
  ctx.session["pending_item"] = item_name
  ctx.session.delete("awaiting_item")

  keyboard = Telecr.inline do |k|
    k.row(
      k.callback("1", "qty:1"),
      k.callback("2", "qty:2"),
      k.callback("3", "qty:3")
    )
    k.row(k.callback("Custom", "qty:custom"))
  end

  ctx.reply("How many #{item_name} do you need?", reply_markup: keyboard.to_h)
end

# Handle inline keyboard callbacks
bot.on(:callback_query) do |ctx|
  data = ctx.data

  if data.starts_with?("complete:")
    index = data[9..].to_i
    list = ctx.session["shopping_list"].as_a? || [] of JSON::Any

    if index < list.size
      item = list[index]
      list.delete_at(index)
      ctx.session["shopping_list"] = list

      ctx.answer("Removed #{item["name"]} from list!")
      show_list(ctx)  # Refresh the list
    end

  elsif data.starts_with?("qty:")
    quantity = data[4..]

    if quantity == "custom"
      ctx.session["awaiting_quantity"] = true
      ctx.answer("Enter quantity as a number:")
    else
      add_item_to_list(ctx, ctx.session["pending_item"].as_s, quantity.to_i)
      ctx.session.delete("pending_item")
    end

  end
end

# Handle custom quantity input
bot.on(:message) do |ctx|
  next unless ctx.session["awaiting_quantity"]?

  if quantity = ctx.text.to_i?
    add_item_to_list(ctx, ctx.session["pending_item"].as_s, quantity)
    ctx.session.delete("pending_item")
    ctx.session.delete("awaiting_quantity")
  else
    ctx.reply("Please enter a valid number.")
  end
end

def add_item_to_list(ctx, name : String, quantity : Int)
  list = ctx.session["shopping_list"].as_a? || [] of JSON::Any

  # Check if item already exists
  existing = list.find { |item| item["name"].as_s == name }

  if existing
    existing["quantity"] = existing["quantity"].as_i + quantity
  else
    list << {"name" => name, "quantity" => quantity}
  end

  ctx.session["shopping_list"] = list
  ctx.reply("Added #{quantity}x #{name} to your list! ✅")
end

# Error handling
bot.error do |error, ctx|
  puts "Error: #{error.message}"
  ctx.try(&.reply("Sorry, something went wrong. Please try again."))
end

bot.start_polling
```

## Features Demonstrated

- Session management for user data persistence
- Reply keyboards for main navigation
- Inline keyboards for interactive lists
- Multi-step conversations
- Error handling
- State management across messages

## Running the Shopping Bot

1. Set your bot token
2. Run: `crystal run shopping_bot.cr`
3. Use `/start` to begin
4. Add items, view lists, and manage your shopping!