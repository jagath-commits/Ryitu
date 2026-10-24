const assert = require('assert');
const http = require('http');
const mongoose = require('mongoose');
const app = require('../src/app');
const env = require('../src/config/env');
const AppConfig = require('../src/models/AppConfig');

const runVersionTests = async () => {
  console.log('🚀 Running App Version and Forced Update Tests...');

  await mongoose.connect(env.MONGODB_URI);

  const server = http.createServer(app);
  await new Promise(resolve => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}`;

  const request = (method, path, body = null) => {
    return new Promise((resolve, reject) => {
      const url = new URL(path, baseUrl);
      const req = http.request(
        url,
        {
          method,
          headers: body ? { 'Content-Type': 'application/json' } : {}
        },
        res => {
          let data = '';
          res.on('data', chunk => (data += chunk));
          res.on('end', () => {
            try {
              resolve({
                status: res.statusCode,
                body: data ? JSON.parse(data) : null
              });
            } catch (e) {
              resolve({ status: res.statusCode, body: data });
            }
          });
        }
      );
      req.on('error', reject);
      if (body) req.write(JSON.stringify(body));
      req.end();
    });
  };

  try {
    // 1. GET /api/app/version
    const res1 = await request('GET', '/api/app/version');
    assert.strictEqual(res1.status, 200);
    assert.strictEqual(res1.body.success, true);
    assert.strictEqual(typeof res1.body.data.minBuildNumber, 'number');
    assert.strictEqual(typeof res1.body.data.forceUpdate, 'boolean');
    assert.ok(res1.body.data.updateUrl);
    console.log('✔ GET /api/app/version passed:', res1.body.data);

    // 2. GET /api/version alias
    const resAlias = await request('GET', '/api/version');
    assert.strictEqual(resAlias.status, 200);
    assert.strictEqual(resAlias.body.data.minBuildNumber, res1.body.data.minBuildNumber);
    console.log('✔ GET /api/version alias passed');

    // 3. POST /api/app/version update
    const updatePayload = {
      minBuildNumber: 7,
      latestBuildNumber: 7,
      minVersion: '1.0.5',
      latestVersion: '1.0.5',
      forceUpdate: true,
      updateUrl: 'https://play.google.com/store/apps/details?id=com.ritpen',
      title: 'Update Required',
      message: 'A new version of Ritpen is available. Please update the app to continue.'
    };
    const resPost = await request('POST', '/api/app/version', updatePayload);
    assert.strictEqual(resPost.status, 200);
    assert.strictEqual(resPost.body.data.minBuildNumber, 7);
    assert.strictEqual(resPost.body.data.forceUpdate, true);
    console.log('✔ POST /api/app/version update passed');

    console.log('🎉 ALL APP VERSION TESTS PASSED SUCCESSFULLY!');
  } finally {
    server.close();
    await mongoose.disconnect();
  }
};

runVersionTests().catch(err => {
  console.error('❌ Version test failed:', err);
  process.exit(1);
});
