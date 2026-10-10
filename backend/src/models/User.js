const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    user_id: {
      type: String,
      sparse: true,
      index: true
    },
    username: {
      type: String,
      trim: true,
      default: ''
    },
    name: {
      type: String,
      trim: true,
      default: ''
    },
    email: {
      type: String,
      lowercase: true,
      trim: true,
      sparse: true,
      default: ''
    },
    mobileNumber: {
      type: String,
      trim: true,
      sparse: true,
      default: ''
    },
    password: {
      type: String,
      required: [true, 'Please provide a password'],
      minlength: [4, 'Password must be at least 4 characters'],
      select: false // Do not return password by default
    },
    profileImage: {
      type: String,
      default: ''
    },
    constituency: {
      type: String,
      default: ''
    },
    fcmToken: {
      type: String,
      default: ''
    },
    resetOtp: {
      type: String,
      default: ''
    },
    resetOtpExpires: {
      type: Date
    }
  },
  {
    timestamps: true
  }
);

// Hash password before saving
userSchema.pre('save', async function (next) {
  if (!this.name && this.username) {
    this.name = this.username;
  }
  if (!this.username && this.name) {
    this.username = this.name;
  }
  if (!this.isModified('password')) {
    return next();
  }
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

// Compare candidate password
userSchema.methods.comparePassword = async function (candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('User', userSchema);