import type { ReactNode } from "react";

export const DPL_LOGO_URL = "https://gtaiehdqxuqakrxetljb.supabase.co/storage/v1/object/public/team-logos/dpl%20logo%20(1).png";

export function Logo() {
  return (
    <div className="logo">
      <img src={DPL_LOGO_URL} alt="Diamond Padel League Botswana" />
      <strong>DPL</strong>
    </div>
  );
}

export function SectionHeader({ eyebrow, title, description, action }: { eyebrow: string; title: string; description?: string; action?: ReactNode }) {
  return <div className="section-header"><div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1>{description && <p className="description">{description}</p>}</div>{action}</div>;
}
