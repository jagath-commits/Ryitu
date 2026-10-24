const mongoose = require('mongoose');

const appConfigSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      required: true,
      unique: true,
      default: 'app_version_config'
    },
    minBuildNumber: {
      type: Number,
      default: 7
    },
    latestBuildNumber: {
      type: Number,
      default: 7
    },
    minVersion: {
      type: String,
      default: '1.0.5'
    },
    latestVersion: {
      type: String,
      default: '1.0.5'
    },
    forceUpdate: {
      type: Boolean,
      default: true
    },
    updateUrl: {
      type: String,
      default: 'https://play.google.com/store/apps/details?id=com.ritpen'
    },
    title: {
      type: String,
      default: 'Update Required'
    },
    message: {
      type: String,
      default: 'A new version of Ritpen is available with important improvements and bug fixes. Please update the app to continue.'
    }
  },
  {
    timestamps: true
  }
);

module.exports = mongoose.model('AppConfig', appConfigSchema);
