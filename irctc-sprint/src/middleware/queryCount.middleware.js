// Query count middleware - increment `req._queryCount` in DB wrapper when queries run
module.exports = function queryCountMiddleware(req, res, next) {
  req._queryCount = 0;
  res.on('finish', () => {
    if (req._queryCount > 5) {
      console.warn(`[QUERY COUNT] ${req.method} ${req.path} → ${req._queryCount} queries`);
    }
  });
  next();
};
