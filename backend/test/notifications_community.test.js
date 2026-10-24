const assert = require('assert');
const mongoose = require('mongoose');
const { connectDB } = require('../src/config/database');
const User = require('../src/models/User');
const Community = require('../src/models/Community');
const CommunityMember = require('../src/models/CommunityMember');
const Post = require('../src/models/Post');
const Notification = require('../src/models/Notification');
const notificationService = require('../src/services/notification.service');

const BASE_URL = 'http://localhost:3001/api';

async function runTests() {
  console.log('=== Starting Notification & Community Integration Tests ===\n');

  await connectDB();

  const userA_id = 'USR_TEST_A_' + Date.now();
  const userB_id = 'USR_TEST_B_' + Date.now();
  const userC_id = 'USR_TEST_C_' + Date.now();

  // Create real test users in DB
  const userA = await User.create({
    user_id: userA_id,
    name: 'Arun Author',
    username: 'arun_author',
    password: 'password123',
    email: `arun_${Date.now()}@example.com`
  });

  const userB = await User.create({
    user_id: userB_id,
    name: 'Priya Reader',
    username: 'priya_reader',
    password: 'password123',
    email: `priya_${Date.now()}@example.com`
  });

  const userC = await User.create({
    user_id: userC_id,
    name: 'Karthik Member',
    username: 'karthik_member',
    password: 'password123',
    email: `karthik_${Date.now()}@example.com`
  });

  console.log('✔ Test accounts created:', userA.name, userB.name, userC.name);

  // Scenario 1: User A publishes a post; other users get notification, User A does not
  console.log('\n--- Scenario 1: New Post Fan-out ---');
  const postRes = await fetch(`${BASE_URL}/posts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      title: 'Guide to Organic Farming in Tamil Nadu',
      caption: 'Detailed handbook on soil enrichment and drip irrigation.',
      user_id: userA._id.toString(),
      username: userA.name,
      content: JSON.stringify([{ blocks: [{ type: 'text', text: 'Soil preparation is vital.' }] }])
    })
  });
  const postData = await postRes.json();
  assert.strictEqual(postData.success, true, 'Post creation must succeed');
  const postId = postData.data.post_id || postData.data._id;
  console.log('✔ User A published post:', postId);

  // Wait a moment for async fan-out
  await new Promise(r => setTimeout(r, 1200));

  const notifsUserB = await Notification.find({ recipientId: userB._id.toString(), type: 'new_post' });
  const notifsUserA = await Notification.find({ recipientId: userA._id.toString(), type: 'new_post', postId });

  assert.strictEqual(notifsUserA.length, 0, 'User A should NEVER receive a new post notification for their own post');
  assert.ok(notifsUserB.length >= 1, 'User B should receive new post notification');
  assert.strictEqual(notifsUserB[0].title, 'New Post');
  assert.strictEqual(notifsUserB[0].body, `${userA.name} shared a new post.`);
  assert.strictEqual(notifsUserB[0].actorName, userA.name);
  console.log('✔ User B received:', notifsUserB[0].body);
  console.log('✔ User A received: 0 notifications (no self-notification)');

  // Scenario 2: User B likes User A's post; User A receives notification showing User B's name
  console.log("\n--- Scenario 2: Like Notification ---");
  const likeRes = await fetch(`${BASE_URL}/posts/${postId}/support`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: userB._id.toString() })
  });
  const likeData = await likeRes.json();
  assert.strictEqual(likeData.success, true);
  assert.strictEqual(likeData.data.isSupported, true);

  await new Promise(r => setTimeout(r, 600));

  const likeNotifsA = await Notification.find({ recipientId: userA._id.toString(), type: 'post_like' });
  assert.strictEqual(likeNotifsA.length, 1, "User A should receive like notification");
  assert.strictEqual(likeNotifsA[0].title, 'New Like');
  assert.strictEqual(likeNotifsA[0].body, `${userB.name} liked your post.`);
  assert.strictEqual(likeNotifsA[0].actorName, userB.name);
  console.log('✔ User A received:', likeNotifsA[0].body);

  // Test like deduplication: repeated like toggle should not create duplicate spam records
  await fetch(`${BASE_URL}/posts/${postId}/support`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: userB._id.toString() })
  }); // untoggle
  await fetch(`${BASE_URL}/posts/${postId}/support`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: userB._id.toString() })
  }); // retoggle
  await new Promise(r => setTimeout(r, 600));

  const likeNotifsCount = await Notification.countDocuments({
    recipientId: userA._id.toString(),
    actorId: userB._id.toString(),
    type: 'post_like',
    postId
  });
  assert.strictEqual(likeNotifsCount, 1, 'Like notification must be deduplicated without duplicate spam');
  console.log('✔ Like notification deduplicated successfully (count = 1)');

  // Scenario 3: User B comments on User A's post; User A receives comment notification with preview
  console.log("\n--- Scenario 3: Comment Notification ---");
  const commentRes = await fetch(`${BASE_URL}/posts/${postId}/comments`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text: 'Super practical guide! Keep it up.',
      userId: userB._id.toString(),
      username: userB.name
    })
  });
  const commentData = await commentRes.json();
  assert.strictEqual(commentData.success, true);

  await new Promise(r => setTimeout(r, 600));

  const commentNotifsA = await Notification.find({ recipientId: userA._id.toString(), type: 'post_comment' });
  assert.strictEqual(commentNotifsA.length, 1, "User A should receive comment notification");
  assert.strictEqual(commentNotifsA[0].title, 'New Comment');
  assert.strictEqual(commentNotifsA[0].body, `${userB.name} commented on your post: "Super practical guide! Keep it up."`);
  console.log('✔ User A received:', commentNotifsA[0].body);

  // Scenario 4 & 5 & 6: Community Creation, My Communities Separation, Join Request
  console.log("\n--- Scenario 4, 5, 6: Community Management & Join Requests ---");
  const commRes = await fetch(`${BASE_URL}/communities`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: 'Tamil Organic Cultivators',
      description: 'Exchange of indigenous farming wisdom and modern sustainable techniques.',
      userId: userA._id.toString()
    })
  });
  const commData = await commRes.json();
  assert.strictEqual(commData.success, true);
  const commId = commData.data.community._id;
  console.log('✔ User A created community:', commData.data.community.name, commId);

  // User B requests to join User A's community
  const joinReqRes = await fetch(`${BASE_URL}/communities/${commId}/request-join`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: userB._id.toString() })
  });
  const joinReqData = await joinReqRes.json();
  assert.strictEqual(joinReqData.success, true);
  console.log('✔ User B submitted join request');

  await new Promise(r => setTimeout(r, 600));

  // Verify User A (Owner) received join request notification
  const joinNotifsA = await Notification.find({
    recipientId: userA._id.toString(),
    type: 'community_join_request'
  });
  assert.strictEqual(joinNotifsA.length, 1, 'Community owner should receive join request notification');
  assert.strictEqual(joinNotifsA[0].title, 'New Community Join Request');
  assert.strictEqual(joinNotifsA[0].body, `${userB.name} requested to join "Tamil Organic Cultivators".`);
  console.log('✔ User A received join request notification:', joinNotifsA[0].body);

  // Scenario 7: My Communities Separation
  console.log("\n--- Scenario 7: My Communities Separation ---");
  const myCommRes = await fetch(`${BASE_URL}/communities/my-communities?userId=${userA._id}`);
  const myCommData = await myCommRes.json();
  assert.strictEqual(myCommData.success, true);

  const createdList = myCommData.data.createdCommunities;
  const joinedList = myCommData.data.joinedCommunities;

  assert.ok(createdList.some(c => c._id === commId), 'Created communities must contain Tamil Organic Cultivators');
  assert.ok(!joinedList.some(c => c._id === commId), 'Joined communities MUST NOT contain communities created by User A');

  const createdItem = createdList.find(c => c._id === commId);
  assert.strictEqual(createdItem.pendingRequestsCount, 1, 'Created community must show 1 pending request');
  console.log('✔ Tab 1 (Created by Me): 1 community with pendingRequestsCount = 1');
  console.log('✔ Tab 2 (Joined Communities): Does not mix created communities');

  // Scenario 8: Owner views join requests for community
  console.log("\n--- Scenario 8: Viewing Community Join Requests ---");
  const listRequestsRes = await fetch(`${BASE_URL}/communities/${commId}/join-requests?userId=${userA._id}`);
  const listRequestsData = await listRequestsRes.json();
  assert.strictEqual(listRequestsData.success, true);
  assert.strictEqual(listRequestsData.data.count, 1);
  const pendingReq = listRequestsData.data.requests[0];
  assert.strictEqual(pendingReq.userId, userB._id.toString());
  assert.strictEqual(pendingReq.name, userB.name);
  console.log('✔ Pending requests for Tamil Organic Cultivators shows:', pendingReq.name, 'Status:', pendingReq.status);

  // Scenario 9: Approve Join Request
  console.log("\n--- Scenario 9: Approving Join Request ---");
  const approveRes = await fetch(`${BASE_URL}/communities/${commId}/join-requests/${pendingReq.id}/action`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'approve',
      userId: userA._id.toString()
    })
  });
  const approveData = await approveRes.json();
  assert.strictEqual(approveData.success, true);
  assert.strictEqual(approveData.data.status, 'approved');
  assert.strictEqual(approveData.data.pendingCount, 0);
  console.log('✔ Request approved. Updated pendingCount:', approveData.data.pendingCount);

  await new Promise(r => setTimeout(r, 600));

  // Verify User B received "Join Request Approved" notification
  const approvedNotifB = await Notification.findOne({
    recipientId: userB._id.toString(),
    type: 'community_join_approved'
  });
  assert.ok(approvedNotifB, 'User B must receive approval notification');
  assert.strictEqual(approvedNotifB.title, 'Join Request Approved');
  assert.strictEqual(approvedNotifB.body, 'Your request to join "Tamil Organic Cultivators" has been approved.');
  console.log('✔ User B received approval notification:', approvedNotifB.body);

  // Scenario 10: Reject Join Request
  console.log("\n--- Scenario 10: Rejecting Join Request ---");
  // User C requests to join
  await fetch(`${BASE_URL}/communities/${commId}/request-join`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: userC._id.toString() })
  });

  const reqCList = await fetch(`${BASE_URL}/communities/${commId}/join-requests?userId=${userA._id}`).then(r => r.json());
  const pendingReqC = reqCList.data.requests[0];

  const rejectRes = await fetch(`${BASE_URL}/communities/${commId}/join-requests/${pendingReqC.id}/action`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'reject',
      userId: userA._id.toString()
    })
  });
  const rejectData = await rejectRes.json();
  assert.strictEqual(rejectData.success, true);
  assert.strictEqual(rejectData.data.status, 'rejected');

  await new Promise(r => setTimeout(r, 600));

  const rejectNotifC = await Notification.findOne({
    recipientId: userC._id.toString(),
    type: 'community_join_rejected'
  });
  assert.ok(rejectNotifC, 'User C must receive update notification');
  assert.strictEqual(rejectNotifC.title, 'Join Request Update');
  assert.strictEqual(rejectNotifC.body, 'Your request to join "Tamil Organic Cultivators" was not approved.');
  console.log('✔ User C received rejection notification:', rejectNotifC.body);

  // Scenario 11 & 12: Notification Read/Unread & Unread Count Consistency
  console.log("\n--- Scenario 11 & 12: Read/Unread & Badge Count ---");
  const countBefore = await fetch(`${BASE_URL}/notifications/unread-count?userId=${userA._id}`).then(r => r.json());
  console.log('✔ User A unread count before marking read:', countBefore.data.unreadCount);

  // Mark all as read
  const markRes = await fetch(`${BASE_URL}/notifications/mark-all-read`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: userA._id.toString() })
  });
  const markData = await markRes.json();
  assert.strictEqual(markData.success, true);

  const countAfter = await fetch(`${BASE_URL}/notifications/unread-count?userId=${userA._id}`).then(r => r.json());
  assert.strictEqual(countAfter.data.unreadCount, 0, 'Unread count must be 0 after marking all read');
  console.log('✔ User A unread count after marking read: 0');

  // Scenario 13: Clean up test records
  console.log("\n--- Cleaning up test records ---");
  await User.deleteMany({ _id: { $in: [userA._id, userB._id, userC._id] } });
  await Post.deleteOne({ _id: postData.data._id });
  await Community.deleteOne({ _id: commId });
  await CommunityMember.deleteMany({ communityId: commId });
  await Notification.deleteMany({
    $or: [
      { recipientId: { $in: [userA._id.toString(), userB._id.toString(), userC._id.toString()] } },
      { actorId: { $in: [userA._id.toString(), userB._id.toString(), userC._id.toString()] } }
    ]
  });
  console.log('✔ Test cleanup complete.');

  console.log('\n======================================================');
  console.log('ALL NOTIFICATION & COMMUNITY TESTS PASSED SUCCESSFULLY!');
  console.log('======================================================\n');
  process.exit(0);
}

runTests().catch(err => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
