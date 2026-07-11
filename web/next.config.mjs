/** @type {import('next').NextConfig} */
const nextConfig = {
  // Firebase Hosting 向け静的エクスポート（完全クライアントサイドなので静的化で動く）
  output: "export",
};

export default nextConfig;
