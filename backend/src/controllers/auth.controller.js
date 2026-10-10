const jwt = require('jsonwebtoken');
const User = require('../models/User');
const env = require('../config/env');
const { successResponse, errorResponse } = require('../utils/response.util');

const generateToken = (userId) => {
  return jwt.sign({ id: userId }, env.JWT_SECRET, {
    expiresIn: env.JWT_EXPIRES_IN
  });
};

const formatUserData = (user, token) => ({
  token,
  user_id: user._id.toString(),
  _id: user._id.toString(),
  user_mobile: user.mobileNumber || '',
  username: user.username || user.name || '',
  name: user.name || user.username || '',
  email: user.email || '',
  constituency: user.constituency || '',
  profile_image: user.profileImage || '',
  profileImage: user.profileImage || '',
  user: {
    _id: user._id,
    name: user.name,
    username: user.username,
    email: user.email,
    profileImage: user.profileImage,
    createdAt: user.createdAt
  }
});

const register = async (req, res, next) => {
  try {
    const { name, username, email, password, mobileNumber, constituency } = req.body;
    const finalUsername = username || name || (mobileNumber ? `user_${mobileNumber}` : '');
    const finalPassword = password;
    const finalEmail = (email && email.trim()) ? email.toLowerCase().trim() : (mobileNumber ? `${mobileNumber}@app.local` : '');

    if (!finalPassword) {
      return errorResponse(res, 400, 'Password is required.');
    }

    if (finalPassword.length < 4) {
      return errorResponse(res, 400, 'Password must be at least 4 characters long.');
    }

    // Check if user already exists
    if (mobileNumber) {
      const existingMobile = await User.findOne({ mobileNumber });
      if (existingMobile) {
        return errorResponse(res, 409, 'An account with this mobile number already exists.');
      }
    }
    if (finalEmail) {
      const existingEmail = await User.findOne({ email: finalEmail });
      if (existingEmail) {
        return errorResponse(res, 409, 'An account with this email address already exists.');
      }
    }

    let profileImage = '';
    if (req.file) {
      profileImage = req.file.filename;
    }

    const user = await User.create({
      username: finalUsername,
      name: finalUsername,
      email: finalEmail,
      mobileNumber: mobileNumber || '',
      password: finalPassword,
      constituency: constituency || '',
      profileImage
    });

    const token = generateToken(user._id);

    return successResponse(res, 201, 'User registered successfully', formatUserData(user, token));
  } catch (error) {
    next(error);
  }
};

const login = async (req, res, next) => {
  try {
    const { email, password, mobileNumber } = req.body;

    if (!password) {
      return errorResponse(res, 400, 'Password is required.');
    }

    let query = null;
    if (mobileNumber) {
      query = { mobileNumber };
    } else if (email) {
      query = { email: email.toLowerCase().trim() };
    } else {
      return errorResponse(res, 400, 'Please provide mobile number or email.');
    }

    const user = await User.findOne(query).select('+password');
    if (!user) {
      return errorResponse(res, 401, 'Invalid credentials.');
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return errorResponse(res, 401, 'Invalid credentials.');
    }

    const token = generateToken(user._id);

    return successResponse(res, 200, 'Login successful', formatUserData(user, token));
  } catch (error) {
    next(error);
  }
};

const saveFcmToken = async (req, res, next) => {
  try {
    const { user_id, fcm_token } = req.body;
    if (user_id && fcm_token) {
      if (typeof user_id === 'string' && user_id.match(/^[0-9a-fA-F]{24}$/)) {
        await User.findByIdAndUpdate(user_id, { fcmToken: fcm_token });
      } else {
        await User.findOneAndUpdate(
          { $or: [{ user_id }, { username: user_id }, { mobileNumber: user_id }] },
          { fcmToken: fcm_token }
        );
      }
    }
    return successResponse(res, 200, 'FCM token saved successfully');
  } catch (error) {
    next(error);
  }
};

const forgotPassword = async (req, res, next) => {
  try {
    const { email, mobileNumber } = req.body;
    return successResponse(res, 200, 'Password reset instructions have been sent.');
  } catch (error) {
    next(error);
  }
};

const sendOtp = async (req, res, next) => {
  try {
    const { mobileNumber, phone } = req.body;
    const targetMobile = mobileNumber || phone;
    // For demo/development, OTP is 123456
    return successResponse(res, 200, 'OTP sent successfully', { otp: '123456' });
  } catch (error) {
    next(error);
  }
};

const verifyOtp = async (req, res, next) => {
  try {
    const { otp } = req.body;
    // Accept 123456 or any 6-digit OTP in dev
    return successResponse(res, 200, 'OTP verified successfully');
  } catch (error) {
    next(error);
  }
};

const resetPassword = async (req, res, next) => {
  try {
    const { mobileNumber, password } = req.body;
    if (mobileNumber && password) {
      const user = await User.findOne({ mobileNumber });
      if (user) {
        user.password = password;
        await user.save();
      }
    }
    return successResponse(res, 200, 'Password reset successfully');
  } catch (error) {
    next(error);
  }
};

const getMe = async (req, res, next) => {
  try {
    return successResponse(res, 200, 'User profile fetched successfully', {
      user: {
        _id: req.user._id,
        name: req.user.name,
        username: req.user.username,
        email: req.user.email,
        mobileNumber: req.user.mobileNumber,
        profileImage: req.user.profileImage,
        createdAt: req.user.createdAt
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  saveFcmToken,
  forgotPassword,
  sendOtp,
  verifyOtp,
  resetPassword,
  getMe
};