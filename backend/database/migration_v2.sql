-- Migration V2: Add new features
-- Run this AFTER schema.sql

USE mobile_flutter_chat;

-- Add group_avatar to chats table
ALTER TABLE chats
    ADD COLUMN group_avatar LONGTEXT AFTER chat_name;

-- Modify message_type to support voice
ALTER TABLE messages
    MODIFY COLUMN message_type ENUM('text', 'image', 'voice') DEFAULT 'text';

-- Add new columns to messages table
ALTER TABLE messages
    ADD COLUMN voice_base64 LONGTEXT AFTER image_base64,
    ADD COLUMN voice_duration INT DEFAULT 0 AFTER voice_base64,
    ADD COLUMN reply_to_id INT NULL AFTER voice_duration,
    ADD COLUMN reply_to_text TEXT AFTER reply_to_id,
    ADD COLUMN reply_to_sender VARCHAR(255) AFTER reply_to_text,
    ADD COLUMN delivery_status ENUM('sent', 'delivered', 'read') DEFAULT 'sent' AFTER reply_to_sender,
    ADD COLUMN is_deleted_for_everyone BOOLEAN DEFAULT FALSE AFTER is_edited,
    ADD COLUMN is_pinned BOOLEAN DEFAULT FALSE AFTER is_deleted_for_everyone,
    ADD INDEX idx_reply_to (reply_to_id),
    ADD INDEX idx_pinned (is_pinned);

-- Message reactions table
CREATE TABLE IF NOT EXISTS message_reactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message_id INT NOT NULL,
    user_uid VARCHAR(255) NOT NULL,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    UNIQUE KEY unique_reaction (message_id, user_uid, emoji),
    INDEX idx_message_id (message_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Message read status (for delivery receipts)
CREATE TABLE IF NOT EXISTS message_read_status (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message_id INT NOT NULL,
    user_uid VARCHAR(255) NOT NULL,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    UNIQUE KEY unique_read (message_id, user_uid),
    INDEX idx_message_id (message_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Blocked users table
CREATE TABLE IF NOT EXISTS blocked_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    blocker_uid VARCHAR(255) NOT NULL,
    blocked_uid VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_block (blocker_uid, blocked_uid),
    INDEX idx_blocker (blocker_uid),
    INDEX idx_blocked (blocked_uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Muted chats table
CREATE TABLE IF NOT EXISTS muted_chats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_uid VARCHAR(255) NOT NULL,
    chat_id INT NOT NULL,
    muted_until TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
    UNIQUE KEY unique_mute (user_uid, chat_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Deleted messages (for "delete for me" feature)
CREATE TABLE IF NOT EXISTS deleted_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message_id INT NOT NULL,
    user_uid VARCHAR(255) NOT NULL,
    deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    UNIQUE KEY unique_delete (message_id, user_uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add is_muted and is_archived to chat_participants
ALTER TABLE chat_participants
    ADD COLUMN is_muted BOOLEAN DEFAULT FALSE AFTER joined_at,
    ADD COLUMN is_archived BOOLEAN DEFAULT FALSE AFTER is_muted,
    ADD COLUMN unread_count INT DEFAULT 0 AFTER is_archived;
