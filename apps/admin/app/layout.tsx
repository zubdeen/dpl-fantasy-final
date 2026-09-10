import type { Metadata } from "next";
import "./styles.css";

const DPL_LOGO_URL = "https://gtaiehdqxuqakrxetljb.supabase.co/storage/v1/object/public/team-logos/dpl%20logo%20(1).png";

export const metadata: Metadata = {
  title: "DPL Admin | Botswana",
  description: "DPL Fantasy administration",
  icons: { icon: DPL_LOGO_URL },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
