# Changelog

## [0.2.0] - 2026-03-13

### Updated to Telegram Bot API 9.5 (March 2026)

#### New Features
- Added `sender_tag` field to Message objects for group member tags
- Added `tag`, `can_edit_tag`, and `can_manage_tags` fields to ChatMember types
- Added `icon_custom_emoji_id` support for KeyboardButton and InlineKeyboardButton
- Added `style` field to buttons for color customization
- New `sendMessageDraft` method for streaming partial messages (AI responses)
- New `setChatMemberTag` method for managing group member tags
- New `repostStory` method for business accounts

#### Enhanced Methods
- `setMyProfilePhoto` and `removeMyProfilePhoto` now fully supported
- `getUserProfileAudios` now available for fetching user audio files

#### Message Entity Updates
- Added `date_time` entity type support
- Added `unix_time` field to MessageEntity for timestamp entities

#### Bug Fixes
- Fixed type system to properly handle all API 9.5 fields
- Improved error handling for new API responses

#### Full Telegram Bot API 9.5 Compatibility
- All methods and types updated to match latest Telegram specification
- Full backward compatibility with previous API versions

---

## [0.1.0] - 2026-03-01

### Initial Release
- Core bot functionality with polling and webhook support
- Full middleware system
- Session management with disk backup
- Rate limiting plugin
- File upload plugin (shrine integration)
- Reply and inline keyboard builders
- Comprehensive Telegram type system