// Joi schema runner. Rejects unknown keys so mass-assignment attacks
// (`isAdmin: true` sneaking into a feed create) surface as 400 rather
// than silently landing on the document.

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
        return res.status(400).json({
          status: 'error',
          message: 'Request validation failed',
          errors: formatDetails(error),
        });
      }
      req[part] = value;
    }
    next();
  };
};
