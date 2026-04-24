require "../src/telecr"

bot = Telecr.new("8759339325:AAGSCZViV9QlBqWfCYDXguPa477a4WFKaXA")

bot.command("start") do |ctx|
    ctx.reply("Hello! I am your friendly neighborhood bot. How can I assist you today?")
end

bot.start_polling