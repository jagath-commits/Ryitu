const app = require('./app');
const env = require('./config/env');
const { connectDB, disconnectDB } = require('./config/database');

const startServer = async () => {
  try {
    await connectDB();

    const server = app.listen(env.PORT, () => {
      console.log(`===============================================`);
      console.log(` PDF Book Reader API Server is running!`);
      console.log(` URL: http://localhost:${env.PORT}`);
      console.log(` Health Check: http://localhost:${env.PORT}/api/health`);
      console.log(` Environment: ${env.NODE_ENV}`);
      console.log(`===============================================`);
    });

    server.setTimeout(30 * 60 * 1000); // 30 minutes for large document extractions up to 5000 pages
    server.keepAliveTimeout = 65000;

    // Graceful Shutdown
    const handleShutdown = async (signal) => {
      console.log(`\nReceived ${signal}. Gracefully shutting down...`);
      server.close(async () => {
        await disconnectDB();
        console.log('Server and database closed. Bye!');
        process.exit(0);
      });
    };

    process.on('SIGINT', () => handleShutdown('SIGINT'));
    process.on('SIGTERM', () => handleShutdown('SIGTERM'));
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();