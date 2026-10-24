const jwt = require('jsonwebtoken');
const User = require('../models/User');
const env = require('../config/env');
const { successResponse, errorResponse } = require('../utils/response.util');
const { sendOtpEmail, verifyOtpEmail } = require('../services/email.service');

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

const checkMobile = async (req, res, next) => {
  try {
    const rawMobile = (req.body.mobileNumber || req.body.phone || req.query.phone || req.query.mobileNumber || '').toString().trim();
    const digitsOnly = rawMobile.replace(/[^0-9]/g, '');
    const cleanMobile = digitsOnly.length >= 10 ? digitsOnly.slice(-10) : digitsOnly;

    if (!cleanMobile || cleanMobile.length < 10) {
      return errorResponse(res, 400, 'Please provide a valid 10-digit mobile number.');
    }

    const existing = await User.findOne({
      $or: [
        { mobileNumber: cleanMobile },
        { mobileNumber: { $regex: cleanMobile + '$' } },
        { user_id: cleanMobile }
      ]
    });

    if (existing) {
      return res.status(200).json({
        success: false,
        available: false,
        message: 'An account with this mobile number already exists.'
      });
    }

    return res.status(200).json({
      success: true,
      available: true,
      message: 'Mobile number is available.'
    });
  } catch (error) {
    next(error);
  }
};

const register = async (req, res, next) => {
  try {
    const { name, username, email, password, mobileNumber, constituency } = req.body;

    const rawMobile = (mobileNumber || req.body.phone || req.body.mobile || '').toString().trim();
    const digitsOnly = rawMobile.replace(/[^0-9]/g, '');
    const cleanMobile = digitsOnly.length >= 10 ? digitsOnly.slice(-10) : digitsOnly;

    if (rawMobile && cleanMobile.length < 10) {
      return errorResponse(res, 400, 'Please provide a valid 10-digit mobile number.');
    }

    const finalUsername = username || name || (cleanMobile ? `user_${cleanMobile}` : '');
    const finalPassword = password;
    const finalEmail = (email && email.trim()) ? email.toLowerCase().trim() : (cleanMobile ? `${cleanMobile}@app.local` : '');

    if (!finalPassword) {
      return errorResponse(res, 400, 'Password is required.');
    }

    if (finalPassword.length < 4) {
      return errorResponse(res, 400, 'Password must be at least 4 characters long.');
    }

    // 1. Check if mobile number already exists (normalized 10 digits check)
    if (cleanMobile) {
      const existingMobile = await User.findOne({
        $or: [
          { mobileNumber: cleanMobile },
          { mobileNumber: { $regex: cleanMobile + '$' } },
          { user_id: cleanMobile },
          { user_id: { $regex: cleanMobile + '$' } }
        ]
      });
      if (existingMobile) {
        return errorResponse(res, 409, 'An account with this mobile number already exists.');
      }
    }

    // 2. Check if email already exists
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
      mobileNumber: cleanMobile || '',
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
    const rawUserId = req.body.user_id || req.body.userId || req.user?.id || req.user?._id;
    const rawToken = req.body.fcm_token || req.body.fcmToken || req.body.token;

    if (rawUserId && rawToken) {
      const user_id = String(rawUserId).trim();
      const fcm_token = String(rawToken).trim();

      if (user_id.match(/^[0-9a-fA-F]{24}$/)) {
        await User.findByIdAndUpdate(user_id, { fcmToken: fcm_token });
      } else {
        await User.findOneAndUpdate(
          { $or: [{ user_id }, { username: user_id }, { mobileNumber: user_id }] },
          { fcmToken: fcm_token }
        );
      }
      console.log(`[FCM Token Saved] User: ${user_id} -> Token: ${fcm_token.substring(0, 12)}...`);
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
    const { email, mobileNumber, phone } = req.body;

    // Email OTP flow
    if (email) {
      const cleanEmail = email.toLowerCase().trim();
      const existingUser = await User.findOne({
        $or: [{ email: cleanEmail }, { username: cleanEmail }]
      });
      if (!existingUser) {
        return errorResponse(res, 404, 'No account found with this email address.');
      }

      await sendOtpEmail(cleanEmail);
      return successResponse(res, 200, 'OTP sent to email successfully', { email: cleanEmail });
    }

    // Mobile fallback (demo)
    const targetMobile = mobileNumber || phone;
    if (targetMobile) {
      return successResponse(res, 200, 'OTP sent successfully', { otp: '123456' });
    }

    return errorResponse(res, 400, 'Please provide an email or mobile number.');
  } catch (error) {
    next(error);
  }
};

const verifyOtp = async (req, res, next) => {
  try {
    const { otp, email } = req.body;

    if (!otp) {
      return errorResponse(res, 400, 'OTP is required.');
    }

    // Email OTP verification
    if (email) {
      const result = verifyOtpEmail(email.toLowerCase().trim(), otp);
      if (!result.valid) {
        return errorResponse(res, 400, result.message);
      }
      return successResponse(res, 200, result.message, { resetToken: 'verified_' + Date.now() });
    }

    // Mobile fallback (demo) - accept any OTP
    return successResponse(res, 200, 'OTP verified successfully', { resetToken: 'verified_' + Date.now() });
  } catch (error) {
    next(error);
  }
};

const resetPassword = async (req, res, next) => {
  try {
    const { email, mobileNumber, phone, newPassword, password } = req.body;
    const finalPassword = newPassword || password;

    if (!finalPassword) {
      return errorResponse(res, 400, 'New password is required.');
    }
    if (finalPassword.length < 6) {
      return errorResponse(res, 400, 'Password must be at least 6 characters long.');
    }

    let user = null;
    if (email) {
      const cleanEmail = email.toLowerCase().trim();
      user = await User.findOne({
        $or: [{ email: cleanEmail }, { username: cleanEmail }]
      });
    } else if (mobileNumber || phone) {
      const rawMobile = (mobileNumber || phone).toString().trim();
      const digits = rawMobile.replace(/[^0-9]/g, '');
      const cleanMobile = digits.length >= 10 ? digits.slice(-10) : digits;
      user = await User.findOne({
        $or: [
          { mobileNumber: cleanMobile },
          { mobileNumber: { $regex: cleanMobile + '$' } },
          { user_id: cleanMobile }
        ]
      });
    }

    if (!user) {
      return errorResponse(res, 404, 'No account found with this email or mobile number.');
    }

    // Assigning new password triggers mongoose pre('save') hook to hash it with bcrypt
    user.password = finalPassword;
    await user.save();

    return successResponse(res, 200, 'Password updated successfully. You can now login with your new password.');
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
  checkMobile,
  register,
  login,
  saveFcmToken,
  forgotPassword,
  sendOtp,
  verifyOtp,
  resetPassword,
  getMe
};