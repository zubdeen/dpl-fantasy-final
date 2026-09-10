import path from "node:path";

/** @type {import("next").NextConfig} */
const nextConfig = {
  transpilePackages: ["@dpl/shared", "@dpl/ui", "@dpl/supabase"],
  outputFileTracingRoot: path.join(process.cwd(), "../.."),
};

export default nextConfig;
