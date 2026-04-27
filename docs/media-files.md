# Media & Files

Telecr provides comprehensive support for sending and receiving media files, documents, and other attachments.

## Sending Media

### Photos

```crystal
# Send photo from file
ctx.photo("path/to/photo.jpg")

# Send with caption
ctx.photo("photo.jpg", caption: "Beautiful sunset!")

# Send photo with options
ctx.photo("photo.jpg",
  caption: "Caption",
  parse_mode: "Markdown",
  reply_to_message_id: 123
)
```

### Documents

```crystal
# Send document
ctx.document("document.pdf")

# Send with custom filename
ctx.document("file.txt", caption: "Important file")

# Send with thumbnail
ctx.document("video.mp4",
  caption: "Video file",
  thumb: "thumbnail.jpg"
)
```

### Other Media Types

```crystal
# Audio
ctx.audio("song.mp3", caption: "Great song!")

# Video
ctx.video("movie.mp4", caption: "Watch this!")

# Voice message
ctx.voice("message.ogg")

# Video note
ctx.video_note("note.mp4")

# Sticker
ctx.sticker("sticker.webp")

# Animation/GIF
ctx.animation("animation.gif")
```

## File Upload Options

### From File Path

```crystal
ctx.photo("./images/photo.jpg")
```

### From IO Object

```crystal
File.open("photo.jpg") do |file|
  ctx.photo(file)
end
```

### From URL

```crystal
ctx.photo("https://example.com/photo.jpg")
```

### From File ID

```crystal
# Reuse previously uploaded file
ctx.photo("AgADBAADGTo4Gz8vFA5R2Q5HqZ2j7HfS0C8ABAEAAwIAA20AA7WLBAABFgQ")
```

## Receiving Files

### Downloading Files

```crystal
bot.on(:message) do |ctx|
  if photo = ctx.message.photo
    # Download largest size
    file_path = ctx.download_file(photo.last.file_id, "downloads/photo.jpg")
    ctx.reply("Photo saved to #{file_path}")
  end
end
```

### Getting File Info

```crystal
bot.on(:document) do |ctx|
  if doc = ctx.message.document
    file_name = doc.file_name
    file_size = doc.file_size
    mime_type = doc.mime_type

    ctx.reply("Received: #{file_name} (#{file_size} bytes, #{mime_type})")
  end
end
```

### Auto-Download with Upload Plugin

```crystal
require "telecr/plugins/upload"

shrine = Shrine.new
shrine.storage = Shrine::Storage::FileSystem.new("uploads")

bot.use(Telecr::Plugins::Upload.new(
  shrine: shrine,
  auto_download: true
))

bot.on(:message) do |ctx|
  if file = ctx.state[:uploaded_file]?
    ctx.reply("File uploaded: #{file.url}")
  end
end
```

## Media Groups

Handle albums of media:

```crystal
bot.on(:message) do |ctx|
  if media_group = ctx.message.media_group_id
    # This is part of a media group
    # Collect all media with same group_id
  end
end
```

## File Size Limits

Be aware of Telegram's limits:

- Documents: 20 MB
- Photos: 10 MB
- Videos: 50 MB (bots), 2 GB (users)
- Audio: 50 MB
- Other files: 20 MB

```crystal
bot.on(:document) do |ctx|
  if doc = ctx.message.document
    if doc.file_size > 20_000_000  # 20MB
      ctx.reply("File too large! Max 20MB")
      return
    end
    # Process file
  end
end
```

## MIME Types

Handle different file types:

```crystal
bot.on(:document) do |ctx|
  if doc = ctx.message.document
    case doc.mime_type
    when "application/pdf"
      ctx.reply("PDF received")
    when "image/jpeg", "image/png"
      ctx.reply("Image document received")
    when "text/plain"
      ctx.reply("Text file received")
    else
      ctx.reply("Unknown file type: #{doc.mime_type}")
    end
  end
end
```

## Thumbnails

Handle thumbnail generation:

```crystal
# Send with custom thumbnail
ctx.document("large_file.zip",
  thumb: "thumbnail.jpg",
  caption: "Large archive"
)

# Handle received thumbnails
bot.on(:message) do |ctx|
  if doc = ctx.message.document
    if thumb = doc.thumb
      # Download thumbnail
      thumb_path = ctx.download_file(thumb.file_id, "thumbs/thumb.jpg")
    end
  end
end
```

## Voice Messages

Special handling for voice messages:

```crystal
bot.on(:voice) do |ctx|
  if voice = ctx.message.voice
    duration = voice.duration  # in seconds
    mime_type = voice.mime_type

    # Download voice message
    file_path = ctx.download_file(voice.file_id, "voice.ogg")

    ctx.reply("Voice message: #{duration}s, #{mime_type}")
  end
end
```

## Video Notes

Circular video messages:

```crystal
bot.on(:video_note) do |ctx|
  if note = ctx.message.video_note
    length = note.length  # diameter in pixels
    duration = note.duration

    # Download video note
    ctx.download_file(note.file_id, "video_note.mp4")
  end
end
```

## Stickers

Handle sticker messages:

```crystal
bot.on(:sticker) do |ctx|
  if sticker = ctx.message.sticker
    emoji = sticker.emoji
    set_name = sticker.set_name
    is_animated = sticker.is_animated

    ctx.reply("Sticker: #{emoji} from set #{set_name}")
  end
end
```

## Animations/GIFs

```crystal
bot.on(:animation) do |ctx|
  if anim = ctx.message.animation
    file_name = anim.file_name
    width = anim.width
    height = anim.height

    # Download animation
    ctx.download_file(anim.file_id, "animation.gif")
  end
end
```

## File Upload Progress

For large files, show progress:

```crystal
bot.command("upload") do |ctx|
  ctx.reply("Send me a file to upload...")

  # In a real scenario, you'd track upload progress
  # This is simplified
end

bot.on(:document) do |ctx|
  if doc = ctx.message.document
    ctx.reply("Processing upload...")

    # Simulate processing
    sleep 2

    ctx.reply("Upload complete!")
  end
end
```

## Error Handling

Handle upload/download errors:

```crystal
bot.on(:message) do |ctx|
  begin
    if photo = ctx.message.photo
      file_path = ctx.download_file(photo.last.file_id)
      ctx.reply("Downloaded to #{file_path}")
    end
  rescue ex : Exception
    ctx.reply("Download failed: #{ex.message}")
  end
end
```

## Security Considerations

### File Type Validation

```crystal
SAFE_MIME_TYPES = [
  "image/jpeg", "image/png", "image/gif",
  "application/pdf", "text/plain"
]

bot.on(:document) do |ctx|
  if doc = ctx.message.document
    unless SAFE_MIME_TYPES.includes?(doc.mime_type)
      ctx.reply("Unsafe file type!")
      return
    end
    # Process safe file
  end
end
```

### File Size Limits

```crystal
MAX_FILE_SIZE = 10_000_000  # 10MB

bot.on(:document) do |ctx|
  if doc = ctx.message.document
    if doc.file_size > MAX_FILE_SIZE
      ctx.reply("File too large!")
      return
    end
  end
end
```

### Path Traversal Protection

```crystal
# Sanitize filenames
def sanitize_filename(name : String) : String
  name.gsub(/[^a-zA-Z0-9._-]/, "_")
end

bot.on(:document) do |ctx|
  if doc = ctx.message.document
    safe_name = sanitize_filename(doc.file_name)
    ctx.download_file(doc.file_id, "uploads/#{safe_name}")
  end
end
```

## Storage Options

### Local File System

```crystal
# Simple file storage
File.open("uploads/file.jpg", "w") do |f|
  # Write downloaded content
end
```

### Cloud Storage

```crystal
# Using Shrine with S3
shrine = Shrine.new
shrine.storage = Shrine::Storage::S3.new(
  bucket: "my-bucket",
  access_key_id: ENV["AWS_ACCESS_KEY"],
  secret_access_key: ENV["AWS_SECRET_KEY"],
  region: "us-east-1"
)

bot.use(Telecr::Plugins::Upload.new(shrine: shrine))
```

### Database Storage

```crystal
# Store file metadata in database
class FileRecord
  property id : Int64
  property telegram_file_id : String
  property local_path : String?
  property url : String?
end
```

## Performance Tips

- Download large files asynchronously
- Use streaming for big files
- Cache file info when possible
- Clean up temporary files

## Edge Cases

### Missing Files

Handle cases where files are deleted or unavailable:

```crystal
begin
  ctx.download_file(file_id, "download.jpg")
rescue ex : Exception
  ctx.reply("File no longer available")
end
```

### Corrupted Downloads

Verify downloaded files:

```crystal
file_path = ctx.download_file(file_id, "temp.jpg")
unless File.exists?(file_path) && File.size(file_path) > 0
  ctx.reply("Download failed")
  return
end
```

### Large Media Groups

Handle albums with multiple photos:

```crystal
media_groups = {} of String => Array(Types::Message)

bot.on(:message) do |ctx|
  if group_id = ctx.message.media_group_id
    media_groups[group_id] ||= [] of Types::Message
    media_groups[group_id] << ctx.message

    # Process complete group when all parts received
    if media_groups[group_id].size >= expected_count
      process_media_group(media_groups[group_id])
    end
  end
end
```

### WebP Images

Telegram uses WebP for compressed images:

```crystal
bot.on(:photo) do |ctx|
  if photo = ctx.message.photo
    # Download as WebP
    webp_path = ctx.download_file(photo.last.file_id, "image.webp")

    # Convert to JPEG if needed
    `convert #{webp_path} image.jpg`
  end
end
```

### File ID Reuse

File IDs are persistent and can be reused:

```crystal
# Store file IDs for later reuse
FILE_CACHE = {} of String => String

bot.on(:photo) do |ctx|
  if photo = ctx.message.photo
    file_id = photo.last.file_id
    FILE_CACHE["user_photo_#{ctx.from.id}"] = file_id
  end
end

bot.command("mypic") do |ctx|
  if file_id = FILE_CACHE["user_photo_#{ctx.from.id}"]?
    ctx.photo(file_id)
  else
    ctx.reply("No photo saved")
  end
end
```

### Caption Length

Captions are limited to 1024 characters:

```crystal
caption = long_text[0..1023]  # Truncate if needed
ctx.photo("image.jpg", caption: caption)
```

### Spoiler Content

Mark media as spoiler (API 9.6+):

```crystal
ctx.photo("image.jpg", caption: "Spoiler!", has_spoiler: true)
```

### Message Threading

Send media to specific threads in forum groups:

```crystal
ctx.photo("image.jpg",
  message_thread_id: thread_id,
  caption: "Thread reply"
)
```