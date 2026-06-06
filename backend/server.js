const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const chatRoutes = require('./routes/chat');
const userRoutes = require('./routes/user');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

const PORT = process.env.PORT || 3000;

// Make io accessible to routes
app.set('io', io);

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/user', userRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Server is running' });
});

// Socket.IO connection handling
const onlineUsers = new Map(); // uid -> socketId

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // User comes online
  socket.on('user_online', (uid) => {
    onlineUsers.set(uid, socket.id);
    socket.uid = uid;
    io.emit('presence_update', { uid, isOnline: true });
  });

  // Join a chat room
  socket.on('join_chat', (chatId) => {
    socket.join(`chat_${chatId}`);
  });

  // Leave a chat room
  socket.on('leave_chat', (chatId) => {
    socket.leave(`chat_${chatId}`);
  });

  // New message sent
  socket.on('send_message', (data) => {
    io.to(`chat_${data.chatId}`).emit('new_message', data);
  });

  // Typing indicator
  socket.on('typing', (data) => {
    socket.to(`chat_${data.chatId}`).emit('user_typing', {
      chatId: data.chatId,
      uid: data.uid,
      isTyping: data.isTyping,
    });
  });

  // Message delivered
  socket.on('message_delivered', (data) => {
    const senderSocket = onlineUsers.get(data.senderUid);
    if (senderSocket) {
      io.to(senderSocket).emit('delivery_update', {
        messageId: data.messageId,
        status: 'delivered',
      });
    }
  });

  // Message read
  socket.on('message_read', (data) => {
    const senderSocket = onlineUsers.get(data.senderUid);
    if (senderSocket) {
      io.to(senderSocket).emit('delivery_update', {
        messageId: data.messageId,
        status: 'read',
      });
    }
  });

  // Message reaction
  socket.on('add_reaction', (data) => {
    io.to(`chat_${data.chatId}`).emit('reaction_update', data);
  });

  // Disconnect
  socket.on('disconnect', () => {
    if (socket.uid) {
      onlineUsers.delete(socket.uid);
      io.emit('presence_update', { uid: socket.uid, isOnline: false });
    }
    console.log('User disconnected:', socket.id);
  });
});

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// Start server
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`WebSocket ready on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});
