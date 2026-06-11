-- Database Schema for Mobile Flutter Chat
-- MySQL Version

CREATE DATABASE IF NOT EXISTS mobile_flutter_chat;
USE mobile_flutter_chat;

-- Users table
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uid VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_uid (uid),
    INDEX idx_email (email),
    INDEX idx_online (is_online)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Chats table
CREATE TABLE chats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    chat_name VARCHAR(255) DEFAULT '',
    last_message TEXT,
    last_message_time TIMESTAMP NULL,
    typing_user VARCHAR(255),
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_last_message_time (last_message_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Chat participants (many-to-many relationship)
CREATE TABLE chat_participants (
    id INT AUTO_INCREMENT PRIMARY KEY,
    chat_id INT NOT NULL,
    user_uid VARCHAR(255) NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
    UNIQUE KEY unique_chat_user (chat_id, user_uid),
    INDEX idx_user_uid (user_uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Messages table
CREATE TABLE messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    chat_id INT NOT NULL,
    sender_uid VARCHAR(255) NOT NULL,
    sender_name VARCHAR(255) NOT NULL,
    text TEXT,
    message_type ENUM('text', 'image') DEFAULT 'text',
    image_base64 TEXT,
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
    INDEX idx_chat_id (chat_id),
    INDEX idx_created_at (created_at),
    INDEX idx_sender_uid (sender_uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
