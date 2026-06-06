# Mobile Flutter Chat Backend

Node.js REST API backend for Mobile Flutter Chat app using MySQL database.

## Prerequisites

- Node.js (v14 or higher)
- MySQL (v5.7 or higher)
- npm or yarn

## Installation

1. Install dependencies:
```bash
npm install
```

2. Create `.env` file in the backend directory:
```bash
cp .env.example .env
```

3. Configure `.env` with your MySQL credentials:
```env
PORT=3000
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=mobile_flutter_chat
JWT_SECRET=your_jwt_secret_key_here
```

## Database Setup

1. Create the database and tables using the schema file:
```bash
mysql -u root -p < database/schema.sql
```

Or manually execute the SQL in `database/schema.sql` in your MySQL client.

## Running the Server

Development mode (with auto-reload):
```bash
npm run dev
```

Production mode:
```bash
npm start
```

The server will start on `http://localhost:3000`

## API Endpoints

### Authentication

- `POST /api/auth/register` - Register new user
  - Body: `{ email, password, displayName }`
  
- `POST /api/auth/login` - Login user
  - Body: `{ email, password }`
  
- `POST /api/auth/logout` - Logout user
  - Body: `{ uid }`

### Users

- `GET /api/user?uid={uid}` - Get all users (except current)
- `GET /api/user/{uid}` - Get user by UID
- `PUT /api/user/{uid}` - Update user profile
  - Body: `{ displayName?, avatarUrl? }`
- `PUT /api/user/{uid}/online` - Update online status
  - Body: `{ isOnline: boolean }`

### Chats

- `GET /api/chat?uid={uid}` - Get all chats for user
- `GET /api/chat/{chatId}/messages` - Get messages for chat
- `POST /api/chat` - Create new chat
  - Body: `{ participants: string[], createdBy: string, chatName?: string }`
- `POST /api/chat/{chatId}/messages` - Send message
  - Body: `{ senderUid, senderName, text, messageType, imageBase64? }`
- `PUT /api/chat/messages/{messageId}` - Update message
  - Body: `{ text }`
- `DELETE /api/chat/messages/{messageId}` - Delete message
- `DELETE /api/chat/{chatId}/messages` - Clear chat history
- `DELETE /api/chat/{chatId}` - Delete chat
- `PUT /api/chat/{chatId}/typing` - Update typing status
  - Body: `{ uid, isTyping }`
- `GET /api/chat/{chatId}/typing` - Get typing user

## Database Schema

### users
- `id` (INT, Primary Key, Auto Increment)
- `uid` (VARCHAR, Unique)
- `email` (VARCHAR, Unique)
- `password_hash` (VARCHAR)
- `display_name` (VARCHAR)
- `avatar_url` (TEXT)
- `is_online` (BOOLEAN)
- `last_seen` (TIMESTAMP)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

### chats
- `id` (INT, Primary Key, Auto Increment)
- `chat_name` (VARCHAR)
- `last_message` (TEXT)
- `last_message_time` (TIMESTAMP)
- `typing_user` (VARCHAR)
- `created_by` (VARCHAR)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

### chat_participants
- `id` (INT, Primary Key, Auto Increment)
- `chat_id` (INT, Foreign Key)
- `user_uid` (VARCHAR)
- `joined_at` (TIMESTAMP)

### messages
- `id` (INT, Primary Key, Auto Increment)
- `chat_id` (INT, Foreign Key)
- `sender_uid` (VARCHAR)
- `sender_name` (VARCHAR)
- `text` (TEXT)
- `message_type` (ENUM: 'text', 'image')
- `image_base64` (TEXT)
- `is_edited` (BOOLEAN)
- `edited_at` (TIMESTAMP)
- `created_at` (TIMESTAMP)

## Features Implemented

- ✅ User registration and login with JWT authentication
- ✅ User profile management
- ✅ Online status tracking
- ✅ Create 1-on-1 chats
- ✅ Send text and image messages (Base64 encoded)
- ✅ Edit and delete messages
- ✅ Clear chat history
- ✅ Delete chats
- ✅ Typing indicators
- ✅ User listing

## Features Not Yet Implemented

- ❌ Group chat management (add/remove members, group settings)
- ❌ Password reset (requires email service)
- ❌ Account deletion
- ❌ Real-time updates (requires WebSocket implementation)

## Security Notes

- Passwords are hashed using bcrypt
- JWT tokens are used for authentication
- CORS is enabled for development
- In production, configure CORS to allow only your Flutter app's domain
- Change the `JWT_SECRET` to a strong random string in production

## Flutter App Configuration

Update the `baseUrl` in `lib/core/services/api_service.dart` to match your backend URL:

```dart
static const String baseUrl = 'http://localhost:3000/api';
```

For production, use your actual backend server URL.

## Troubleshooting

### Database Connection Error
- Ensure MySQL server is running
- Check credentials in `.env` file
- Verify database exists

### Port Already in Use
- Change `PORT` in `.env` file
- Or kill the process using port 3000

### JWT Token Issues
- Ensure `JWT_SECRET` is set in `.env`
- Tokens expire after 7 days by default
