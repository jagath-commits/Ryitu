const AppConfig = require('../models/AppConfig');
const env = require('../config/env');
const { successResponse, errorResponse } = require('../utils/response.util');

const CONFIG_KEY = 'app_version_config';

/**
 * Get current app version and forced update status
 */
exports.getVersion = async (req, res, next) => {
  try {
    let config = await AppConfig.findOne({ key: CONFIG_KEY });

    if (!config) {
      // Initialize with environment defaults
      config = await AppConfig.create({
        key: CONFIG_KEY,
        minBuildNumber: env.APP_MIN_BUILD_NUMBER,
        latestBuildNumber: env.APP_LATEST_BUILD_NUMBER,
        minVersion: env.APP_MIN_VERSION,
        latestVersion: env.APP_LATEST_VERSION,
        forceUpdate: env.APP_FORCE_UPDATE,
        updateUrl: env.APP_UPDATE_URL,
        title: env.APP_UPDATE_TITLE,
        message: env.APP_UPDATE_MESSAGE
      });
    }

    return successResponse(res, 200, 'App version fetched successfully', {
      minBuildNumber: config.minBuildNumber,
      latestBuildNumber: config.latestBuildNumber,
      minVersion: config.minVersion,
      latestVersion: config.latestVersion,
      forceUpdate: config.forceUpdate,
      updateUrl: config.updateUrl,
      title: config.title,
      message: config.message
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update app version requirements (e.g. For releasing updates)
 */
exports.updateVersion = async (req, res, next) => {
  try {
    const {
      minBuildNumber,
      latestBuildNumber,
      minVersion,
      latestVersion,
      forceUpdate,
      updateUrl,
      title,
      message
    } = req.body;

    let config = await AppConfig.findOne({ key: CONFIG_KEY });

    if (!config) {
      config = new AppConfig({ key: CONFIG_KEY });
    }

    if (minBuildNumber !== undefined) config.minBuildNumber = parseInt(minBuildNumber, 10);
    if (latestBuildNumber !== undefined) config.latestBuildNumber = parseInt(latestBuildNumber, 10);
    if (minVersion !== undefined) config.minVersion = minVersion;
    if (latestVersion !== undefined) config.latestVersion = latestVersion;
    if (forceUpdate !== undefined) config.forceUpdate = Boolean(forceUpdate);
    if (updateUrl !== undefined) config.updateUrl = updateUrl;
    if (title !== undefined) config.title = title;
    if (message !== undefined) config.message = message;

    await config.save();

    return successResponse(res, 200, 'App version requirements updated successfully', {
      minBuildNumber: config.minBuildNumber,
      latestBuildNumber: config.latestBuildNumber,
      minVersion: config.minVersion,
      latestVersion: config.latestVersion,
      forceUpdate: config.forceUpdate,
      updateUrl: config.updateUrl,
      title: config.title,
      message: config.message
    });
  } catch (error) {
    next(error);
  }
};
