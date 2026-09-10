import type { NextConfig } from "next";
import path from "node:path";
const nextConfig: NextConfig = { transpilePackages: ["@dpl/shared", "@dpl/supabase", "@dpl/ui"], outputFileTracingRoot: path.join(__dirname, "../..") };
export default nextConfig;
