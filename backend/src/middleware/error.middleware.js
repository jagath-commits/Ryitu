const { errorResponse } = require('../utils/response.util');

const errorHandler = (err, req, res, next) => {
  console.error('[Error Middleware]:', err);

  // Payload / Entity Too Large (Express Body Parser & Proxies)
  if (err.type === 'entity.too.large' || err.status === 413 || err.statusCode === 413) {
    return errorResponse(res, 413, 'Request payload too large. The maximum supported upload size is 100 MB.', {
      code: 'LIMIT_FILE_SIZE'
    });
  }

  // Multer Errors
  if (err.name === 'MulterError') {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return errorResponse(res, 413, 'File size exceeds the 100 MB maximum limit.', {
        code: 'LIMIT_FILE_SIZE'
      });
    }
    if (err.code === 'LIMIT_FIELD_VALUE') {
      return errorResponse(res, 413, 'Form field value exceeds maximum permitted size.', {
        code: 'LIMIT_FIELD_VALUE'
      });
    }
    if (err.code === 'LIMIT_UNEXPECTED_FILE') {
      return errorResponse(res, 400, `Unexpected upload field: ${err.field || 'unknown'}`, {
        code: 'LIMIT_UNEXPECTED_FILE'
      });
    }
    return errorResponse(res, 400, `File upload error: ${err.message}`, { code: err.code || 'MULTER_ERROR' });
  }

  if (err.code === 'INVALID_FILE_TYPE') {
    return errorResponse(res, 400, err.message, { code: 'INVALID_FILE_TYPE' });
  }

  // Mongoose Validation Error
  if (err.name === 'ValidationError') {
    const messages = Object.values(err.errors).map((val) => val.message);
    return errorResponse(res, 400, 'Validation Error', { details: messages });
  }

  // Mongoose Duplicate Key Error (e.g. unique email)
  if (err.code === 11000) {
    const field = Object.keys(err.keyValue || {})[0] || 'field';
    return errorResponse(res, 409, `An account with that ${field} already exists.`);
  }

  // Cast Error (invalid ObjectId)
  if (err.name === 'CastError') {
    return errorResponse(res, 400, `Invalid ID format for ${err.path}.`);
  }

  // Fallback 500
  const message = err.message || 'Internal Server Error';
  return errorResponse(res, err.statusCode || 500, message);
};

module.exports = { errorHandler };