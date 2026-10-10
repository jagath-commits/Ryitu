const jwt = require('jsonwebtoken');
const env = require('../config/env');
const User = require('../models/User');
const { errorResponse } = require('../utils/response.util');

const authenticate = async (req, res, next) => {
  try {
    let token = null;
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.split(' ')[1];
    }

    if (!token) {
      return errorResponse(res, 401, 'Authentication token required. Please log in.');
    }

    let decoded;
    try {
      decoded = jwt.verify(token, env.JWT_SECRET);
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return errorResponse(res, 401, 'Authentication token has expired. Please log in again.');
      }
      return errorResponse(res, 401, 'Invalid authentication token.');
    }

    const user = await User.findById(decoded.id);
    if (!user) {
      return errorResponse(res, 401, 'User account associated with this token no longer exists.');
    }

    req.user = user;
    next();
  } catch (error) {
    return errorResponse(res, 500, 'Authentication error', error.message);
  }
};

const optionalAuth = async (req, res, next) => {
  try {
    let token = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.split(' ')[1];
    }
    if (token) {
      try {
        const decoded = jwt.verify(token, env.JWT_SECRET);
        const user = await User.findById(decoded.id);
        if (user) {
          req.user = user;
        }
      } catch (_) {}
    }
    next();
  } catch (_) {
    next();
  }
};

module.exports = { authenticate, optionalAuth };