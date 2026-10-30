import type { NextConfig } from "next";

// GitHub Pages serves a static export from https://<user>.github.io/gps-gym/.
// Set GITHUB_PAGES=true (the Pages workflow does) to build that way; local dev is unaffected.
const isGitHubPages = process.env.GITHUB_PAGES === "true";

const nextConfig: NextConfig = {
  // Cache Components / Partial Prefetching need a server; static export rejects them.
  cacheComponents: !isGitHubPages,
  partialPrefetching: !isGitHubPages,
  ...(isGitHubPages && {
    output: "export",
    basePath: "/gps-gym",
    // Emit /app/index.html so Pages serves /gps-gym/app/ without a server.
    trailingSlash: true,
  }),
};

export default nextConfig;
