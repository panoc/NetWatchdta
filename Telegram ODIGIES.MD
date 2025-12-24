### **Phase 1. Create the Bot (Get the Token)**

1. Open Telegram and search for @BotFather.

2. Start a chat and send the command: /newbot

3. Follow the instructions to give your bot a name (e.g., MyHomeMonitor) and a username (must end in "bot", e.g., nwda_router_bot).

4. BotFather will send you a message containing your HTTP API Token. It looks like this: 123456789:ABCdefGhIJKlmNoPQRstUV

5. Save this! This is your TELE_BOT_TOKEN.

### **Phase 2. Get Your Chat ID**

The bot needs to know who to send the messages to.

1. Search for your new bot by its username and press Start.

2. Send a random message to the bot (like "Hello").

3.- Now, in your web browser, go to the following URL (replace <YOUR_TOKEN> with the token you got from BotFather): https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates

4.- Look for the part of the text that says "chat":{"id":XXXXXXXXX.

5.- The number (usually 9 or 10 digits) is your TELE_CHAT_ID.

**Note:** 

```sh
If you are using a Group, the Chat ID will usually start with a minus sign (e.g., -100123456789).

```

3. Usage in the netwatchda Installer

When you run the script provided in Part 1 and 2, select option 2 (Telegram) or 3 (Both). The installer will ask:

    Bot Token: Paste the long string from Step 1.

    Chat ID: Paste the number from Step 2.

4. Security Tip

    Privacy: Do not share your Bot Token with anyone. Anyone with that token can control your bot and read your notification history.


    Testing: The installer will automatically send a test message. If you don't receive it, ensure you have clicked "Start" on your bot in Telegram first, otherwise, it cannot message you.

