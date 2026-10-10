const fs = require('fs');
const path = require('path');
const env = require('../config/env');

/**
 * Storage abstraction interface
 */
class BaseStorageProvider {
  async saveFile(file, subfolder) {
    throw new Error('Not implemented');
  }
  getFileUrl(fileName, subfolder) {
    throw new Error('Not implemented');
  }
  async deleteFile(fileName, subfolder) {
    throw new Error('Not implemented');
  }
  resolveLocalPath(fileName, subfolder) {
    throw new Error('Not implemented');
  }
}

/**
 * Local Disk Storage Provider
 * Safe against path traversal and prepares relative/full URLs.
 */
class LocalStorageProvider extends BaseStorageProvider {
  constructor(baseDir, baseUrl) {
    super();
    this.baseDir = path.resolve(baseDir);
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  _getSafePath(fileName, subfolder = '') {
    // Prevent path traversal
    const safeSub = path.normalize(subfolder).replace(/^(\.\.[\/\\])+/, '');
    const safeName = path.basename(fileName);
    return path.join(this.baseDir, safeSub, safeName);
  }

  getFileUrl(fileName, subfolder = '') {
    if (!fileName) return '';
    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      return fileName;
    }
    const safeSub = subfolder.replace(/\\/g, '/');
    const safeName = path.basename(fileName);
    const subPath = safeSub ? `${safeSub}/${safeName}` : safeName;
    return `${this.baseUrl}/uploads/${subPath}`;
  }

  resolveLocalPath(fileName, subfolder = '') {
    return this._getSafePath(fileName, subfolder);
  }

  async saveFile(bufferOrStream, fileName, subfolder = '') {
    const targetPath = this._getSafePath(fileName, subfolder);
    await fs.promises.mkdir(path.dirname(targetPath), { recursive: true });

    if (Buffer.isBuffer(bufferOrStream)) {
      await fs.promises.writeFile(targetPath, bufferOrStream);
    } else if (typeof bufferOrStream === 'string') {
      // If temporary file path was passed, move it
      await fs.promises.rename(bufferOrStream, targetPath);
    }
    return fileName;
  }

  async deleteFile(fileName, subfolder = '') {
    try {
      const targetPath = this._getSafePath(fileName, subfolder);
      if (fs.existsSync(targetPath)) {
        await fs.promises.unlink(targetPath);
      }
      return true;
    } catch (err) {
      console.warn(`[Storage] Failed to delete file ${fileName}:`, err.message);
      return false;
    }
  }
}

// Storage instance configured with uploads directory and base URL
const storageService = new LocalStorageProvider(
  path.join(__dirname, '../../uploads'),
  env.BASE_URL
);

module.exports = {
  storageService,
  LocalStorageProvider,
  BaseStorageProvider
};