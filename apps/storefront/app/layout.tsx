import type { Metadata } from "next";
import "./styles.css";

const DPL_LOGO_URL = "https://gtaiehdqxuqakrxetljb.supabase.co/storage/v1/object/public/team-logos/fantasy-logo.png";

export const metadata: Metadata = {
  title: "DPL Fantasy | Botswana",
  description: "Private fantasy league for the Diamond Padel League Botswana community.",
  icons: {
    icon: DPL_LOGO_URL,
    shortcut: DPL_LOGO_URL,
    apple: DPL_LOGO_URL,
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body>{children}</body></html>;
}
