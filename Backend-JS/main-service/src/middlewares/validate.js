// Joi schema runner. Rejects unknown keys (`stripUnknown: false` +
// `allowUnknown: false`) so mass-assignment attacks surface as a 400
// rather than quietly landing in the database.
//
// Usage: `router.post("/x", validate({ body: schemas.x }), handler)`.
// Pass `{ body, query, params }` to validate multiple parts; each key
// is optional.

const { HTTP_STATUS } = require('../utils/constants');

const formatDetails = (error) =>
  error.details.map((d) => ({ path: d.path.join('.'), message: d.message }));

module.exports = function validate(spec) {
  return (req, res, next) => {
    for (const part of ['body', 'query', 'params']) {
      const schema = spec[part];
      if (!schema) continue;
      const { error, value } = schema.validate(req[part], {
        abortEarly: false,
        allowUnknown: false,
        stripUnknown: false,
        convert: true,
      });
      if (error) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          message: 'Request validation failed',
          errors: formatDetails(error),
        });
      }
      // req.query in Express 4 is writable; replace with coerced output.
      req[part] = value;
    }
    next();
  };
};
