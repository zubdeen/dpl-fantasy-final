# League Match Entry and Individual Scoring

This reference shows the current code used by the admin page to enter league-phase match results and calculate individual player points.

## 1. League match result entry

Source: `src/app/admin/page.tsx`

The form state and validation are defined as follows:

```tsx
type MatchForm = {
  team1: string;
  team2: string;
  team1_player1_id: string;
  team1_player2_id: string;
  team2_player1_id: string;
  team2_player2_id: string;
  team1_games: string;
  team2_games: string;
  tie_breaker: boolean;
  played_at: string;
};

const emptyForm = (): MatchForm => ({
  team1: "",
  team2: "",
  team1_player1_id: "",
  team1_player2_id: "",
  team2_player1_id: "",
  team2_player2_id: "",
  team1_games: "",
  team2_games: "",
  tie_breaker: false,
  played_at: new Date().toISOString().slice(0, 10),
});

function validateForm(f: MatchForm): string | null {
  if (!f.team1 || !f.team2) return "Pick both teams.";
  if (f.team1 === f.team2) return "Teams must be different.";
  const ids = [f.team1_player1_id, f.team1_player2_id, f.team2_player1_id, f.team2_player2_id];
  if (ids.some((id) => !id)) return "Select two players for each team.";
  if (new Set(ids).size !== 4) return "A player can't be picked twice.";
  const g1 = parseInt(f.team1_games, 10);
  const g2 = parseInt(f.team2_games, 10);
  if (!Number.isFinite(g1) || !Number.isFinite(g2) || g1 < 0 || g2 < 0)
    return "Enter valid game scores.";
  if (g1 === g2) return "Game scores can't be tied.";
  if (!f.played_at) return "Pick a date.";
  return null;
}
```

The `MatchEntryPanel` submits the result to the `matches` table:

```tsx
function MatchEntryPanel() {
  const qc = useQueryClient();
  const players = usePlayers();
  const [form, setForm] = useState<MatchForm>(emptyForm);
  const team1Lineup = useQuery<LockedSeason5Lineup | null>({
    queryKey: ["season5_locked_lineup", form.team1, form.played_at],
    enabled: Boolean(form.team1 && form.played_at),
    queryFn: () => fetchLockedSeason5Lineup(form.team1, form.played_at),
  });
  const team2Lineup = useQuery<LockedSeason5Lineup | null>({
    queryKey: ["season5_locked_lineup", form.team2, form.played_at],
    enabled: Boolean(form.team2 && form.played_at),
    queryFn: () => fetchLockedSeason5Lineup(form.team2, form.played_at),
  });

  const submit = async () => {
    if (!team1Lineup.data || !team2Lineup.data)
      return toast.error("Lock a Season 5 lineup for both teams before recording games.");
    const err = validateForm(form);
    if (err) return toast.error(err);
    const payload = {
      team1_name: form.team1,
      team2_name: form.team2,
      team1_player1_id: form.team1_player1_id,
      team1_player2_id: form.team1_player2_id,
      team2_player1_id: form.team2_player1_id,
      team2_player2_id: form.team2_player2_id,
      team1_games: parseInt(form.team1_games, 10),
      team2_games: parseInt(form.team2_games, 10),
      tie_breaker: form.tie_breaker,
      played_at: new Date(form.played_at).toISOString(),
    };
    let { error } = await supabase.from("matches").insert(payload as never);
    const savedWithoutTeamNames = isMissingMatchTeamNameColumn(error);

    if (savedWithoutTeamNames) {
      const legacy = await supabase.from("matches").insert(withoutMatchTeamNames(payload) as never);
      error = legacy.error;
    }

    if (error) return toast.error(error.message);
    toast.success(
      savedWithoutTeamNames
        ? "Match recorded. Apply the substitution migration to save playing team names."
        : "Match recorded",
    );
    setForm(emptyForm());
    qc.invalidateQueries({ queryKey: ["matches"] });
  };

  return (
    <SectionCard title="Record Match" icon={<Swords className="h-4 w-4 text-primary" />}>
      <MatchFormFields
        form={form}
        setForm={setForm}
        players={players.data ?? []}
        team1Lineup={team1Lineup.data}
        team2Lineup={team2Lineup.data}
        lineupLoading={team1Lineup.isLoading || team2Lineup.isLoading}
      />
      <Button
        className="w-full mt-4"
        onClick={submit}
        disabled={!team1Lineup.data || !team2Lineup.data}
      >
        Save match
      </Button>
    </SectionCard>
  );
}
```

`MatchFormFields` provides the team selectors, active-player selectors, game-score inputs, tiebreak checkbox, and played-date input. It limits player choices to active players from the locked Season 5 lineup.

## 2. Individual scoring calculation

Source: `src/lib/scoring.ts` and `src/lib/eliminators.ts`

`computePlayerStandings()` processes every league match and applies the adjusted difference to each player on the relevant pair:

```ts
for (const m of matches) {
  const rawDiff = m.team1_games - m.team2_games;
  const t1 = [m.team1_player1_id, m.team1_player2_id];
  const t2 = [m.team2_player1_id, m.team2_player2_id];
  const allPlayerIds = [...t1, ...t2];
  const tierByPlayerId = new Map(
    allPlayerIds.map((pid) => [pid, byId.get(pid)?.category ?? "Dev"]),
  );
  const { team1Diff, team2Diff } = adjustedPlayerDiffs(m, tierByPlayerId);

  for (const pid of t1) {
    const s = ensure(pid);
    s.matches += 1;
    s.points += team1Diff;
    s.gamesFor += m.team1_games;
    s.gamesAgainst += m.team2_games;
    if (rawDiff > 0) s.wins += 1;
    else if (rawDiff < 0) s.losses += 1;
  }
  for (const pid of t2) {
    const s = ensure(pid);
    s.matches += 1;
    s.points += team2Diff;
    s.gamesFor += m.team2_games;
    s.gamesAgainst += m.team1_games;
    if (-rawDiff > 0) s.wins += 1;
    else if (-rawDiff < 0) s.losses += 1;
  }
}

for (const s of acc.values()) {
  s.points = s.matches > 0 ? s.points / s.matches : 0;
}
```

The adjustment helper calculates the points for each pair:

```ts
export function adjustedPlayerDiffs(
  match: IndividualPointMatch,
  tierByPlayerId: ReadonlyMap<string, string | null | undefined>,
) {
  const team1Ids = [match.team1_player1_id, match.team1_player2_id];
  const team2Ids = [match.team2_player1_id, match.team2_player2_id];
  const team1Handicap = pairHandicap(tierByPlayerId, team1Ids);
  const team2Handicap = pairHandicap(tierByPlayerId, team2Ids);
  const rawTeam1Diff = match.team1_games - match.team2_games;
  const handicapAdjustment = team2Handicap - team1Handicap;

  return {
    team1Diff: rawTeam1Diff + handicapAdjustment,
    team2Diff: -rawTeam1Diff - handicapAdjustment,
    team1Handicap,
    team2Handicap,
    fixtureDifficulty: Math.abs(team1Handicap - team2Handicap),
  };
}
```

In formula form:

```text
Raw team 1 difference = team 1 games - team 2 games
Handicap adjustment   = team 2 pair handicap - team 1 pair handicap
Team 1 player points  = raw difference + handicap adjustment
Team 2 player points  = -team 1 player points

Final individual points = total adjusted points / matches played
```

The official category handicap values are:

```ts
M1: 4;
M2: 3;
Star: 2;
Core: 1;
Dev: 0;
```

The league calculation uses each player's official roster category, not the nightly playing tier.
