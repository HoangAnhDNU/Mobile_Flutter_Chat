const express = require('express');
const Chat = require('../models/Chat');
const Message = require('../models/Message');
const User = require('../models/User');

const router = express.Router();

// Get all chats for current user
router.get('/', async (req, res) => {
  try {
    const { uid } = req.query;
    if (!uid) {
      return res.status(400).json({ error: 'Missing uid' });
    }

    const chats = await Chat.findByUserUid(uid);

    const chatsWithParticipants = await Promise.all(
      chats.map(async (chat) => {
        const participants = await Chat.getParticipants(chat.id);
        const otherUid = participants.find(p => p !== uid) || '';
        
        let otherUser = null;
        if (otherUid) {
          otherUser = await User.findByUid(otherUid);
        }

        return {
          id: chat.id,
          chatName: chat.chat_name,
          lastMessage: chat.last_message,
          lastMessageTime: chat.last_message_time,
          typingUser: chat.typing_user,
          participants,
          otherUser: otherUser ? {
            uid: otherUser.uid,
            displayName: otherUser.display_name,
            avatarUrl: otherUser.avatar_url,
            isOnline: otherUser.is_online
          } : null
        };
      })
    );

    res.json(chatsWithParticipants);
  } catch (error) {
    console.error('Get chats error:', error);
    res.status(500).json({ error: 'Failed to fetch chats' });
  }
});

// Get messages for a chat
router.get('/:chatId/messages', async (req, res) => {
  try {
    const { chatId } = req.params;
    const messages = await Message.findByChatId(chatId);
    res.json(messages);
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

// Create new chat
router.post('/', async (req, res) => {
  try {
    const { participants, createdBy, chatName } = req.body;

    if (!participants || !createdBy) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const existingChat = await Chat.findByParticipants(participants);
    if (existingChat) {
      return res.json({ chatId: existingChat.id, existing: true });
    }

    const chatId = await Chat.create({ participants, createdBy, chatName });

    res.status(201).json({ chatId, existing: false });
  } catch (error) {
    console.error('Create chat error:', error);
    res.status(500).json({ error: 'Failed to create chat' });
  }
});

// Send message
router.post('/:chatId/messages', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { senderUid, senderName, text, messageType, imageBase64 } = req.body;

    if (!senderUid || !senderName) {
      return res.status(400).json({ error: 'Missing sender info' });
    }

    if (messageType === 'text' && !text) {
      return res.status(400).json({ error: 'Text message cannot be empty' });
    }

    const messageId = await Message.create({
      chatId,
      senderUid,
      senderName,
      text: text || '',
      messageType: messageType || 'text',
      imageBase64: imageBase64 || null
    });

    const lastMessage = messageType === 'image' ? '🖼️ Ảnh' : text;
    await Chat.updateLastMessage(chatId, lastMessage);

    res.status(201).json({ messageId });
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

// Update message
router.put('/messages/:messageId', async (req, res) => {
  try {
    const { messageId } = req.params;
    const { text } = req.body;

    if (!text) {
      return res.status(400).json({ error: 'Text cannot be empty' });
    }

    await Message.update(messageId, { text });

    const message = await Message.findById(messageId);
    await Chat.updateLastMessage(message.chat_id, text);

    res.json({ message: 'Message updated' });
  } catch (error) {
    console.error('Update message error:', error);
    res.status(500).json({ error: 'Failed to update message' });
  }
});

// Delete message
router.delete('/messages/:messageId', async (req, res) => {
  try {
    const { messageId } = req.params;

    const message = await Message.findById(messageId);
    await Message.delete(messageId);

    const lastMessage = await Message.getLastMessage(message.chat_id);
    if (lastMessage) {
      await Chat.updateLastMessage(message.chat_id, lastMessage.text);
    } else {
      await Chat.updateLastMessage(message.chat_id, '');
    }

    res.json({ message: 'Message deleted' });
  } catch (error) {
    console.error('Delete message error:', error);
    res.status(500).json({ error: 'Failed to delete message' });
  }
});

// Clear chat
router.delete('/:chatId/messages', async (req, res) => {
  try {
    const { chatId } = req.params;
    await Message.deleteByChatId(chatId);
    await Chat.updateLastMessage(chatId, '');
    res.json({ message: 'Chat cleared' });
  } catch (error) {
    console.error('Clear chat error:', error);
    res.status(500).json({ error: 'Failed to clear chat' });
  }
});

// Delete chat
router.delete('/:chatId', async (req, res) => {
  try {
    const { chatId } = req.params;
    await Chat.delete(chatId);
    res.json({ message: 'Chat deleted' });
  } catch (error) {
    console.error('Delete chat error:', error);
    res.status(500).json({ error: 'Failed to delete chat' });
  }
});

// Update typing status
router.put('/:chatId/typing', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { uid, isTyping } = req.body;

    await Chat.updateTypingUser(chatId, isTyping ? uid : null);

    res.json({ message: 'Typing status updated' });
  } catch (error) {
    console.error('Update typing error:', error);
    res.status(500).json({ error: 'Failed to update typing status' });
  }
});

// Get typing user
router.get('/:chatId/typing', async (req, res) => {
  try {
    const { chatId } = req.params;
    const typingUser = await Chat.getTypingUser(chatId);
    res.json({ typingUser });
  } catch (error) {
    console.error('Get typing error:', error);
    res.status(500).json({ error: 'Failed to get typing status' });
  }
});

// Get chat/group info
router.get('/:chatId/info', async (req, res) => {
  try {
    const { chatId } = req.params;
    const pool = require('../config/database');
    const [chats] = await pool.query('SELECT * FROM chats WHERE id = ?', [chatId]);
    if (chats.length === 0) return res.status(404).json({ error: 'Chat not found' });

    const participants = await Chat.getParticipants(chatId);
    const participantDetails = await Promise.all(
      participants.map(async (uid) => {
        const user = await User.findByUid(uid);
        return user ? { uid: user.uid, displayName: user.display_name, avatarUrl: user.avatar_url, email: user.email } : null;
      })
    );

    res.json({
      ...chats[0],
      participants: participantDetails.filter(p => p !== null),
    });
  } catch (error) {
    console.error('Get chat info error:', error);
    res.status(500).json({ error: 'Failed to get chat info' });
  }
});

// Update group name/avatar
router.put('/:chatId/group', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { groupName, groupAvatar, adminUid } = req.body;
    const pool = require('../config/database');

    // Check if user is admin (created_by)
    const [chats] = await pool.query('SELECT created_by FROM chats WHERE id = ?', [chatId]);
    if (chats.length === 0) return res.status(404).json({ error: 'Chat not found' });
    if (chats[0].created_by !== adminUid) return res.status(403).json({ error: 'Only admin can update group' });

    const updates = [];
    const values = [];
    if (groupName) { updates.push('chat_name = ?'); values.push(groupName); }
    if (groupAvatar) { updates.push('group_avatar = ?'); values.push(groupAvatar); }

    if (updates.length > 0) {
      values.push(chatId);
      await pool.query(`UPDATE chats SET ${updates.join(', ')} WHERE id = ?`, values);
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Update group error:', error);
    res.status(500).json({ error: 'Failed to update group' });
  }
});

// Add participant to group
router.post('/:chatId/participants', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { userUid, adminUid } = req.body;
    const pool = require('../config/database');

    // Check admin
    const [chats] = await pool.query('SELECT created_by FROM chats WHERE id = ?', [chatId]);
    if (chats.length === 0) return res.status(404).json({ error: 'Chat not found' });
    if (chats[0].created_by !== adminUid) return res.status(403).json({ error: 'Only admin can add members' });

    await pool.query(
      'INSERT IGNORE INTO chat_participants (chat_id, user_uid) VALUES (?, ?)',
      [chatId, userUid]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Add participant error:', error);
    res.status(500).json({ error: 'Failed to add participant' });
  }
});

// Remove participant from group
router.delete('/:chatId/participants/:userUid', async (req, res) => {
  try {
    const { chatId, userUid } = req.params;
    const { adminUid } = req.body;
    const pool = require('../config/database');

    // Check admin
    const [chats] = await pool.query('SELECT created_by FROM chats WHERE id = ?', [chatId]);
    if (chats.length === 0) return res.status(404).json({ error: 'Chat not found' });
    if (chats[0].created_by !== adminUid) return res.status(403).json({ error: 'Only admin can remove members' });

    await pool.query(
      'DELETE FROM chat_participants WHERE chat_id = ? AND user_uid = ?',
      [chatId, userUid]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Remove participant error:', error);
    res.status(500).json({ error: 'Failed to remove participant' });
  }
});

// Leave group
router.post('/:chatId/leave', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { userUid } = req.body;
    const pool = require('../config/database');

    // Remove user from participants
    await pool.query(
      'DELETE FROM chat_participants WHERE chat_id = ? AND user_uid = ?',
      [chatId, userUid]
    );

    // If user was admin, transfer to next participant
    const [chats] = await pool.query('SELECT created_by FROM chats WHERE id = ?', [chatId]);
    if (chats.length > 0 && chats[0].created_by === userUid) {
      const [remaining] = await pool.query(
        'SELECT user_uid FROM chat_participants WHERE chat_id = ? LIMIT 1',
        [chatId]
      );
      if (remaining.length > 0) {
        await pool.query('UPDATE chats SET created_by = ? WHERE id = ?', [remaining[0].user_uid, chatId]);
      } else {
        // No members left, delete chat
        await pool.query('DELETE FROM chats WHERE id = ?', [chatId]);
      }
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Leave group error:', error);
    res.status(500).json({ error: 'Failed to leave group' });
  }
});

// Search messages in a chat
router.get('/:chatId/search', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { query, uid } = req.query;
    if (!query) return res.status(400).json({ error: 'Missing search query' });

    const pool = require('../config/database');
    const [messages] = await pool.query(
      `SELECT m.* FROM messages m
       LEFT JOIN deleted_messages dm ON dm.message_id = m.id AND dm.user_uid = ?
       WHERE m.chat_id = ? AND m.text LIKE ? AND dm.id IS NULL AND m.is_deleted_for_everyone = FALSE
       ORDER BY m.created_at DESC LIMIT 50`,
      [uid || '', chatId, `%${query}%`]
    );
    res.json(messages);
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Search failed' });
  }
});

// Add reaction to message
router.post('/messages/:messageId/reactions', async (req, res) => {
  try {
    const { messageId } = req.params;
    const { userUid, emoji } = req.body;
    const pool = require('../config/database');
    await pool.query(
      'INSERT INTO message_reactions (message_id, user_uid, emoji) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE emoji = ?',
      [messageId, userUid, emoji, emoji]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Reaction error:', error);
    res.status(500).json({ error: 'Failed to add reaction' });
  }
});

// Remove reaction from message
router.delete('/messages/:messageId/reactions', async (req, res) => {
  try {
    const { messageId } = req.params;
    const { userUid, emoji } = req.body;
    const pool = require('../config/database');
    await pool.query(
      'DELETE FROM message_reactions WHERE message_id = ? AND user_uid = ? AND emoji = ?',
      [messageId, userUid, emoji]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Remove reaction error:', error);
    res.status(500).json({ error: 'Failed to remove reaction' });
  }
});

// Get reactions for a message
router.get('/messages/:messageId/reactions', async (req, res) => {
  try {
    const { messageId } = req.params;
    const pool = require('../config/database');
    const [reactions] = await pool.query(
      'SELECT * FROM message_reactions WHERE message_id = ?',
      [messageId]
    );
    res.json(reactions);
  } catch (error) {
    console.error('Get reactions error:', error);
    res.status(500).json({ error: 'Failed to get reactions' });
  }
});

// Mark messages as read
router.post('/:chatId/read', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { userUid } = req.body;
    const pool = require('../config/database');

    // Get all unread messages in this chat not sent by this user
    const [messages] = await pool.query(
      `SELECT id, sender_uid FROM messages WHERE chat_id = ? AND sender_uid != ? AND delivery_status != 'read'`,
      [chatId, userUid]
    );

    for (const msg of messages) {
      await pool.query(
        'INSERT IGNORE INTO message_read_status (message_id, user_uid) VALUES (?, ?)',
        [msg.id, userUid]
      );
      await pool.query(
        "UPDATE messages SET delivery_status = 'read' WHERE id = ?",
        [msg.id]
      );
    }

    // Reset unread count
    await pool.query(
      'UPDATE chat_participants SET unread_count = 0 WHERE chat_id = ? AND user_uid = ?',
      [chatId, userUid]
    );

    // Emit via socket
    const io = req.app.get('io');
    if (io) {
      messages.forEach(msg => {
        io.emit('delivery_update', { messageId: msg.id, status: 'read' });
      });
    }

    res.json({ success: true, readCount: messages.length });
  } catch (error) {
    console.error('Mark read error:', error);
    res.status(500).json({ error: 'Failed to mark as read' });
  }
});

// Pin/Unpin message
router.put('/messages/:messageId/pin', async (req, res) => {
  try {
    const { messageId } = req.params;
    const { isPinned } = req.body;
    const pool = require('../config/database');
    await pool.query('UPDATE messages SET is_pinned = ? WHERE id = ?', [isPinned, messageId]);
    res.json({ success: true });
  } catch (error) {
    console.error('Pin error:', error);
    res.status(500).json({ error: 'Failed to pin message' });
  }
});

// Get pinned messages
router.get('/:chatId/pinned', async (req, res) => {
  try {
    const { chatId } = req.params;
    const pool = require('../config/database');
    const [messages] = await pool.query(
      'SELECT * FROM messages WHERE chat_id = ? AND is_pinned = TRUE ORDER BY created_at DESC',
      [chatId]
    );
    res.json(messages);
  } catch (error) {
    console.error('Get pinned error:', error);
    res.status(500).json({ error: 'Failed to get pinned messages' });
  }
});

// Delete for me
router.post('/messages/:messageId/delete-for-me', async (req, res) => {
  try {
    const { messageId } = req.params;
    const { userUid } = req.body;
    const pool = require('../config/database');
    await pool.query(
      'INSERT IGNORE INTO deleted_messages (message_id, user_uid) VALUES (?, ?)',
      [messageId, userUid]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Delete for me error:', error);
    res.status(500).json({ error: 'Failed to delete for me' });
  }
});

// Delete for everyone
router.post('/messages/:messageId/delete-for-everyone', async (req, res) => {
  try {
    const { messageId } = req.params;
    const pool = require('../config/database');
    await pool.query(
      'UPDATE messages SET is_deleted_for_everyone = TRUE, text = "Tin nhắn đã bị xóa" WHERE id = ?',
      [messageId]
    );

    // Emit via socket
    const io = req.app.get('io');
    if (io) {
      const [msg] = await pool.query('SELECT chat_id FROM messages WHERE id = ?', [messageId]);
      if (msg.length > 0) {
        io.to(`chat_${msg[0].chat_id}`).emit('message_deleted', { messageId });
      }
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Delete for everyone error:', error);
    res.status(500).json({ error: 'Failed to delete for everyone' });
  }
});

// Mute/Unmute chat
router.put('/:chatId/mute', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { userUid, isMuted } = req.body;
    const pool = require('../config/database');
    await pool.query(
      'UPDATE chat_participants SET is_muted = ? WHERE chat_id = ? AND user_uid = ?',
      [isMuted, chatId, userUid]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Mute error:', error);
    res.status(500).json({ error: 'Failed to mute chat' });
  }
});

// Archive/Unarchive chat
router.put('/:chatId/archive', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { userUid, isArchived } = req.body;
    const pool = require('../config/database');
    await pool.query(
      'UPDATE chat_participants SET is_archived = ? WHERE chat_id = ? AND user_uid = ?',
      [isArchived, chatId, userUid]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Archive error:', error);
    res.status(500).json({ error: 'Failed to archive chat' });
  }
});

// Send message with reply support
router.post('/:chatId/messages/reply', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { senderUid, senderName, text, messageType, imageBase64, voiceBase64, voiceDuration, replyToId, replyToText, replyToSender } = req.body;
    const pool = require('../config/database');

    const [result] = await pool.query(
      `INSERT INTO messages (chat_id, sender_uid, sender_name, text, message_type, image_base64, voice_base64, voice_duration, reply_to_id, reply_to_text, reply_to_sender, delivery_status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'sent')`,
      [chatId, senderUid, senderName, text || '', messageType || 'text', imageBase64 || null, voiceBase64 || null, voiceDuration || 0, replyToId || null, replyToText || null, replyToSender || null]
    );

    // Update last message
    const lastMsg = messageType === 'image' ? '🖼️ Ảnh' : messageType === 'voice' ? '🎤 Voice' : text;
    await pool.query(
      'UPDATE chats SET last_message = ?, last_message_time = NOW() WHERE id = ?',
      [lastMsg, chatId]
    );

    // Increment unread count for other participants
    await pool.query(
      'UPDATE chat_participants SET unread_count = unread_count + 1 WHERE chat_id = ? AND user_uid != ?',
      [chatId, senderUid]
    );

    const messageId = result.insertId;

    // Emit via socket
    const io = req.app.get('io');
    if (io) {
      io.to(`chat_${chatId}`).emit('new_message', {
        id: messageId,
        chatId: parseInt(chatId),
        senderUid,
        senderName,
        text,
        messageType,
        replyToId,
        replyToText,
        replyToSender,
      });
    }

    res.status(201).json({ messageId });
  } catch (error) {
    console.error('Reply message error:', error);
    res.status(500).json({ error: 'Failed to send reply' });
  }
});

module.exports = router;
