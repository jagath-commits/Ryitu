const fs = require('fs');
const path = require('path');
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

let firebaseApp = null;
let messagingInstance = null;

/**
 * Attempts to load and initialize Firebase Admin SDK.
 * Checks for Service Account JSON in standard locations or environment variables.
 */
function initFirebase() {
  if (firebaseApp && messagingInstance) {
    return firebaseApp;
  }

  try {
    const existingApps = getApps();
    if (existingApps.length > 0) {
      firebaseApp = existingApps[0];
      messagingInstance = getMessaging(firebaseApp);
      return firebaseApp;
    }

    let serviceAccount = null;

    // 1. Check if provided directly via FIREBASE_SERVICE_ACCOUNT environment variable (JSON string or base64)
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      try {
        const raw = process.env.FIREBASE_SERVICE_ACCOUNT.trim();
        const jsonStr = raw.startsWith('{')
          ? raw
          : Buffer.from(raw, 'base64').toString('utf8');
        serviceAccount = JSON.parse(jsonStr);
      } catch (err) {
        console.warn('[Firebase Admin] Error parsing FIREBASE_SERVICE_ACCOUNT env:', err.message);
      }
    }

    // 2. Check explicitly defined path in env
    if (!serviceAccount && process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
      const explicitPath = path.resolve(process.cwd(), process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
      if (fs.existsSync(explicitPath)) {
        serviceAccount = JSON.parse(fs.readFileSync(explicitPath, 'utf8'));
      }
    }

    // 3. Check default locations in backend root directory and subdirectories
    if (!serviceAccount) {
      const candidates = [
        path.join(process.cwd(), 'firebase-service-account.json'),
        path.join(process.cwd(), 'backend', 'firebase-service-account.json'),
        path.join(__dirname, '..', '..', 'firebase-service-account.json'),
        path.join(__dirname, '..', 'firebase-service-account.json'),
        path.join(__dirname, 'firebase-service-account.json')
      ];

      for (const candidate of candidates) {
        if (fs.existsSync(candidate)) {
          try {
            serviceAccount = JSON.parse(fs.readFileSync(candidate, 'utf8'));
            console.log(`[Firebase Admin] Loaded service account credentials from: ${candidate}`);
            break;
          } catch (e) {
            console.warn(`[Firebase Admin] Failed reading candidate ${candidate}:`, e.message);
          }
        }
      }
    }

    // 4. Also scan for any file matching *adminsdk*.json in backend/ or root
    if (!serviceAccount) {
      const scanDirs = [process.cwd(), path.join(process.cwd(), 'backend'), path.join(__dirname, '..', '..')];
      for (const dir of scanDirs) {
        if (fs.existsSync(dir)) {
          const files = fs.readdirSync(dir);
          const match = files.find(f => f.toLowerCase().includes('adminsdk') && f.endsWith('.json'));
          if (match) {
            try {
              serviceAccount = JSON.parse(fs.readFileSync(path.join(dir, match), 'utf8'));
              console.log(`[Firebase Admin] Detected SDK key: ${match}`);
              break;
            } catch (_) {}
          }
        }
      }
    }

    // 5. Initialize Firebase Admin if valid credentials obtained
    if (serviceAccount && serviceAccount.project_id && serviceAccount.private_key) {
      if (typeof serviceAccount.private_key === 'string') {
        serviceAccount.private_key = serviceAccount.private_key.replace(/\\n/g, '\n');
      }

      firebaseApp = initializeApp({
        credential: cert(serviceAccount),
        projectId: serviceAccount.project_id
      });
      messagingInstance = getMessaging(firebaseApp);

      global.firebaseApp = firebaseApp;
      global.firebaseMessaging = messagingInstance;

      console.log(`[Firebase Admin] Ready! Connected to Firebase project: ${serviceAccount.project_id}`);
      return firebaseApp;
    }

    console.log(
      '[Firebase Admin] Service account file not yet found at backend/firebase-service-account.json.\n' +
      '  -> In-app notifications are active.'
    );
    return null;
  } catch (error) {
    console.warn('[Firebase Admin Initialization Error]:', error.message);
    return null;
  }
}

// Initial attempt on import
initFirebase();

module.exports = {
  initFirebase,
  getFirebaseApp: () => firebaseApp,
  getMessaging: () => {
    if (!messagingInstance) {
      initFirebase();
    }
    return messagingInstance;
  },
  isFirebaseConfigured: () => !!firebaseApp && !!messagingInstance
};
