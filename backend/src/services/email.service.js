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

  const fromAddress = env.EMAIL_FROM || env.EMAIL_USER || 'ryitu.app@gmail.com';

  const mailOptions = {
    from: `"Ritpen" <${fromAddress}>`,
    to: email,
    replyTo: fromAddress,
    subject: `Ritpen Verification Code: ${otp}`,
    text: `Your Ritpen Verification Code is: ${otp}\n\nUse this 6-digit code to reset your account password. This code will expire in 5 minutes.\n\nIf you did not request this verification code, please ignore this email or contact support.\n\n© ${new Date().getFullYear()} Ritpen. All rights reserved.`,
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Ritpen Verification Code</title>
      </head>
      <body style="margin: 0; padding: 20px; background-color: #f3f4f6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
        <div style="max-width: 500px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);">
          <!-- Header Banner -->
          <div style="background: linear-gradient(135deg, #0729E8 0%, #041CA1 100%); padding: 32px 24px; text-align: center;">
            <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: 800; letter-spacing: 0.5px;">Ritpen</h1>
            <p style="color: rgba(255, 255, 255, 0.85); margin: 6px 0 0 0; font-size: 14px;">Password Reset Verification</p>
          </div>

          <!-- Body Content -->
          <div style="padding: 36px 32px;">
            <h2 style="color: #111827; margin: 0 0 12px 0; font-size: 20px; font-weight: 700;">Verify Your Account</h2>
            <p style="color: #4b5563; font-size: 15px; line-height: 1.6; margin: 0 0 24px 0;">
              We received a request to reset your Ritpen account password. Enter the one-time code below to proceed.
            </p>

            <!-- OTP Box -->
            <div style="background: #F0F4FF; border: 2px dashed #0729E8; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
              <span style="font-family: 'Courier New', Courier, monospace; font-size: 42px; font-weight: 800; letter-spacing: 12px; color: #0729E8; display: inline-block; padding-left: 12px;">${otp}</span>
            </div>

            <p style="color: #6b7280; font-size: 13px; line-height: 1.5; margin: 0 0 8px 0; text-align: center;">
              ⏳ This code is valid for <strong>5 minutes</strong>.
            </p>
            <p style="color: #9ca3af; font-size: 12px; line-height: 1.5; margin: 16px 0 0 0; border-top: 1px solid #f3f4f6; padding-top: 16px;">
              If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.
            </p>
          </div>

          <!-- Footer -->
          <div style="background-color: #f9fafb; padding: 20px 24px; text-align: center; border-top: 1px solid #e5e7eb;">
            <p style="color: #9ca3af; font-size: 12px; margin: 0;">
              © ${new Date().getFullYear()} Ritpen. All rights reserved.
            </p>
          </div>
        </div>
      </body>
      </html>
    `,
    headers: {
      'X-Priority': '1',
      'X-MSMail-Priority': 'High',
      'Importance': 'high',
      'X-Mailer': 'Ritpen Auth Mailer'
    }
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
