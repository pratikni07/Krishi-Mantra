const Joi = require('joi');

const objectId = Joi.string().pattern(/^[0-9a-fA-F]{24}$/);

const location = Joi.object({
  latitude: Joi.alternatives(Joi.number(), Joi.string()).optional(),
  longitude: Joi.alternatives(Joi.number(), Joi.string()).optional(),
}).optional();

const mediaUrl = Joi.string().uri({ scheme: ['http', 'https'] }).max(2048);

exports.createFeed = Joi.object({
  // Identity fields remain accepted for backward compat but the gateway
  // overwrites userId from the verified JWT before it reaches the service.
  userId: objectId.required(),
  userName: Joi.string().trim().min(1).max(100).required(),
  profilePhoto: Joi.string().uri({ scheme: ['http', 'https'] }).max(2048).optional().allow('', null),
  description: Joi.string().max(5000).optional().allow('', null),
  content: Joi.string().max(10000).optional().allow('', null),
  mediaUrl: mediaUrl.optional().allow('', null),
  mediaUrls: Joi.array().items(mediaUrl).max(10).optional(),
  location,
});

exports.addCommentParams = Joi.object({
  feedId: objectId.required(),
});

exports.addCommentBody = Joi.object({
  userId: objectId.required(),
  userName: Joi.string().trim().min(1).max(100).required(),
  profilePhoto: Joi.string().uri({ scheme: ['http', 'https'] }).max(2048).optional().allow('', null),
  content: Joi.string().trim().min(1).max(5000).required(),
  parentCommentId: objectId.optional().allow(null),
});

exports.toggleLikeParams = Joi.object({
  feedId: objectId.required(),
});

exports.toggleLikeBody = Joi.object({
  userId: objectId.required(),
});
