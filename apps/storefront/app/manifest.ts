import type { MetadataRoute } from "next";

const DPL_LOGO_URL = "https://gtaiehdqxuqakrxetljb.supabase.co/storage/v1/object/public/team-logos/dpl%20logo%20(1).png";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "DPL Fantasy",
    short_name: "DPL Fantasy",
    description: "Private fantasy league for the Diamond Padel League Botswana community.",
    start_url: "/",
    display: "standalone",
    background_color: "#f5f3ee",
    theme_color: "#f5f3ee",
    icons: [
      { src: DPL_LOGO_URL, sizes: "192x192", type: "image/png" },
      { src: DPL_LOGO_URL, sizes: "512x512", type: "image/png" },
    ],
  };
}
