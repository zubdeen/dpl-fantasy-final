export type Tier = "M1" | "M2" | "STAR" | "CORE" | "DEV";
export type PowerUpId = "diamond" | "no_negative" | "wildcard" | "diamond_boost";
export type PlayerScore = {
  season?: string | null;
  night?: number | null;
  gamePoints: number;
  wins: number;
  losses: number;
  overallPoints: number;
  updatedAt: string | null;
};
export type Player = {
  id: string;
  name: string;
  initials: string;
  tier: Tier;
  price: number;
  form: number;
  club: string;
  color: string;
  score?: PlayerScore;
};
export const SQUAD_BUDGET = 3400;
export const SQUAD_SIZE = 8;
export const STARTERS = 8;
export const TIER_COUNTS: Record<Tier, number> = { M1: 1, M2: 1, STAR: 2, CORE: 2, DEV: 2 };
export const TIER_LABELS: Record<Tier, string> = { M1: "M1", M2: "M2", STAR: "Star", CORE: "Core", DEV: "Dev" };
export const POWER_UPS = [
  { id: "diamond" as const, label: "Diamond", group: "Match Power-Ups", description: "Choose any captain and double their points.", availability: "Every night" },
  { id: "no_negative" as const, label: "No Negative", group: "Seasonal Power-Ups", description: "Negative points become zero; positive points stay unchanged.", availability: "Once per season" },
  { id: "wildcard" as const, label: "Wildcard", group: "Seasonal Power-Ups", description: "Unlimited budget for a complete team change.", availability: "Once per season" },
  { id: "diamond_boost" as const, label: "Diamond Boost", group: "Seasonal Power-Ups", description: "Triple any captain's points. Overrides Diamond.", availability: "Once per season" },
];
export function pointsMultiplier(diamond: boolean, boost: boolean) { return boost ? 3 : diamond ? 2 : 1; }
export function tierCountsAreValid(players: Player[]) {
  return (Object.keys(TIER_COUNTS) as Tier[]).every((tier) => players.filter((player) => player.tier === tier).length === TIER_COUNTS[tier]);
}
