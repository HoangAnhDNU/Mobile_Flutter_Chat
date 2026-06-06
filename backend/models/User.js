const pool = require('../config/database');

class User {
  static async create({ uid, email, passwordHash, displayName }) {
    const [result] = await pool.execute(
      'INSERT INTO users (uid, email, password_hash, display_name, is_online, last_seen) VALUES (?, ?, ?, ?, TRUE, NOW())',
      [uid, email, passwordHash, displayName]
    );
    return result.insertId;
  }

  static async findByEmail(email) {
    const [rows] = await pool.execute(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );
    return rows[0];
  }

  static async findByUid(uid) {
    const [rows] = await pool.execute(
      'SELECT * FROM users WHERE uid = ?',
      [uid]
    );
    return rows[0];
  }

  static async updateOnlineStatus(uid, isOnline) {
    await pool.execute(
      'UPDATE users SET is_online = ?, last_seen = NOW() WHERE uid = ?',
      [isOnline, uid]
    );
  }

  static async updateProfile(uid, { displayName, avatarUrl }) {
    const updates = [];
    const values = [];

    if (displayName !== undefined) {
      updates.push('display_name = ?');
      values.push(displayName);
    }
    if (avatarUrl !== undefined) {
      updates.push('avatar_url = ?');
      values.push(avatarUrl);
    }

    if (updates.length === 0) return;

    values.push(uid);
    await pool.execute(
      `UPDATE users SET ${updates.join(', ')} WHERE uid = ?`,
      values
    );
  }

  static async getAllUsers(excludeUid) {
    const [rows] = await pool.execute(
      'SELECT uid, email, display_name, avatar_url, is_online, last_seen FROM users WHERE uid != ?',
      [excludeUid]
    );
    return rows;
  }
}

module.exports = User;
