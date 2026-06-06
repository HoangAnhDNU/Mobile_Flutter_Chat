const pool = require('../config/database');

class Chat {
  static async create({ participants, createdBy, chatName = '' }) {
    const [result] = await pool.execute(
      'INSERT INTO chats (chat_name, last_message, created_by) VALUES (?, ?, ?)',
      [chatName, '', createdBy]
    );
    const chatId = result.insertId;

    for (const uid of participants) {
      await pool.execute(
        'INSERT INTO chat_participants (chat_id, user_uid) VALUES (?, ?)',
        [chatId, uid]
      );
    }

    return chatId;
  }

  static async findByParticipants(userUids) {
    if (!userUids || userUids.length === 0) return null;
    const placeholders = userUids.map(() => '?').join(',');
    const [rows] = await pool.execute(
      `SELECT c.* FROM chats c
       JOIN chat_participants cp ON c.id = cp.chat_id
       WHERE cp.user_uid IN (${placeholders})
       GROUP BY c.id
       HAVING COUNT(DISTINCT cp.user_uid) = ?`,
      [...userUids, userUids.length]
    );
    return rows[0];
  }

  static async findByUserUid(uid) {
    const [rows] = await pool.execute(
      `SELECT DISTINCT c.* FROM chats c
       JOIN chat_participants cp ON c.id = cp.chat_id
       WHERE cp.user_uid = ?
       ORDER BY c.last_message_time DESC`,
      [uid]
    );
    return rows;
  }

  static async getParticipants(chatId) {
    const [rows] = await pool.execute(
      'SELECT user_uid FROM chat_participants WHERE chat_id = ?',
      [chatId]
    );
    return rows.map(row => row.user_uid);
  }

  static async updateLastMessage(chatId, lastMessage) {
    await pool.execute(
      'UPDATE chats SET last_message = ?, last_message_time = NOW() WHERE id = ?',
      [lastMessage, chatId]
    );
  }

  static async updateTypingUser(chatId, uid) {
    await pool.execute(
      'UPDATE chats SET typing_user = ? WHERE id = ?',
      [uid ?? null, chatId]
    );
  }

  static async delete(chatId) {
    await pool.execute('DELETE FROM chats WHERE id = ?', [chatId]);
  }

  static async getTypingUser(chatId) {
    const [rows] = await pool.execute(
      'SELECT typing_user FROM chats WHERE id = ?',
      [chatId]
    );
    return rows[0]?.typing_user;
  }
}

module.exports = Chat;
