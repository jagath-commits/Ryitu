# PageCraft - Mobile PDF Book Reader Application

A complete, production-ready, standalone digital book reading solution consisting of:
- **Mobile Client**: Flutter application featuring Material 3 UI, distraction-free PDF reading, reading themes, settings, bookmarks, and automatic reading progress tracking.
- **Backend Service**: Node.js & Express REST API with JWT authentication, Mongoose/MongoDB metadata persistence, dedicated file storage abstraction, automatic PDF page calculation, and dynamic cover generation.

---

## Technology Stack

### Frontend
- **Framework**: Flutter 3.41+ & Dart 3.11+
- **UI Design**: Material 3 Design with Light, Dark, Sepia, and AMOLED Black reading themes
- **State Management**: Provider (clean, scalable MVVM architecture)
- **PDF Engine**: `syncfusion_flutter_pdfviewer`
- **File Management**: `file_picker`, `shared_preferences`, `wakelock_plus`

### Backend
- **Runtime**: Node.js v24+
- **Server Framework**: Express.js
- **Database**: MongoDB with Mongoose (with embedded in-memory fallback for zero-config testing)
- **Security**: JWT authentication, bcryptjs password hashing, helmet, CORS, path-traversal prevention
- **File Uploads**: Multer with 50MB limit & PDF MIME validation
- **PDF Processing**: `pdf-lib` for page count extraction & custom SVG cover generator

---

## Getting Started

### 1. Prerequisites
- **Node.js** v18+ and **npm**
- **Flutter SDK** v3.20+ and Dart
- Optional: MongoDB installed locally, or Docker (the backend automatically starts an embedded database if MongoDB is not detected!)

---

### 2. Backend Setup & Run

```bash
cd backend

# Install dependencies
npm install

# Run automated verification test suite
npm test

# Start backend server
npm start
```
The backend starts at `http://localhost:5000`. You can check server health at `http://localhost:5000/api/health`.

---

### 3. Frontend Setup & Run

```bash
cd frontend

# Install Flutter dependencies
flutter pub get

# Run test suite
flutter test

# Run code analyzer
flutter analyze

# Launch the app
flutter run
```

> **Network Configuration Note:**
> - When running on **Android Emulator**, the app connects to `http://10.0.2.2:5000/api` (the host machine).
> - When running on **Windows Desktop / Web / iOS**, the app connects to `http://localhost:5000/api`.
> - If you are testing on a **physical mobile device**, enter your computer's local Wi-Fi IP (e.g. `http://192.168.1.100:5000/api`) directly from the in-app **Profile > Backend API Server** configuration dialog.

---

## Core User Flows

1. **Authentication**: Register with Name, Email, Password, or Log in with existing credentials.
2. **Library**: View all uploaded books, real-time search by Title or Author, view reading progress badges, sort by Recent / Title / Progress, or switch between Grid and List view.
3. **PDF Upload**: Select a PDF from device storage (validated for `.pdf` and <50MB), enter custom title/author/description, upload with progress tracking, and automatically generate a book with custom SVG cover.
4. **Book Details**: Inspect full book metadata, page count, and reading progress. Tap `[Continue Reading]` to jump directly to your last read page, `[Start From Beginning]` to start at page 1, or `[Bookmark List]` to browse bookmarks.
5. **PDF Reader**:
   - Smooth continuous vertical scrolling or single-page view.
   - Pinch zoom, double-tap zoom, and zoom presets.
   - Tap screen to toggle top/bottom overlays.
   - Jump to any page with the page slider or direct page input dialog.
   - Switch between **Light**, **Dark**, **Sepia**, and **AMOLED Black** themes.
   - Toggle Keep Screen Awake on or off.
   - Add bookmarks with custom notes; bookmark button highlights if current page is bookmarked.
   - Automatic debounced reading progress sync with backend and offline local cache.
6. **Profile**: View statistics (Total Books, Total Pages, Completed Books), change preferences, configure server endpoint, and sign out.

---

## Automated Verification Results

- **Backend Integration Tests**: 11/11 tests passing (Auth, PDF Upload, Page Count Calculation, Cover Generation, Reading Progress, Bookmarks, Search, User Isolation, Deletion).
- **Frontend Unit & Widget Tests**: 9/9 tests passing (User model, Book model, ReadingProgress calculation, Bookmark model, Settings enums, FileSize formatters, ReadingProgressBar, EmptyState).
- **Flutter Analyze**: 0 errors, 0 warnings.
- **Web Build**: Successfully compiled to `build/web`.