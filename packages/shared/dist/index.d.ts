export type Tier = "M1" | "M2" | "STAR" | "CORE" | "DEV";
export type PowerUpId = "wildcard" | "diamond" | "safety_net" | "diamond_boost";
export type Player = {
    id: string;
    name: string;
    initials: string;
    tier: Tier;
    price: number;
    form: number;
    club: string;
    color: string;
};
export declare const SQUAD_BUDGET = 3400;
export declare const SQUAD_SIZE = 7;
export declare const STARTERS = 4;
export declare const TIER_LABELS: Record<Tier, string>;
export declare const POWER_UPS: ({
    id: "wildcard";
    label: string;
    description: string;
    availability: string;
} | {
    id: "diamond";
    label: string;
    description: string;
    availability: string;
} | {
    id: "safety_net";
    label: string;
    description: string;
    availability: string;
} | {
    id: "diamond_boost";
    label: string;
    description: string;
    availability: string;
})[];
export declare function pointsMultiplier(diamond: boolean, boost: boolean): 3 | 2 | 1;
