export const SQUAD_BUDGET = 3400;
export const SQUAD_SIZE = 7;
export const STARTERS = 4;
export const TIER_LABELS = { M1: "Match 1", M2: "Match 2", STAR: "Star", CORE: "Core", DEV: "Development" };
export const POWER_UPS = [
    { id: "wildcard", label: "Wildcard", description: "Rebuild your entire squad from scratch.", availability: "1 available" },
    { id: "diamond", label: "Diamond", description: "Captain earns 2× points for this gameweek.", availability: "Unlimited" },
    { id: "safety_net", label: "Safety net", description: "No points reduced from players who lose games.", availability: "1 available" },
    { id: "diamond_boost", label: "Diamond boost", description: "Captain earns a 3× points multiplier once.", availability: "1 available" },
];
export function pointsMultiplier(diamond, boost) { return boost ? 3 : diamond ? 2 : 1; }
