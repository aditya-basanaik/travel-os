const { createProxyMiddleware } = require("http-proxy-middleware");

module.exports = function (app) {
  app.use(
    "/api",
    createProxyMiddleware({
      target: process.env.REACT_APP_BACKEND_URL || "http://localhost:8001",
      changeOrigin: true,
      secure: false,
      headers: {
        "Accept": "application/json",
      },
      cookieDomainRewrite: "localhost",
      onProxyRes(proxyRes) {
        // Rewrite Set-Cookie headers so they work on localhost
        const sc = proxyRes.headers["set-cookie"];
        if (sc) {
          proxyRes.headers["set-cookie"] = sc.map((cookie) =>
            cookie
              .replace(/;\s*Secure/gi, "")
              .replace(/;\s*SameSite=None/gi, "; SameSite=Lax")
              .replace(/;\s*Domain=[^;]*/gi, "")
          );
        }
      },
    })
  );
};
