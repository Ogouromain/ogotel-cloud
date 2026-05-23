import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  reactStrictMode: false,
  async rewrites() {
    return [
      // ── Core Pages ──
      { source: '/landing.html', destination: '/landing' },
      { source: '/landing', destination: '/landing/index.html' },
      { source: '/login.html', destination: '/login' },
      { source: '/login', destination: '/login.html' },
      { source: '/register.html', destination: '/register' },
      { source: '/register', destination: '/register.html' },
      { source: '/dashboard.html', destination: '/dashboard' },
      { source: '/dashboard', destination: '/dashboard.html' },

      // ── Admin ──
      { source: '/admin/super-admin.html', destination: '/admin/super-admin' },
      { source: '/admin/super-admin', destination: '/admin/super-admin.html' },

      // ── Auth flow ──
      { source: '/email-confirmed.html', destination: '/email-confirmed' },
      { source: '/email-confirmed', destination: '/email-confirmed.html' },
      { source: '/reset-password.html', destination: '/reset-password' },
      { source: '/reset-password', destination: '/reset-password.html' },

      // ── Business ──
      { source: '/payment.html', destination: '/payment' },
      { source: '/payment', destination: '/payment.html' },
      { source: '/invoice.html', destination: '/invoice' },
      { source: '/invoice', destination: '/invoice.html' },
      { source: '/onboarding.html', destination: '/onboarding' },
      { source: '/onboarding', destination: '/onboarding.html' },

      // ── System ──
      { source: '/404.html', destination: '/404' },
      { source: '/404', destination: '/404.html' },
      { source: '/maintenance.html', destination: '/maintenance' },
      { source: '/maintenance', destination: '/maintenance.html' },
    ];
  },
};

export default nextConfig;
