import { NextResponse } from "next/server";
import { serverSupabase } from "@dpl/supabase/server";
export async function GET(request: Request) { const url = new URL(request.url); const code = url.searchParams.get("code"); if (code) await (await serverSupabase()).auth.exchangeCodeForSession(code); return NextResponse.redirect(new URL("/", request.url)); }
