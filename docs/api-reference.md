# API Reference

Complete reference for Telecr's API, including all classes, methods, and types.

## Core Classes

### Telecr::Core::Bot

Main bot class that handles updates and manages handlers/middleware.

#### Constructor

```crystal
Telecr.new(token : String) : Bot
```

#### Methods

##### Handler Registration

```crystal
command(name : String, &block : Context ->) : Nil
```

Register a command handler.

**Parameters:**
- `name`: Command name without `/`
- `block`: Handler block receiving `Context`

```crystal
hears(pattern : Regex | String, &block : Context ->) : Nil
```

Register a pattern-matching handler.

**Parameters:**
- `pattern`: Regex or string pattern
- `block`: Handler block

```crystal
on(type : Symbol, **filters, &block : Context ->) : Nil
```

Register a generic event handler.

**Parameters:**
- `type`: Update type symbol (:message, :callback_query, etc.)
- `filters`: Optional filters
- `block`: Handler block

##### Bot Control

```crystal
start_polling : Nil
```

Start the bot in polling mode.

```crystal
start_webhook(path : String = "/webhook", port : Int32? = nil, **options) : Webhook::Server?
```

Start the bot in webhook mode.

**Parameters:**
- `path`: Webhook path
- `port`: Port to listen on
- `options`: SSL and other options

```crystal
shutdown : Nil
```

Stop the bot and clean up resources.

##### API Methods

```crystal
set_webhook(url : String? = nil, secret_token : String? = nil) : JSON::Any
```

Set webhook URL.

**Parameters:**
- `url`: Webhook URL
- `secret_token`: Secret token for verification

##### Processing

```crystal
process(data : String | Hash | JSON::Any) : Nil
```

Process a raw update.

**Parameters:**
- `data`: Update data in various formats

##### Error Handling

```crystal
error(&block : Exception, Context? ->) : Nil
```

Register global error handler.

**Parameters:**
- `block`: Error handler block

### Telecr::Core::Context

Context object passed to all handlers containing update data and helper methods.

#### Properties

```crystal
update : Types::Update
bot : Bot
state : Hash(Symbol, JSON::Any)
session : Hash(String, JSON::Any)
match : Regex::MatchData?
```

#### Update Accessors

```crystal
message : Types::Message?
callback_query : Types::CallbackQuery?
from : Types::User?
chat : Types::Chat?
data : String?
text : String?
```

#### Response Methods

```crystal
reply(text : String, **options) : JSON::Any
```

Send a text message.

**Parameters:**
- `text`: Message text
- `options`: Additional API options

```crystal
edit_text(text : String, **options) : JSON::Any
```

Edit message text.

```crystal
answer(text : String? = nil, show_alert : Bool = false, **options) : JSON::Any
```

Answer callback query.

#### Media Methods

```crystal
photo(file, caption : String? = nil, **options) : JSON::Any
document(file, caption : String? = nil, **options) : JSON::Any
audio(file, caption : String? = nil, **options) : JSON::Any
video(file, caption : String? = nil, **options) : JSON::Any
voice(file, **options) : JSON::Any
video_note(file, **options) : JSON::Any
sticker(file, **options) : JSON::Any
animation(file, caption : String? = nil, **options) : JSON::Any
```

Send various media types.

#### File Methods

```crystal
download_file(file_id : String, path : String? = nil) : String?
```

Download file from Telegram.

**Parameters:**
- `file_id`: Telegram file ID
- `path`: Local path to save file (optional)

#### Utility Methods

```crystal
with_typing(&block) : Nil
```

Execute block with typing indicator.

```crystal
send_chat_action(action : String) : JSON::Any
```

Send chat action (typing, upload, etc.).

### Telecr::Core::Middleware

Base class for middleware.

#### Methods

```crystal
call(ctx : Context, next_mw : Context ->) : Nil
```

Execute middleware logic.

**Parameters:**
- `ctx`: Current context
- `next_mw`: Next middleware in chain

## Built-in Middleware

### Telecr::Session::Middleware

Session management middleware.

#### Constructor

```crystal
Session::Middleware.new(store : Store? = nil)
```

**Parameters:**
- `store`: Session store (defaults to MemoryStore)

### Telecr::Plugins::RateLimit

Rate limiting middleware.

#### Constructor

```crystal
RateLimit.new(**options)
```

**Parameters:**
- `options`: Rate limit configuration (:user, :chat, :global)

### Telecr::Plugins::Upload

File upload middleware.

#### Constructor

```crystal
Upload.new(shrine : Shrine, auto_download : Bool = true)
```

**Parameters:**
- `shrine`: Shrine storage instance
- `auto_download`: Auto-download files

## Keyboard Classes

### Telecr::Markup::ReplyKeyboard

Reply keyboard markup.

#### Constructor

```crystal
ReplyKeyboard.new(rows : Array(Array(Hash)), options : Hash)
```

#### Methods

```crystal
to_h : Hash
```

Convert to Telegram API format.

### Telecr::Markup::InlineKeyboard

Inline keyboard markup.

#### Constructor

```crystal
InlineKeyboard.new(rows : Array(Array(Hash)))
```

#### Methods

```crystal
to_h : Hash
```

Convert to Telegram API format.

### Builders

#### Telecr::Markup::ReplyBuilder

```crystal
row(*buttons) : ReplyBuilder
resize(bool = true) : ReplyBuilder
one_time(bool = true) : ReplyBuilder
selective(bool = true) : ReplyBuilder
placeholder(text : String) : ReplyBuilder
build : ReplyKeyboard
```

#### Telecr::Markup::InlineBuilder

```crystal
row(*buttons) : InlineBuilder
add(button) : InlineBuilder
build : InlineKeyboard
```

## Type Definitions

### Telecr::Types::Update

Root update object.

#### Properties

```crystal
update_id : Int64
message : Message?
edited_message : Message?
channel_post : Message?
edited_channel_post : Message?
inline_query : JSON::Any?
chosen_inline_result : JSON::Any?
callback_query : CallbackQuery?
shipping_query : JSON::Any?
pre_checkout_query : JSON::Any?
poll : Poll?
poll_answer : JSON::Any?
my_chat_member : JSON::Any?
chat_member : JSON::Any?
chat_join_request : JSON::Any?
managed_bot : ManagedBotUpdated?
```

#### Methods

```crystal
update_type : Symbol
from : User?
```

### Telecr::Types::Message

Message object.

#### Properties

```crystal
message_id : Int64
message_thread_id : Int32?
from : User?
sender_chat : Chat?
date : Int64
chat : Chat
text : String?
entities : Array(MessageEntity)?
caption : String?
caption_entities : Array(MessageEntity)?
reply_to_message : Message?
via_bot : User?
is_topic_message : Bool?
managed_bot_created : ManagedBotCreated?
# Media fields...
```

#### Methods

```crystal
time : Time
command? : Bool
command_name : String?
command_args : String?
reply? : Bool
has_media? : Bool
```

### Telecr::Types::User

User object.

#### Properties

```crystal
id : Int64
is_bot : Bool
first_name : String
last_name : String?
username : String?
language_code : String?
is_premium : Bool?
added_to_attachment_menu : Bool?
```

#### Methods

```crystal
full_name : String
mention : String
```

### Telecr::Types::Chat

Chat object.

#### Properties

```crystal
id : Int64
type : String
title : String?
username : String?
first_name : String?
last_name : String?
is_forum : Bool?
```

#### Methods

```crystal
private? : Bool
group? : Bool
supergroup? : Bool
channel? : Bool
```

### Telecr::Types::CallbackQuery

Callback query object.

#### Properties

```crystal
id : String
from : User
message : Message?
inline_message_id : String?
chat_instance : String
data : String?
game_short_name : String?
```

#### Methods

```crystal
from_user? : Bool
message? : Bool
inline_message? : Bool
```

## API Client

### Telecr::Api::Client

Low-level Telegram API client.

#### Constructor

```crystal
Client.new(token : String)
```

#### Methods

```crystal
call(method : String, params : Hash(String, String)? = nil) : JSON::Any
```

Call Telegram API method.

```crystal
get_updates(**options) : JSON::Any
```

Get updates (used by polling).

## Session Stores

### Telecr::Session::Store

Abstract base class for session stores.

#### Methods

```crystal
get(key : String) : Hash(String, JSON::Any)?
set(key : String, data : Hash(String, JSON::Any)) : Nil
```

### Telecr::Session::MemoryStore

In-memory session store.

#### Constructor

```crystal
MemoryStore.new
```

#### Additional Methods

```crystal
clear : Nil
size : Int32
```

### Telecr::Session::FileStore

File-based session store.

#### Constructor

```crystal
FileStore.new(directory : String)
```

**Parameters:**
- `directory`: Directory to store session files

## Webhook Classes

### Telecr::Webhook::Server

Webhook server for handling HTTP requests.

#### Constructor

```crystal
Server.new(bot : Bot, port : Int32? = nil, **options)
```

#### Methods

```crystal
run(**webhook_options) : Nil
stop : Nil
set_webhook(**options) : Nil
```

## Constants

```crystal
Telecr::VERSION : String
```

Current library version.

## Module Methods

### Telecr

```crystal
Telecr.new(token : String) : Core::Bot
Telecr.keyboard(&block : Markup::ReplyBuilder ->) : Markup::ReplyKeyboard
Telecr.inline(&block : Markup::InlineBuilder ->) : Markup::InlineKeyboard
Telecr.remove_keyboard(**options) : Hash
```

## Error Classes

Telecr uses standard Crystal exceptions plus:

- `JSON::Error` for parsing errors
- `HTTP::Error` for network errors
- `KeyError` for missing configuration

## Type Aliases

```crystal
JSONAny = JSON::Any
ContextProc = Context ->
MiddlewareProc = Context, Context -> ->
```

## Annotations

Telecr uses standard Crystal annotations and JSON::Serializable for type safety.

## Threading Model

- Polling: Single thread with async processing
- Webhooks: Multi-threaded (one fiber per request)
- Middleware: Synchronous chain execution
- Handlers: Synchronous execution per update

## Memory Management

- Uses Crystal's GC
- Sessions stored as JSON::Any for flexibility
- File downloads streamed to avoid memory bloat
- Connection pooling recommended for databases

## Performance Characteristics

- Polling: 30-second intervals, low CPU
- Webhooks: Instant delivery, higher concurrency
- Sessions: In-memory fast, file/DB slower
- Rate limiting: O(1) counter checks
- Regex matching: O(n) where n is pattern complexity

## Compatibility

- Crystal 1.0+
- Telegram Bot API 6.0+
- Standard library only (no external deps)

## Extension Points

- Custom middleware
- Custom session stores
- Custom keyboard builders
- Custom API clients
- Custom webhook servers