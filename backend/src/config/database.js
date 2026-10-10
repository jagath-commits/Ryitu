const mongoose = require('mongoose');
const env = require('./env');

let memoryServer = null;

const connectDB = async () => {
  try {
    mongoose.set('strictQuery', false);
    await mongoose.connect(env.MONGODB_URI, {
      serverSelectionTimeoutMS: 2000
    });
    console.log('[MongoDB] Connected successfully');
  } catch (error) {
    console.warn('[MongoDB] Primary connection failed (' + error.message + '). Initializing embedded MongoDB fallback...');
    try {
      const { MongoMemoryServer } = require('mongodb-memory-server');
      memoryServer = await MongoMemoryServer.create();
      const fallbackUri = memoryServer.getUri();
      await mongoose.connect(fallbackUri);
      console.log('[MongoDB] Connected to embedded in-memory database: ' + fallbackUri);
    } catch (fallbackError) {
      console.error('[MongoDB] Embedded fallback failed:', fallbackError.message);
      throw fallbackError;
    }
  }
};

const disconnectDB = async () => {
  try {
    await mongoose.disconnect();
    if (memoryServer) {
      await memoryServer.stop();
    }
    console.log('[MongoDB] Disconnected successfully');
  } catch (err) {
    console.error('[MongoDB] Error during disconnect:', err.message);
  }
};

module.exports = { connectDB, disconnectDB };