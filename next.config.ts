import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  reactStrictMode: false,
  async rewrites() {
    return [
      {
        source: '/landing.html',
        destination: '/landing',
      },
      {
        source: '/login.html',
        destination: '/login',
      },
      {
        source: '/register.html',
        destination: '/register',
      },
      {
        source: '/dashboard.html',
        destination: '/dashboard',
      },
      {
        source: '/admin/super-admin.html',
        destination: '/admin/super-admin',
      },
    ];
  },
};

export default nextConfig;
