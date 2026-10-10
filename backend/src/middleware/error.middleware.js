const { errorResponse } = require('../utils/response.util');

const errorHandler = (err, req, res, next) => {
  console.error('[Error Middleware]:', err);

  // Multer Errors
  if (err.name === 'MulterError') {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return errorResponse(res, 400, 'File size exceeds the 50MB maximum limit.');
    }
    return errorResponse(res, 400, `File upload error: ${err.message}`);
  }

  if (err.code === 'INVALID_FILE_TYPE') {
    return errorResponse(res, 400, err.message);
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