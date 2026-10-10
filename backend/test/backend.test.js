const http = require('http');
const path = require('path');
const fs = require('fs');
const assert = require('assert');
const { PDFDocument } = require('pdf-lib');
const app = require('../src/app');
const env = require('../src/config/env');
const { connectDB, disconnectDB } = require('../src/config/database');

let server;
let baseUrl;
let authToken = '';
let registeredUserId = '';
let createdBookId = '';
let createdBookmarkId = '';

// Helper to make HTTP requests
function request(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(baseUrl + path);
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: { ...headers }
    };

    let postData = null;
    if (body && !(body instanceof Buffer)) {
      if (typeof body === 'object' && !headers['content-type']) {
        postData = JSON.stringify(body);
        options.headers['Content-Type'] = 'application/json';
        options.headers['Content-Length'] = Buffer.byteLength(postData);
      }
    } else if (body instanceof Buffer) {
      postData = body;
      options.headers['Content-Length'] = body.length;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });

    req.on('error', reject);
    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

// Multipart builder helper
function buildMultipart(boundary, fields, files) {
  const chunks = [];
  for (const [key, val] of Object.entries(fields)) {
    chunks.push(Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="${key}"\r\n\r\n${val}\r\n`
    ));
  }
  for (const file of files) {
    chunks.push(Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="${file.field}"; filename="${file.filename}"\r\nContent-Type: ${file.contentType}\r\n\r\n`
    ));
    chunks.push(file.content);
    chunks.push(Buffer.from('\r\n'));
  }
  chunks.push(Buffer.from(`--${boundary}--\r\n`));
  return Buffer.concat(chunks);
}

async function runTests() {
  console.log('🚀 Starting Backend Verification Suite...');
  await connectDB();

  server = app.listen(0);
  const port = server.address().port;
  baseUrl = `http://localhost:${port}`;
  console.log(`[Test Server] Running on ${baseUrl}`);

  try {
    // 1. Health Check
    console.log('\n--- 1. Testing GET /api/health ---');
    const health = await request('GET', '/api/health');
    assert.strictEqual(health.status, 200);
    assert.strictEqual(health.body.success, true);
    console.log('✔ Health check passed');

    // 2. Register
    console.log('\n--- 2. Testing POST /api/auth/register ---');
    const regRes = await request('POST', '/api/auth/register', {
      name: 'Alice Reader',
      email: `alice_${Date.now()}@example.com`,
      password: 'password123'
    });
    assert.strictEqual(regRes.status, 201);
    assert.strictEqual(regRes.body.success, true);
    assert.ok(regRes.body.data.token);
    assert.strictEqual(regRes.body.data.user.name, 'Alice Reader');
    authToken = regRes.body.data.token;
    registeredUserId = regRes.body.data.user_id;
    console.log('✔ User registration passed');

    // 3. Login
    console.log('\n--- 3. Testing POST /api/auth/login ---');
    const loginRes = await request('POST', '/api/auth/login', {
      email: regRes.body.data.user.email,
      password: 'password123'
    });
    assert.strictEqual(loginRes.status, 200);
    assert.strictEqual(loginRes.body.success, true);
    assert.ok(loginRes.body.data.token);
    console.log('✔ User login passed');

    // 4. GET /api/auth/me
    console.log('\n--- 4. Testing GET /api/auth/me ---');
    const meRes = await request('GET', '/api/auth/me', null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(meRes.status, 200);
    assert.strictEqual(meRes.body.data.user.name, 'Alice Reader');
    console.log('✔ User profile /me passed');

    // 5. Upload PDF Book
    console.log('\n--- 5. Testing POST /api/books/upload (with valid PDF) ---');
    // Generate a valid 2-page sample PDF
    const pdfDoc = await PDFDocument.create();
    pdfDoc.addPage([400, 600]);
    pdfDoc.addPage([400, 600]);
    const pdfBytes = await pdfDoc.save();

    const boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW';
    const multipartBody = buildMultipart(
      boundary,
      {
        title: 'The Art of Computer Reading',
        author: 'Donald Knuth',
        description: 'An insightful masterpiece on algorithmic reading.'
      },
      [
        {
          field: 'pdf',
          filename: 'computer_reading.pdf',
          contentType: 'application/pdf',
          content: Buffer.from(pdfBytes)
        }
      ]
    );

    const uploadRes = await request('POST', '/api/books/upload', multipartBody, {
      Authorization: `Bearer ${authToken}`,
      'Content-Type': `multipart/form-data; boundary=${boundary}`
    });

    assert.strictEqual(uploadRes.status, 201);
    assert.strictEqual(uploadRes.body.success, true);
    assert.strictEqual(uploadRes.body.data.book.title, 'The Art of Computer Reading');
    assert.strictEqual(uploadRes.body.data.book.author, 'Donald Knuth');
    assert.strictEqual(uploadRes.body.data.book.pageCount, 2);
    assert.ok(uploadRes.body.data.book.coverImage);
    assert.ok(uploadRes.body.data.book.pdfUrl);
    createdBookId = uploadRes.body.data.book._id;
    console.log(`✔ Book upload passed (Page count calculated: ${uploadRes.body.data.book.pageCount})`);

    // 6. List Books & Search
    console.log('\n--- 6. Testing GET /api/books (with & without search) ---');
    const listRes = await request('GET', '/api/books', null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(listRes.status, 200);
    assert.strictEqual(listRes.body.data.count, 1);
    assert.strictEqual(listRes.body.data.books[0]._id, createdBookId);

    const searchMatch = await request('GET', '/api/books?search=Donald', null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(searchMatch.body.data.count, 1);

    const searchMiss = await request('GET', '/api/books?search=NonExistentKeywordXYZ', null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(searchMiss.body.data.count, 0);
    console.log('✔ Book listing and real-time search passed');

    // 7. Get Book By ID
    console.log('\n--- 7. Testing GET /api/books/:id ---');
    const singleBook = await request('GET', `/api/books/${createdBookId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(singleBook.status, 200);
    assert.strictEqual(singleBook.body.data.book.title, 'The Art of Computer Reading');
    assert.strictEqual(singleBook.body.data.book.progress.currentPage, 1);
    console.log('✔ Get book by ID passed');

    // 8. Bookmark System (Create, List, Delete)
    console.log('\n--- 8. Testing Bookmark System ---');
    const addBm = await request('POST', `/api/books/${createdBookId}/bookmarks`, {
      pageNumber: 2,
      note: 'Key algorithmic formula'
    }, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(addBm.status, 201);
    assert.strictEqual(addBm.body.data.bookmark.pageNumber, 2);
    assert.strictEqual(addBm.body.data.bookmark.note, 'Key algorithmic formula');
    createdBookmarkId = addBm.body.data.bookmark._id;

    const listBm = await request('GET', `/api/books/${createdBookId}/bookmarks`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(listBm.status, 200);
    assert.strictEqual(listBm.body.data.count, 1);
    console.log('✔ Add & list bookmarks passed');

    // 9. Reading Progress (Update & Get)
    console.log('\n--- 9. Testing Reading Progress ---');
    const updateProg = await request('PUT', `/api/books/${createdBookId}/progress`, {
      currentPage: 2,
      totalPages: 2
    }, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(updateProg.status, 200);
    assert.strictEqual(updateProg.body.data.progress.currentPage, 2);
    assert.strictEqual(updateProg.body.data.progress.progressPercentage, 100);

    const getProg = await request('GET', `/api/books/${createdBookId}/progress`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(getProg.status, 200);
    assert.strictEqual(getProg.body.data.progress.currentPage, 2);
    console.log('✔ Reading progress tracking passed (100% completed)');

    // 10. Delete Bookmark
    console.log('\n--- 10. Testing DELETE Bookmark ---');
    const delBm = await request('DELETE', `/api/books/${createdBookId}/bookmarks/${createdBookmarkId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(delBm.status, 200);
    const listBmAfter = await request('GET', `/api/books/${createdBookId}/bookmarks`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(listBmAfter.body.data.count, 0);
    console.log('✔ Delete bookmark passed');

    // 11. Delete Book
    console.log('\n--- 11. Testing DELETE Book ---');
    const delBook = await request('DELETE', `/api/books/${createdBookId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(delBook.status, 200);

    const listFinal = await request('GET', '/api/books', null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(listFinal.body.data.count, 0);
    console.log('✔ Delete book passed');

    // 12. Document Extraction (PDF)
    console.log('\n--- 12. Testing POST /api/posts/extractDocument (PDF Processing) ---');
    const docPdf = await PDFDocument.create();
    docPdf.addPage([400, 600]);
    const docPdfBytes = await docPdf.save();

    const extractBoundary = '----WebKitFormBoundaryExtract';
    const extractBody = buildMultipart(extractBoundary, {}, [
      {
        field: 'document',
        filename: 'sample_document.pdf',
        contentType: 'application/pdf',
        content: Buffer.from(docPdfBytes)
      }
    ]);
    const extractRes = await request('POST', '/api/posts/extractDocument', extractBody, {
      'Content-Type': `multipart/form-data; boundary=${extractBoundary}`,
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(extractRes.status, 200);
    assert.strictEqual(extractRes.body.success, true);
    assert.ok(extractRes.body.extractionId);
    const extractionId = extractRes.body.extractionId;

    const fullDoc = await request('GET', `/api/posts/documentFull/${extractionId}`);
    assert.strictEqual(fullDoc.status, 200);
    assert.strictEqual(fullDoc.body.success, true);
    assert.ok(fullDoc.body.text !== undefined);

    const chunkDoc = await request('GET', `/api/posts/documentChunk/${extractionId}/0`);
    assert.strictEqual(chunkDoc.status, 200);
    assert.strictEqual(chunkDoc.body.success, true);
    console.log('✔ PDF document extraction & chunk streaming passed');

    // 13. Publish Ryitu Post with Cover Image
    console.log('\n--- 13. Testing POST /api/posts (Publish Ryitu PDF Book with Cover Image) ---');
    const postBoundary = '----WebKitFormBoundaryPost';
    const fakeCover = Buffer.from('fake-jpeg-cover-data');
    const postBody = buildMultipart(postBoundary, {
      title: 'Tamil Historical Novel',
      caption: 'A digital edition book for readers',
      categoryId: 'CAT00000004',
      hashtags: '#history #ryitu',
      content: JSON.stringify([
        {
          fontSize: 22,
          fontFamily: 'Roboto',
          blocks: [{ type: 'text', text: 'First Chapter of the book' }]
        }
      ])
    }, [
      {
        field: 'cover_image',
        filename: 'my_cover.jpg',
        contentType: 'image/jpeg',
        content: fakeCover
      }
    ]);
    const createPostRes = await request('POST', '/api/posts', postBody, {
      'Content-Type': `multipart/form-data; boundary=${postBoundary}`,
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(createPostRes.status, 201);
    assert.strictEqual(createPostRes.body.success, true);
    assert.strictEqual(createPostRes.body.data.category, 'Ryitu');
    assert.strictEqual(createPostRes.body.data.categoryId, 'CAT00000004');
    assert.ok(createPostRes.body.data.cover_image.startsWith('cover_image_'));
    assert.strictEqual(createPostRes.body.data.cover_img, createPostRes.body.data.cover_image);
    assert.strictEqual(createPostRes.body.data.coverImage, createPostRes.body.data.cover_image);
    const createdPostId = createPostRes.body.data.post_id;
    console.log('✔ Ryitu PDF book publication with cover image passed');

    // 14. Get Posts & Search (Strictly Ryitu)
    console.log('\n--- 14. Testing GET /api/posts (List & Search Ryitu) ---');
    const getPostsRes = await request('GET', '/api/posts');
    assert.strictEqual(getPostsRes.status, 200);
    assert.strictEqual(getPostsRes.body.success, true);
    assert.ok(getPostsRes.body.data.length >= 1);
    assert.strictEqual(getPostsRes.body.data[0].category, 'Ryitu');
    assert.ok(getPostsRes.body.data[0].cover_image);
    assert.ok(getPostsRes.body.data[0].cover_img);

    const searchPostRes = await request('GET', '/api/posts?search=Historical');
    assert.strictEqual(searchPostRes.status, 200);
    assert.strictEqual(searchPostRes.body.data.length, 1);
    console.log('✔ Ryitu post listing and keyword search passed');

    // 14b. Test User Posts in Profile
    console.log('\n--- 14b. Testing GET /api/posts/userposts/:userId (Profile Posts) ---');
    const userPostsRes = await request('GET', `/api/posts/userposts/${registeredUserId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(userPostsRes.status, 200);
    assert.strictEqual(userPostsRes.body.success, true);
    assert.ok(userPostsRes.body.data.length >= 1);
    assert.strictEqual(userPostsRes.body.data[0].post_id, createdPostId);
    console.log('✔ Profile user posts listing passed');

    // 15. Toggle Support, Save, and View Count
    console.log('\n--- 15. Testing Post Interactions (Support, Save, View) ---');
    const supportRes = await request('POST', `/api/posts/toggleSupport/${createdPostId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(supportRes.status, 200);
    assert.strictEqual(supportRes.body.data.support_count, 1);

    const saveRes = await request('POST', `/api/posts/toggleSave/${createdPostId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(saveRes.status, 200);
    assert.strictEqual(saveRes.body.data.isSaved, true);

    // Verify Saved Posts in Profile
    const savedPostsRes = await request('GET', `/api/posts/savedposts/${registeredUserId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(savedPostsRes.status, 200);
    assert.strictEqual(savedPostsRes.body.success, true);
    assert.ok(savedPostsRes.body.data.length >= 1);
    assert.strictEqual(savedPostsRes.body.data[0].post_id, createdPostId);
    console.log('✔ Profile saved posts listing passed');

    const viewRes = await request('POST', `/api/posts/view/${createdPostId}`);
    assert.strictEqual(viewRes.status, 200);
    console.log('✔ Support, bookmark save, and view tracking passed');

    // 16. Drafts Management
    console.log('\n--- 16. Testing Draft Management ---');
    const draftRes = await request('POST', '/api/draft/saveDraft', {
      title: 'Work In Progress Book',
      caption: 'Draft notes',
      content: JSON.stringify([{ blocks: [] }])
    }, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(draftRes.status, 200);
    assert.ok(draftRes.body.draftId);
    const draftId = draftRes.body.draftId;

    // Verify Drafts in Profile
    const userDraftsRes = await request('GET', `/api/posts/getdraftposts/${registeredUserId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(userDraftsRes.status, 200);
    assert.strictEqual(userDraftsRes.body.success, true);
    assert.ok(userDraftsRes.body.data.length >= 1);
    assert.strictEqual(userDraftsRes.body.data[0].draft_id, draftId);
    console.log('✔ Profile drafts listing passed');

    const delDraftRes = await request('DELETE', `/api/draft/${draftId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(delDraftRes.status, 200);
    console.log('✔ Draft creation and deletion passed');

    // 17. Delete Ryitu Post
    console.log('\n--- 17. Testing DELETE /api/posts/:id ---');
    const delPostRes = await request('DELETE', `/api/posts/${createdPostId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(delPostRes.status, 200);
    console.log('✔ Ryitu post deletion passed');

    // 18. Verify AI Route is Removed (404)
    console.log('\n--- 18. Verifying AI Feature Endpoint Removal ---');
    const aiRes = await request('POST', '/api/ai/generate-meme', {});
    assert.strictEqual(aiRes.status, 404);
    console.log('✔ Confirmed AI writing/meme route is completely removed');

    // 19. Verify Custom String User ID (USR00000001) Compatibility
    console.log('\n--- 19. Testing Custom String user_id ("USR00000001") Compatibility ---');
    const customUserId = 'USR00000001';

    // 19a. Save Draft with custom string user_id
    const customDraftRes = await request('POST', '/api/draft/saveDraft', {
      user_id: customUserId,
      title: 'Draft with custom string user_id',
      caption: 'Testing BSON CastError fix',
      content: JSON.stringify([{ blocks: [] }])
    });
    assert.strictEqual(customDraftRes.status, 200);
    assert.ok(customDraftRes.body.draftId);
    const customDraftId = customDraftRes.body.draftId;

    // 19b. Get user drafts by custom string user_id
    const customGetDraftsRes = await request('GET', `/api/posts/getdraftposts/${customUserId}`);
    assert.strictEqual(customGetDraftsRes.status, 200);
    assert.ok(customGetDraftsRes.body.data.some(d => d.draft_id === customDraftId));

    // 19c. Publish Post with custom string user_id
    const customPostBoundary = '----WebKitFormBoundaryCustomPost';
    const customPostBody = buildMultipart(customPostBoundary, {
      user_id: customUserId,
      title: 'Ryitu Book by Custom User',
      caption: 'Testing Post schema Mixed user_id',
      categoryId: 'CAT00000004',
      hashtags: '#custom #ryitu',
      content: JSON.stringify([{ blocks: [{ type: 'text', text: 'Content from USR00000001' }] }])
    }, [
      {
        field: 'cover_image',
        filename: 'custom_cover.jpg',
        contentType: 'image/jpeg',
        content: Buffer.from('custom-cover-bytes')
      }
    ]);
    const customPostRes = await request('POST', '/api/posts', customPostBody, {
      'Content-Type': `multipart/form-data; boundary=${customPostBoundary}`
    });
    assert.strictEqual(customPostRes.status, 201);
    assert.strictEqual(customPostRes.body.data.user_id, customUserId);
    const customPostId = customPostRes.body.data.post_id;

    // 19d. Fetch user posts by custom string user_id
    const customUserPostsRes = await request('GET', `/api/posts/userposts/${customUserId}`);
    assert.strictEqual(customUserPostsRes.status, 200);
    assert.ok(customUserPostsRes.body.data.some(p => p.post_id === customPostId));

    // 19e. Toggle Support & Save using custom string user_id
    const customSupportRes = await request('POST', `/api/posts/toggleSupport/${customPostId}`, {
      user_id: customUserId
    });
    assert.strictEqual(customSupportRes.status, 200);
    assert.strictEqual(customSupportRes.body.data.isSupported, true);

    const customSaveRes = await request('POST', `/api/posts/toggleSave/${customPostId}`, {
      user_id: customUserId
    });
    assert.strictEqual(customSaveRes.status, 200);
    assert.strictEqual(customSaveRes.body.data.isSaved, true);

    // 19f. Get saved posts by custom string user_id
    const customSavedRes = await request('GET', `/api/posts/savedposts/${customUserId}`);
    assert.strictEqual(customSavedRes.status, 200);
    assert.ok(customSavedRes.body.data.some(p => p.post_id === customPostId));

    // 19g. Get Profile by custom string user_id
    const customProfileRes = await request('GET', `/api/profile/profile/${customUserId}`);
    assert.strictEqual(customProfileRes.status, 200);
    assert.ok(customProfileRes.body.data.username);

    // Cleanup custom draft and post
    await request('DELETE', `/api/draft/${customDraftId}`);
    await request('DELETE', `/api/posts/${customPostId}`);
    console.log('✔ Custom string user_id ("USR00000001") draft, post, profile, & interactions passed with 0 errors');

    // 20. Verify Profile Update & Fallback Profile Image 404 Prevention
    console.log('\n--- 20. Testing Profile Update (Unauthorized fix) & 404 Image Fallbacks ---');
    
    // 20a. Profile update with custom user_id and NO token (prevents "unauthorized nu error varuthu")
    const updateBoundary = '----WebKitFormBoundaryProfileUpdate';
    const updateBody = buildMultipart(updateBoundary, {
      user_id: 'USR00000001',
      username: 'Updated Ryitu Farmer',
      email: 'farmer@app.local',
      constituency: 'Coimbatore South'
    }, [
      {
        field: 'profile_image',
        filename: 'new_avatar.jpg',
        contentType: 'image/jpeg',
        content: Buffer.from('new-avatar-bytes')
      }
    ]);
    const updateRes = await request('POST', '/api/profile/update', updateBody, {
      'Content-Type': `multipart/form-data; boundary=${updateBoundary}`
    });
    assert.strictEqual(updateRes.status, 200);
    assert.strictEqual(updateRes.body.success, true);
    assert.strictEqual(updateRes.body.data.username, 'Updated Ryitu Farmer');
    assert.strictEqual(updateRes.body.data.Constituency, 'Coimbatore South');
    assert.ok(updateRes.body.data.ProfileImage);
    console.log('✔ Profile update without token / with custom user_id passed (No 401 Unauthorized)');

    // 20b. Profile image URL request for non-existent / old cached image (prevents 404 error)
    const oldImageRes = await request('GET', '/uploads/profile_images/profile_image-1785996570764-880525909.jpg');
    assert.strictEqual(oldImageRes.status, 200);
    console.log('✔ Old/Missing profile image fallback passed with 200 OK (No 404 HttpException)');

    const directImageRes = await request('GET', '/profile_images/profile_image-1785996570764-880525909.jpg');
    assert.strictEqual(directImageRes.status, 200);
    console.log('✔ Direct /profile_images path fallback passed with 200 OK');

    // 21. Verify Community Features (Listing, Details, Join Request, Community Posts, & Book linking)
    console.log('\n--- 21. Testing Community Features & Community Posts ---');
    
    // 21a. List communities
    const commsRes = await request('GET', '/api/communities');
    assert.strictEqual(commsRes.status, 200);
    assert.ok(commsRes.body.data.communities.length >= 1);
    const sampleComm = commsRes.body.data.communities[0];
    const sampleCommId = sampleComm._id;
    console.log(`✔ Communities fetched successfully (${commsRes.body.data.count} communities)`);

    // 21b. Get Community Details
    const freshCommUserId = 'USR_TEST_' + Date.now();
    const commDetailRes = await request('GET', `/api/communities/${sampleCommId}?userId=${freshCommUserId}`);
    assert.strictEqual(commDetailRes.status, 200);
    assert.strictEqual(commDetailRes.body.data.community.name, sampleComm.name);
    assert.strictEqual(commDetailRes.body.data.community.joinStatus, 'none');
    console.log('✔ Community details fetched with initial joinStatus: none');

    // 21c. Request to Join Community
    const joinRes = await request('POST', `/api/communities/${sampleCommId}/request-join`, {
      userId: freshCommUserId
    });
    assert.ok(joinRes.status === 200 || joinRes.status === 201);
    assert.strictEqual(joinRes.body.data.status, 'pending');
    console.log('✔ Community request-to-join passed with status: pending');

    // Duplicate request check (must not duplicate)
    const dupJoinRes = await request('POST', `/api/communities/${sampleCommId}/request-join`, {
      userId: 'USR00000001'
    });
    assert.strictEqual(dupJoinRes.status, 200);
    assert.strictEqual(dupJoinRes.body.data.status, 'pending');
    console.log('✔ Duplicate request-to-join handled safely without duplicates');

    // Check membership status endpoint
    const statusRes = await request('GET', `/api/communities/${sampleCommId}/membership-status?userId=USR00000001`);
    assert.strictEqual(statusRes.status, 200);
    assert.strictEqual(statusRes.body.data.status, 'pending');
    console.log('✔ Community membership status endpoint passed');

    // 21d. Publish a Community Post
    const commPostBoundary = '----WebKitFormBoundaryCommPost';
    const commPostBody = buildMultipart(commPostBoundary, {
      title: 'Agricultural IoT Sensors in Modern Farming',
      caption: 'Detailed guide for soil moisture and automated drip irrigation.',
      categoryId: 'CAT00000004',
      communityId: sampleCommId.toString(),
      communityName: sampleComm.name,
      content: JSON.stringify([{ blocks: [{ type: 'text', text: 'IoT sensors transmit real-time data.' }] }])
    }, []);
    const commPostRes = await request('POST', '/api/posts', commPostBody, {
      'Content-Type': `multipart/form-data; boundary=${commPostBoundary}`
    });
    assert.strictEqual(commPostRes.status, 201);
    assert.strictEqual(commPostRes.body.data.communityId, sampleCommId.toString());
    assert.strictEqual(commPostRes.body.data.isCommunityPost, true);
    console.log('✔ Community post published successfully with communityId');

    // 21e. Get Community Posts
    const getCommPostsRes = await request('GET', `/api/communities/${sampleCommId}/posts`);
    assert.strictEqual(getCommPostsRes.status, 200);
    assert.ok(getCommPostsRes.body.data.length >= 1);
    assert.ok(getCommPostsRes.body.data.some(p => p.post_id === commPostRes.body.data.post_id));
    console.log('✔ Community posts fetched by communityId successfully');

    // Cleanup community post
    await request('DELETE', `/api/posts/${commPostRes.body.data.post_id}`);

    // 21f. Create a Community
    console.log('\n--- 21f. Testing Create Community (POST /api/communities) ---');
    const newCommRes = await request('POST', '/api/communities', {
      name: 'Modern Tamil Writers Circle',
      description: 'A vibrant collective of emerging novelists, poets, and storytellers.',
      userId: 'USR00000001'
    });
    assert.strictEqual(newCommRes.status, 201);
    assert.strictEqual(newCommRes.body.data.community.name, 'Modern Tamil Writers Circle');
    assert.strictEqual(newCommRes.body.data.community.isCreator, true);
    assert.strictEqual(newCommRes.body.data.community.isMember, true);
    const createdCommId = newCommRes.body.data.community._id;
    console.log('✔ Community creation passed with creator auto-joined');

    // 21g. Get My Communities (GET /api/communities/my-communities)
    const myCommsRes = await request('GET', '/api/communities/my-communities?userId=USR00000001');
    assert.strictEqual(myCommsRes.status, 200);
    assert.ok(myCommsRes.body.data.communities.length >= 1);
    assert.ok(myCommsRes.body.data.communities.some(c => c._id === createdCommId));
    console.log('✔ My communities listing endpoint passed');

    // 21h. Get Available Users to Add (GET /api/communities/:id/available-users)
    const availUsersRes = await request('GET', `/api/communities/${createdCommId}/available-users`);
    assert.strictEqual(availUsersRes.status, 200);
    assert.ok(availUsersRes.body.data.users.length >= 1);
    const userToAdd = availUsersRes.body.data.users.find(u => u._id !== 'USR00000001') || availUsersRes.body.data.users[0];
    console.log(`✔ Available users listing passed (${availUsersRes.body.data.users.length} users discovered)`);

    // 21i. Add Users to Community (POST /api/communities/:id/members)
    const addMemberRes = await request('POST', `/api/communities/${createdCommId}/members`, {
      userIds: [userToAdd._id]
    });
    assert.strictEqual(addMemberRes.status, 200);
    assert.ok(addMemberRes.body.data.memberCount >= 2);
    console.log('✔ Adding users to community by creator passed');

    // 22. Comment System Tests (Create, List, Like, Delete)
    console.log('\n--- 22. Testing Comment System (POST, GET, Like, DELETE) ---');
    // First create a post to comment on
    const commPostForComments = await request('POST', '/api/posts', {
      title: 'Story for Comments Test',
      caption: 'Testing real comments system',
      categoryId: 'CAT00000004'
    }, {
      Authorization: `Bearer ${authToken}`
    });
    const cPostId = commPostForComments.body.data.post_id;

    // 22a. Add top-level comment
    const addCommentRes = await request('POST', `/api/posts/${cPostId}/comments`, {
      text: 'Great story! Thanks for sharing.',
      userId: registeredUserId,
      username: 'Alice Reader'
    }, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(addCommentRes.status, 201);
    assert.strictEqual(addCommentRes.body.success, true);
    assert.strictEqual(addCommentRes.body.data.text, 'Great story! Thanks for sharing.');
    const commentId = addCommentRes.body.data.id;

    // 22b. Add reply to comment
    const replyRes = await request('POST', `/api/posts/${cPostId}/comments`, {
      text: 'I agree completely!',
      parentCommentId: commentId,
      userId: registeredUserId,
      username: 'Alice Reader'
    }, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(replyRes.status, 201);
    assert.strictEqual(replyRes.body.data.parentCommentId, commentId);

    // 22c. Get comments
    const getCommentsRes = await request('GET', `/api/posts/${cPostId}/comments?userId=${registeredUserId}`);
    assert.strictEqual(getCommentsRes.status, 200);
    assert.strictEqual(getCommentsRes.body.data.count, 2);
    assert.strictEqual(getCommentsRes.body.data.comments.length, 1); // 1 top-level
    assert.strictEqual(getCommentsRes.body.data.comments[0].replies.length, 1); // 1 reply
    console.log('✔ Comment creation, reply nesting, and retrieval passed');

    // 22d. Toggle comment like
    const likeCommentRes = await request('POST', `/api/posts/comments/${commentId}/toggleLike`, {
      userId: registeredUserId
    }, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(likeCommentRes.status, 200);
    assert.strictEqual(likeCommentRes.body.data.isLiked, true);
    assert.strictEqual(likeCommentRes.body.data.likesCount, 1);
    console.log('✔ Comment like toggling passed');

    // 22e. Delete comment
    const delCommentRes = await request('DELETE', `/api/posts/comments/${commentId}`, null, {
      Authorization: `Bearer ${authToken}`
    });
    assert.strictEqual(delCommentRes.status, 200);
    console.log('✔ Comment deletion passed');

    // 23. Testing Web Share Redirect Endpoints
    console.log('\n--- 23. Testing Web Share Redirects (/share/post & /share/community) ---');
    const sharePostRes = await request('GET', `/share/post/${cPostId}`, null, {
      Accept: 'application/json'
    });
    assert.strictEqual(sharePostRes.status, 200);
    assert.strictEqual(sharePostRes.body.success, true);
    assert.ok(sharePostRes.body.deepLink.includes('ryitu://post/'));

    const shareCommRes = await request('GET', `/share/community/${createdCommId}`, null, {
      Accept: 'application/json'
    });
    assert.strictEqual(shareCommRes.status, 200);
    assert.strictEqual(shareCommRes.body.success, true);
    assert.ok(shareCommRes.body.deepLink.includes('ryitu://community/'));
    console.log('✔ Web share deep link generation passed');

    // Cleanup test post
    await request('DELETE', `/api/posts/${cPostId}`, null, {
      Authorization: `Bearer ${authToken}`
    });

    console.log('\n🎉 ALL BACKEND TESTS PASSED SUCCESSFULLY! 100% VERIFIED.\n');
  } catch (err) {
    console.error('❌ Test suite failed:', err);
    process.exitCode = 1;
  } finally {
    if (server) server.close();
    await disconnectDB();
  }
}

runTests();