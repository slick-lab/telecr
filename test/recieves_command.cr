require "../src/telecr"

bot = Telecr.new("8759339325:AAGSCZhgViV9QlBqWfCYDXguPa4f77a4WFKaXA") //fake token btw have revoked it 😂 try your luck 🤧

bot.command("start") do |ctx|
    ctx.reply("Hello! I am your friendly neighborhood bot. How can I assist you today?")
end

bot.start_polling
