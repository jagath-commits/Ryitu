# PageCraft Backend API

A production-ready Node.js, Express, and MongoDB backend service for the **PageCraft Mobile PDF Book Reader Application**.

## Features

- **JWT Authentication**: User registration, login, forgot password, and profile endpoints with bcrypt password hashing.
- **Dedicated File Storage Abstraction**: Clean decoupling of binary PDF files from MongoDB metadata. PDF files are saved to safe storage with randomized, traversal-proof IDs.
- **Automatic PDF Processing**: Extracts accurate page counts directly from uploaded PDF documents using `pdf-lib`.
- **Dynamic Cover Generation**: Automatically generates stylish SVG book covers with title, author, and gradient themes when no explicit image is provided.
- **Reading Progress Tracking**: Records current page, total pages, percentage calculation, and last read timestamp per user and book.
- **Bookmark System**: Saves page-level bookmarks with optional notes and user isolation.
- **Embedded Database Fallback**: Out-of-the-box local execution using `mongodb-memory-server` if an external MongoDB service is not currently running.

---

## Directory Structure

```
backend/
├── src/
│   ├── config/
│   │   ├── database.js          # Mongoose connection & in-memory fallback
│   │   └── env.js               # Environment configuration
│   ├── controllers/
│   │   ├── auth.controller.js   # Register, Login, ForgotPassword, Me
│   │   ├── book.controller.js   # Upload, List, Details, Update, Delete
│   │   ├── bookmark.controller.js # Add, List, Delete bookmarks
│   │   └── progress.controller.js # Get, Update reading progress
│   ├── middleware/
│   │   ├── auth.middleware.js   # JWT verification & req.user injection
│   │   ├── upload.middleware.js # Multer PDF validation & 50MB limit
│   │   └── error.middleware.js  # Centralized error handler
│   ├── models/
│   │   ├── User.js              # User schema
│   │   ├── Book.js              # Book schema
│   │   ├── Bookmark.js          # Bookmark schema
│   │   └── ReadingProgress.js   # Reading progress schema
│   ├── routes/
│   │   ├── auth.routes.js
│   │   ├── book.routes.js
│   │   ├── bookmark.routes.js
│   │   └── progress.routes.js
│   ├── services/
│   │   └── storage.service.js   # Storage abstraction (Local / S3 ready)
│   ├── utils/
│   │   ├── coverGenerator.js    # Visual SVG cover generator
│   │   └── response.util.js     # Standard response formatting
│   ├── app.js                   # Express application setup
│   └── server.js                # Server entrypoint
├── uploads/
│   ├── pdf/                     # Uploaded PDF binary documents
│   └── covers/                  # Generated SVG/PNG book covers
├── test/
│   └── backend.test.js          # Automated end-to-end test suite
├── .env.example
├── package.json
└── README.md
```

---

## Environment Variables (`.env`)

| Variable | Default | Description |
|---|---|---|
| `PORT` | `5000` | Port for the HTTP server |
| `MONGODB_URI` | `mongodb://127.0.0.1:27017/pdf_book_reader` | MongoDB connection URI |
| `JWT_SECRET` | `pdf_reader_secret_key_change_in_production` | Secret key for signing JWT tokens |
| `JWT_EXPIRES_IN` | `7d` | Token validity duration |
| `UPLOAD_DIR` | `uploads` | Folder for PDF and cover files |
| `MAX_FILE_SIZE` | `52428800` | Max file upload limit in bytes (50MB) |
| `BASE_URL` | `http://localhost:5000` | Server base URL for asset links |

---

## Installation & Running

```bash
# 1. Install dependencies
npm install

# 2. Run automated test suite
npm test

# 3. Start development server (watch mode)
npm run dev

# 4. Start production server
npm start
```

---

## API Endpoints

### 1. Authentication (`/api/auth`)
- `POST /api/auth/register` — Body: `{ name, email, password }`
- `POST /api/auth/login` — Body: `{ email, password }`
- `POST /api/auth/forgot-password` — Body: `{ email }`
- `GET  /api/auth/me` — Protected (Bearer token)

### 2. Books (`/api/books`) — All Protected
- `GET    /api/books` — List user books (supports `?search=keyword`)
- `GET    /api/books/:id` — Get book details & reading progress
- `POST   /api/books/upload` — Upload PDF (`multipart/form-data`: `pdf`, `title`, `author`, `description`)
- `PUT    /api/books/:id` — Update book metadata
- `DELETE /api/books/:id` — Delete book (soft delete)

### 3. Bookmarks (`/api/books/:bookId/bookmarks`) — All Protected
- `POST   /api/books/:bookId/bookmarks` — Body: `{ pageNumber, note }`
- `GET    /api/books/:bookId/bookmarks` — List bookmarks for book
- `DELETE /api/books/:bookId/bookmarks/:bookmarkId` — Delete bookmark

### 4. Reading Progress (`/api/books/:bookId/progress`) — All Protected
- `GET /api/books/:bookId/progress` — Get progress
- `PUT /api/books/:bookId/progress` — Body: `{ currentPage, totalPages }`