const pool = require('../config/database');

class Message {
  static async create({ chatId, senderUid, senderName, text, messageType = 'text', imageBase64 = null }) {
    const [result] = await pool.execute(
      'INSERT INTO messages (chat_id, sender_uid, sender_name, text, message_type, image_base64) VALUES (?, ?, ?, ?, ?, ?)',
      [chatId, senderUid, senderName, text, messageType, imageBase64]
    );
    return result.insertId;
  }

  static async findByChatId(chatId, limit = 50) {
    const [rows] = await pool.execute(
      `SELECT * FROM messages WHERE chat_id = ? ORDER BY created_at DESC LIMIT ${parseInt(limit)}`,
      [parseInt(chatId)]
    );
    return rows;
  }

  static async findById(messageId) {
    const [rows] = await pool.execute(
      'SELECT * FROM messages WHERE id = ?',
      [messageId]
    );
    return rows[0];
  }

  static async update(messageId, { text, isEdited = true }) {
    await pool.execute(
      'UPDATE messages SET text = ?, is_edited = ?, edited_at = NOW() WHERE id = ?',
      [text, isEdited, messageId]
    );
  }

  static async delete(messageId) {
    await pool.execute('DELETE FROM messages WHERE id = ?', [messageId]);
  }

  static async deleteByChatId(chatId) {
    await pool.execute('DELETE FROM messages WHERE chat_id = ?', [chatId]);
  }

  static async getLastMessage(chatId) {
    const [rows] = await pool.execute(
      'SELECT * FROM messages WHERE chat_id = ? ORDER BY created_at DESC LIMIT 1',
      [chatId]
    );
    return rows[0];
  }
}

module.exports = Message;
