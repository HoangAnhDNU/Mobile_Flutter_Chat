const express = require('express');
const User = require('../models/User');

const router = express.Router();

// Get all users (except current)
router.get('/', async (req, res) => {
  try {
    const { uid } = req.query;
    if (!uid) {
      return res.status(400).json({ error: 'Missing uid' });
    }

    const users = await User.getAllUsers(uid);
    res.json(users);
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// Get user by uid
router.get('/:uid', async (req, res) => {
  try {
    const { uid } = req.params;
    const user = await User.findByUid(uid);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      uid: user.uid,
      email: user.email,
      displayName: user.display_name,
      avatarUrl: user.avatar_url,
      isOnline: user.is_online,
      lastSeen: user.last_seen
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// Update user profile
router.put('/:uid', async (req, res) => {
  try {
    const { uid } = req.params;
    const { displayName, avatarUrl } = req.body;

    await User.updateProfile(uid, { displayName, avatarUrl });

    const updatedUser = await User.findByUid(uid);
    res.json({
      uid: updatedUser.uid,
      displayName: updatedUser.display_name,
      avatarUrl: updatedUser.avatar_url
    });
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ error: 'Failed to update user' });
  }
});

// Update online status
router.put('/:uid/online', async (req, res) => {
  try {
    const { uid } = req.params;
    const { isOnline } = req.body;

    await User.updateOnlineStatus(uid, isOnline);

    res.json({ message: 'Online status updated' });
  } catch (error) {
    console.error('Update online status error:', error);
    res.status(500).json({ error: 'Failed to update online status' });
  }
});

// Block user
router.post('/:uid/block', async (req, res) => {
  try {
    const { uid } = req.params;
    const { blockedUid } = req.body;
    const pool = require('../config/database');
    await pool.query(
      'INSERT IGNORE INTO blocked_users (blocker_uid, blocked_uid) VALUES (?, ?)',
      [uid, blockedUid]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Block user error:', error);
    res.status(500).json({ error: 'Failed to block user' });
  }
});

// Unblock user
router.delete('/:uid/block', async (req, res) => {
  try {
    const { uid } = req.params;
    const { blockedUid } = req.body;
    const pool = require('../config/database');
    await pool.query(
      'DELETE FROM blocked_users WHERE blocker_uid = ? AND blocked_uid = ?',
      [uid, blockedUid]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Unblock user error:', error);
    res.status(500).json({ error: 'Failed to unblock user' });
  }
});

// Get blocked users
router.get('/:uid/blocked', async (req, res) => {
  try {
    const { uid } = req.params;
    const pool = require('../config/database');
    const [blocked] = await pool.query(
      `SELECT u.uid, u.display_name, u.avatar_url, u.email
       FROM blocked_users b
       JOIN users u ON u.uid = b.blocked_uid
       WHERE b.blocker_uid = ?`,
      [uid]
    );
    res.json(blocked);
  } catch (error) {
    console.error('Get blocked error:', error);
    res.status(500).json({ error: 'Failed to get blocked users' });
  }
});

module.exports = router;
