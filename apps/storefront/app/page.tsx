import Link from "next/link";
import { redirect } from "next/navigation";
import { ArrowRight, Check, Shield, Sparkles, Trophy, Users } from "lucide-react";
import { serverSupabase } from "@dpl/supabase/server";
import { Logo } from "@dpl/ui";
import "./styles.css";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function Page() {
  const { data: { user } } = await (await serverSupabase()).auth.getUser();
  if (user) redirect("/dashboard");
  return <main className="marketing">
    <header className="marketing-nav"><Link href="/" className="logo"><Logo /></Link><nav><a href="#how-it-works">How it works</a><a href="#features">Fantasy rules</a></nav><Link href="/login" className="nav-login">Sign in <ArrowRight size={15} /></Link></header>
    <section className="hero"><div className="hero-copy"><p className="eyebrow">DPL Fantasy · Botswana</p><h1>Build your court.<br /><em>Own the night.</em></h1><p className="hero-lede">A private fantasy league for the Diamond Padel League. Choose your players, pick your captain, and compete against the DPL community every game night.</p><div className="hero-actions"><Link href="/login" className="primary">Create your team <ArrowRight size={16} /></Link><a href="#how-it-works" className="text-link">See how it works</a></div><div className="hero-proof"><span><Check size={14} /> Eight-player squads</span><span><Check size={14} /> Live night points</span></div></div><div className="hero-art"><div className="hero-court"><div className="court-net" /><div className="hero-player hp1">M1</div><div className="hero-player hp2">M2</div><div className="hero-player hp3">★</div><div className="hero-player hp4">C</div><div className="hero-player hp5">D</div><div className="hero-stamp">DPL<br /><strong>FANTASY</strong></div></div></div></section>
    <section id="how-it-works" className="how"><p className="eyebrow">The game plan</p><h2>Fantasy, built<br />for padel.</h2><div className="step-grid"><article><b>01 / BUILD</b><h3>Pick your eight</h3><p>Choose one M1, one M2, two Stars, two Cores and two Dev players within the P3,400 budget.</p></article><article><b>02 / CAPTAIN</b><h3>Back your player</h3><p>Select a captain before the night deadline. Diamond doubles their points every game night.</p></article><article><b>03 / COMPETE</b><h3>Climb the table</h3><p>Player scores come from real DPL fixtures. Track your night points and overall league ranking.</p></article></div></section>
    <section id="features" className="feature-band"><div><p className="eyebrow">Your private league</p><h2>Every point<br />has a story.</h2></div><div className="feature-list"><p><Users size={20} /><span><strong>Real DPL players</strong>Build with the current player pool, teams and results from the DPL scoring app.</span></p><p><Trophy size={20} /><span><strong>Night-by-night scoring</strong>Player points refresh after each deadline so every fixture matters.</span></p><p><Shield size={20} /><span><strong>Power-ups with purpose</strong>Use Diamond, No Negative, Wildcard and Diamond Boost strategically.</span></p><p><Sparkles size={20} /><span><strong>Made for your league</strong>A private fantasy experience for the Diamond Padel League Botswana community.</span></p></div></section>
    <section className="cta"><div><p className="eyebrow">Ready for the next game night?</p><h2>Make your move.</h2><p>Sign up and create your first fantasy team.</p></div><Link href="/login" className="primary">Enter DPL Fantasy <ArrowRight size={16} /></Link></section>
    <footer className="marketing-footer"><Logo /><span>Private fantasy league for Diamond Padel League Botswana · 2026</span><Link href="/login">Sign in <ArrowRight size={13} /></Link></footer>
  </main>;
}
