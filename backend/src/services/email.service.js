const nodemailer = require('nodemailer');
const env = require('../config/env');

// In-memory OTP store: { email: { otp, expiresAt } }
const otpStore = new Map();

// Create Gmail transporter using App Password
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: env.EMAIL_USER,
    pass: env.EMAIL_PASS
  }
});

/**
 * Generate a random 6-digit OTP
 */
const generateOtp = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

/**
 * Send OTP email and store it temporarily (5 min expiry)
 * @param {string} email - Recipient email address
 * @returns {Promise<boolean>}
 */
const sendOtpEmail = async (email) => {
  const otp = generateOtp();
  const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes

  // Save OTP in memory
  otpStore.set(email.toLowerCase(), { otp, expiresAt });

  const mailOptions = {
    from: `"PDF Reader App" <${env.EMAIL_FROM}>`,
    to: email,
    subject: 'Your OTP - PDF Reader App',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
        <div style="background: #4f46e5; padding: 24px; text-align: center;">
          <h1 style="color: #ffffff; margin: 0; font-size: 22px;">PDF Reader App</h1>
        </div>
        <div style="padding: 32px;">
          <h2 style="color: #1f2937; margin-top: 0;">Your OTP Code</h2>
          <p style="color: #6b7280;">Use the following One-Time Password to continue. It is valid for <strong>5 minutes</strong>.</p>
          <div style="background: #f3f4f6; border-radius: 8px; padding: 20px; text-align: center; margin: 24px 0;">
            <span style="font-size: 40px; font-weight: bold; letter-spacing: 10px; color: #4f46e5;">${otp}</span>
          </div>
          <p style="color: #9ca3af; font-size: 13px;">If you did not request this OTP, please ignore this email.</p>
        </div>
        <div style="background: #f9fafb; padding: 16px; text-align: center;">
          <p style="color: #9ca3af; font-size: 12px; margin: 0;">© 2026 PDF Reader App. All rights reserved.</p>
        </div>
      </div>
    `
  };

  await transporter.sendMail(mailOptions);
  return true;
};

/**
 * Verify OTP for a given email
 * @param {string} email
 * @param {string} otp
 * @returns {{ valid: boolean, message: string }}
 */
const verifyOtpEmail = (email, otp) => {
  const key = email.toLowerCase();
  const record = otpStore.get(key);

  if (!record) {
    return { valid: false, message: 'OTP not found. Please request a new OTP.' };
  }

  if (Date.now() > record.expiresAt) {
    otpStore.delete(key);
    return { valid: false, message: 'OTP has expired. Please request a new OTP.' };
  }

  if (record.otp !== otp.toString()) {
    return { valid: false, message: 'Invalid OTP. Please try again.' };
  }

  // OTP verified - remove from store
  otpStore.delete(key);
  return { valid: true, message: 'OTP verified successfully.' };
};

module.exports = {
  sendOtpEmail,
  verifyOtpEmail
};
