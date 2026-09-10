import { redirect } from "next/navigation";
import { serverSupabase } from "@dpl/supabase/server";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { data: { user } } = await (await serverSupabase()).auth.getUser();
  if (!user) redirect("/login");
  return children;
}
