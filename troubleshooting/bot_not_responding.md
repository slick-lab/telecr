
#  Bot Not Responding - Troubleshooting Guide

If your Telecr bot is not replying to commands or messages, follow these steps:

---

## 1. Check Bot Token
- Ensure you are using the correct **Telegram Bot Token**.
- Verify that the token is active and not revoked in [BotFather](https://t.me/botfather).

---

## 2. Confirm Bot Startup
- Did you call `bot.start_polling` or configure **webhooks** properly?
- Make sure your bot process is running and not terminated.

---

## 3. Enable Logging
- Add logging to see incoming updates:
  ```crystal
  bot.on_update do |ctx|
    puts ctx.update.inspect
  end
  ```
- This helps confirm whether Telegram is sending updates.

---

## 4. Network & Firewall
- If using **webhooks**, check that your server is reachable from Telegram.
- Ensure ports (usually 443 for HTTPS) are open.

---

## 5. Command Handlers
- Verify that your handlers match the commands:
  ```crystal
  bot.command("start") do |ctx|
    ctx.reply("Bot is alive!")
  end
  ```
- If regex or text matchers are used, confirm they are correct.

---

## 6. Session & Middleware
- If using sessions or middleware, check they are not blocking updates.
- Temporarily disable middleware to isolate the issue.

---

## 7. Crystal Runtime
- Ensure you are running the bot with a compatible **Crystal version**.
- Run `crystal --version` and check against Telecr’s requirements.

---

## 8. Debugging Checklist
-  Correct bot token  
-  Bot process running  
-  Updates received (polling/webhook)  
-  Handlers correctly defined  
-  No middleware blocking  
-  Network accessible  

---

## 9. Last Resort
- Restart the bot process.  
- Regenerate a new token via BotFather.  
- Test with a minimal bot script to confirm basic functionality.

---

> Tip: Always start with a **minimal bot** (just `/start` command) to confirm connectivity before adding complex logic
