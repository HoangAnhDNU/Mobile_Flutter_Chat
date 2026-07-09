-- =============================================================================
-- Migration: chuyen luu media (voice/image) tu LONGTEXT/URL sang BLOB nhi phan
-- =============================================================================
-- Muc dich:
--   * Anh/audio se duoc luu dang BLOB nhi phan trong MySQL, khong luu tren dia.
--   * media_data    : LONGBLOB (toi da 4GB) - file nhi phan tho (m4a, jpg, png...).
--   * media_mime    : VARCHAR(50)         - MIME type ("audio/m4a", "image/jpeg").
--   * media_size    : INT                 - dung luong bytes.
--   * thumbnail_*   : MEDIUMBLOB (16MB)   - thumbnail neu co.
--   * media_url     : VARCHAR(500)        - giu lai lam fallback cho URL ngoai.
--
-- File nay duoc chia thanh 2 phan:
--   PHAN A: Chay tren database SACH (init_db se tu tao schema moi)
--   PHAN B: Chay tren database CU  (ALTER TABLE)
--
-- De ap dung migration tren DB cu:
--   mysql -u root -p mobile_flutter_chat < migration_media_to_blob.sql
-- Sau do chay: python -m app.seed_data (se insert data mau moi)
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- PHAN A: Tao schema moi (neu tao DB moi)
-- =============================================================================

CREATE TABLE IF NOT EXISTS `users` (
    `id`              INT            NOT NULL AUTO_INCREMENT,
    `email`           VARCHAR(120)   NOT NULL UNIQUE,
    `password_hash`   VARCHAR(255)   NOT NULL,
    `display_name`    VARCHAR(100)   NOT NULL,
    `avatar_url`      LONGTEXT       NULL,
    `role`            VARCHAR(20)    NOT NULL DEFAULT 'user',
    `is_online`       TINYINT(1)     NOT NULL DEFAULT 0,
    `is_locked`       TINYINT(1)     NOT NULL DEFAULT 0,
    `last_seen`       DATETIME       NULL,
    `created_at`      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `chats` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `name`         VARCHAR(100) NULL,
    `is_group`     TINYINT(1)   NOT NULL DEFAULT 0,
    `avatar_url`   LONGTEXT     NULL,
    `creator_id`   INT          NULL,
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_chats_creator` (`creator_id`),
    CONSTRAINT `fk_chats_creator` FOREIGN KEY (`creator_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `chat_participants` (
    `id`                   INT          NOT NULL AUTO_INCREMENT,
    `chat_id`              INT          NOT NULL,
    `user_id`              INT          NOT NULL,
    `role`                 VARCHAR(20)  NOT NULL DEFAULT 'member',
    `joined_at`            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `is_muted`             TINYINT(1)   NOT NULL DEFAULT 0,
    `is_hidden`            TINYINT(1)   NOT NULL DEFAULT 0,
    `is_archived`          TINYINT(1)   NOT NULL DEFAULT 0,
    `messages_cleared_at`  DATETIME     NULL,
    `auto_delete_days`     INT          NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_chat_user` (`chat_id`, `user_id`),
    KEY `idx_cp_user` (`user_id`),
    CONSTRAINT `fk_cp_chat` FOREIGN KEY (`chat_id`) REFERENCES `chats` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_cp_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `messages` (
    `id`               INT          NOT NULL AUTO_INCREMENT,
    `chat_id`          INT          NOT NULL,
    `sender_id`        INT          NULL,
    `content`          TEXT         NOT NULL,
    `type`             VARCHAR(20)  NULL DEFAULT 'text',
    `status`           VARCHAR(20)  NULL DEFAULT 'sent',

    -- Media luu dang BLOB nhi phan trong MySQL
    `media_data`       LONGBLOB     NULL,
    `media_mime`       VARCHAR(50)  NULL,
    `media_size`       INT          NULL,
    `media_url`        VARCHAR(500) NULL,         -- (legacy) URL ngoai neu co
    `thumbnail_data`   MEDIUMBLOB   NULL,         -- toi da 16MB
    `thumbnail_mime`   VARCHAR(50)  NULL,

    `reply_to_id`      INT          NULL,
    `is_deleted`       TINYINT(1)   NULL DEFAULT 0,
    `is_pinned`        TINYINT(1)   NOT NULL DEFAULT 0,
    `forwarded`        TINYINT(1)   NOT NULL DEFAULT 0,
    `image_label`      VARCHAR(50)  NULL,
    `expires_at`       DATETIME     NULL,
    `voice_duration`   INT          NULL,
    `fake_news_label`  VARCHAR(50)  NULL,
    `mentions`         JSON         NULL,
    `created_at`       DATETIME     NULL,
    `edited_at`        DATETIME     NULL,
    PRIMARY KEY (`id`),
    KEY `idx_msg_chat` (`chat_id`),
    KEY `idx_msg_sender` (`sender_id`),
    KEY `idx_msg_reply` (`reply_to_id`),
    CONSTRAINT `fk_msg_chat` FOREIGN KEY (`chat_id`) REFERENCES `chats` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_msg_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_msg_reply` FOREIGN KEY (`reply_to_id`) REFERENCES `messages` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `message_reactions` (
    `id`          INT          NOT NULL AUTO_INCREMENT,
    `message_id`  INT          NOT NULL,
    `user_id`     INT          NOT NULL,
    `emoji`       VARCHAR(20)  NOT NULL,
    `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_react_user_emoji` (`message_id`, `user_id`, `emoji`),
    KEY `idx_mr_user` (`user_id`),
    CONSTRAINT `fk_mr_msg` FOREIGN KEY (`message_id`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_mr_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `message_read_status` (
    `id`          INT      NOT NULL AUTO_INCREMENT,
    `message_id`  INT      NOT NULL,
    `user_id`     INT      NOT NULL,
    `read_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_read_msg_user` (`message_id`, `user_id`),
    KEY `idx_mrs_user` (`user_id`),
    CONSTRAINT `fk_mrs_msg` FOREIGN KEY (`message_id`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_mrs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `deleted_messages` (
    `id`          INT      NOT NULL AUTO_INCREMENT,
    `message_id`  INT      NOT NULL,
    `user_id`     INT      NOT NULL,
    `deleted_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_del_msg_user` (`message_id`, `user_id`),
    CONSTRAINT `fk_del_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `friendships` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `requester_id` INT          NOT NULL,
    `addressee_id` INT          NOT NULL,
    `status`       VARCHAR(20)  NOT NULL DEFAULT 'pending',
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `responded_at` DATETIME     NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_friend_pair` (`requester_id`, `addressee_id`),
    KEY `idx_friend_addressee` (`addressee_id`),
    CONSTRAINT `fk_friend_req` FOREIGN KEY (`requester_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_friend_addr` FOREIGN KEY (`addressee_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `blocked_users` (
    `id`         INT      NOT NULL AUTO_INCREMENT,
    `blocker_id` INT      NOT NULL,
    `blocked_id` INT      NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_block_pair` (`blocker_id`, `blocked_id`),
    CONSTRAINT `fk_block_blocker` FOREIGN KEY (`blocker_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_block_blocked` FOREIGN KEY (`blocked_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_privacy` (
    `id`              INT      NOT NULL AUTO_INCREMENT,
    `user_id`         INT      NOT NULL UNIQUE,
    `show_online`     TINYINT(1) NOT NULL DEFAULT 1,
    `show_last_seen`  TINYINT(1) NOT NULL DEFAULT 1,
    `show_read_receipts` TINYINT(1) NOT NULL DEFAULT 1,
    `updated_at`      DATETIME NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_privacy_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `group_invites` (
    `id`         INT          NOT NULL AUTO_INCREMENT,
    `chat_id`    INT          NOT NULL,
    `code`       VARCHAR(40)  NOT NULL UNIQUE,
    `created_by` INT          NULL,
    `expires_at` DATETIME     NULL,
    `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_invite_chat` (`chat_id`),
    CONSTRAINT `fk_invite_chat` FOREIGN KEY (`chat_id`) REFERENCES `chats` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_invite_user` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `activity_logs` (
    `id`         INT          NOT NULL AUTO_INCREMENT,
    `actor_id`   INT          NULL,
    `action`     VARCHAR(50)  NOT NULL,
    `target_id`  INT          NULL,
    `target_type` VARCHAR(50) NULL,
    `detail`     TEXT         NULL,
    `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_log_actor` (`actor_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =============================================================================
-- PHAN B: Migration cho database CU (ALTER TABLE)
-- =============================================================================
-- Chi chay nhung lenh ALTER ben duoi neu database da co du lieu cu va
-- media_url dang luu LONGTEXT. Neu moi tao DB moi, khong can chay phan nay.
--
-- Tat ca cac lenh ALTER deu co IF EXISTS/IF NOT EXISTS logic o seed_data.py,
-- o day viet cu the de admin review truoc khi chay.
-- =============================================================================

-- 1) Them cot BLOB moi vao messages
ALTER TABLE `messages` ADD COLUMN `media_data`       LONGBLOB     NULL AFTER `status`;
ALTER TABLE `messages` ADD COLUMN `media_mime`       VARCHAR(50)  NULL AFTER `media_data`;
ALTER TABLE `messages` ADD COLUMN `media_size`       INT          NULL AFTER `media_mime`;
ALTER TABLE `messages` ADD COLUMN `thumbnail_data`   MEDIUMBLOB   NULL AFTER `media_size`;
ALTER TABLE `messages` ADD COLUMN `thumbnail_mime`   VARCHAR(50)  NULL AFTER `thumbnail_data`;

-- 2) Chuyen kieu cot media_url (cu: LONGTEXT) thanh VARCHAR(500).
--    LUU Y: tat ca data URI base64 cu trong media_url se bi CAT bo khi chuyen
--    kieu. Can backup truoc neu muon giu!
--    Neu muon giu data cu, hay SUA model Message.to_dict() de giu media_url
--    nhu cu va khong chay lenh nay.
ALTER TABLE `messages` MODIFY COLUMN `media_url` VARCHAR(500) NULL;

-- 3) Them cot role / is_locked neu thieu (chay nhieu lan van OK)
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `role` VARCHAR(20) NOT NULL DEFAULT 'user';
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `is_locked` TINYINT(1) NOT NULL DEFAULT 0;

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- Verify schema sau migration:
-- =============================================================================
-- DESCRIBE messages;
-- Cac cot can thay:
--   media_data      longblob    YES
--   media_mime      varchar(50) YES
--   media_size      int         YES
--   thumbnail_data  mediumblob  YES
--   thumbnail_mime  varchar(50) YES
--   media_url       varchar(500) YES
-- =============================================================================