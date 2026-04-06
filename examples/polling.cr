# how to implement polling for development 

require 'telecr'

bot = Telecr.new("1234:432343686383629379392982829") 

bot.command("start") do |ctx| 
  ctx.reply("welcome to telecr framework") 
end 

bot.command("help") do |ctx| 
  ctx.reply("you asked for help") 
end 

bot.start_polling # your bot starts asking telegram for updates 
