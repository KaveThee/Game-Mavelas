"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { Gamepad2, Trophy, Users, Clock, QrCode, CheckCircle2 } from "lucide-react";
import QRCode from "qrcode";
import { ensureGameIdentity, supabase } from "@/lib/supabase";

type PublicPlayer = {
  name: string;
  score: number;
  seat?: number | null;
  has_answered?: boolean;
};

type PublicRoom = {
  room_code: string;
  status: string;
  phase: string;
  game_mode: string;
  game_title?: string | null;
  state_version: number;
  round_ends_at?: string | null;
  last_transition_at: string;
  total_players: number;
  answered_count: number;
  players: PublicPlayer[];
};

type PublicRound = {
  round_id?: string;
  position: number;
  game_mode: string;
  duration_seconds: number;
  status: string;
  opens_at?: string | null;
  closes_at?: string | null;
  prompt: string;
  options: Array<{ label: string; text: string; is_correct?: boolean | null }>;
  media?: { type: string; url: string; alt: string } | null;
  correct_option?: string | null;
  explanation?: string | null;
  active_player_name?: string | null;
};

type PublicClueHeist = {
  clue_number: number;
  current_value: number;
  turn_phase: "spotlight" | "steal" | "revealed";
  clues: Array<{ position: number; text: string }>;
  answer?: string | null;
  image?: { url: string; alt: string } | null;
  explanation?: string | null;
  winner_name?: string | null;
  awarded_points: number;
};

const gameName: Record<string, string> = {
  who_am_i: "Who Am I?",
  flag_frenzy: "Flag Frenzy",
  trivia: "Trivia Vault",
  "trivia-kenya": "Trivia Vault · Home Turf",
  "trivia-scitech": "Trivia Vault · Brain Buzz",
  "trivia-mix": "Trivia Vault · Anything Goes",
  guess_image: "Clue Heist",
};

function getFlagDifficulty(position?: number): "Easy" | "Medium" | "Hard" | null {
  if (!position) return null;
  if (position <= 3) return "Easy";
  if (position <= 7) return "Medium";
  return "Hard";
}

export default function SharedDisplay({ params }: { params: Promise<{ code: string }> }) {
  const [code, setCode] = useState("");
  const [room, setRoom] = useState<PublicRoom | null>(null);
  const [round, setRound] = useState<PublicRound | null>(null);
  const [error, setError] = useState("");
  const [qrDataUrl, setQrDataUrl] = useState<string>("");
  const [secondsRemaining, setSecondsRemaining] = useState<number | null>(null);
  const [heist, setHeist] = useState<PublicClueHeist | null>(null);

  useEffect(() => {
    void params.then(({ code: roomCode }) => setCode(roomCode.toUpperCase()));
  }, [params]);

  useEffect(() => {
    if (!code || typeof window === "undefined") return;
    const joinUrl = `${window.location.origin}/?code=${code}`;
    QRCode.toDataURL(joinUrl, {
      width: 280,
      margin: 1,
      color: {
        dark: "#101314",
        light: "#ffffff",
      },
    })
      .then(setQrDataUrl)
      .catch(console.error);
  }, [code]);

  // Server-synchronized countdown timer using closes_at
  useEffect(() => {
    if (!round?.closes_at || round.status !== "open") {
      setSecondsRemaining(null);
      return;
    }

    const targetTime = new Date(round.closes_at).getTime();

    const updateTimer = () => {
      const now = Date.now();
      const diff = Math.max(0, Math.ceil((targetTime - now) / 1000));
      setSecondsRemaining(diff);
    };

    updateTimer();
    const interval = setInterval(updateTimer, 500);
    return () => clearInterval(interval);
  }, [round?.closes_at, round?.status, round?.position]);

  // Realtime room and round listeners
  useEffect(() => {
    if (!code || !supabase) return;
    const client = supabase;

    const load = async () => {
      try {
        await ensureGameIdentity();
        const [{ data: roomData, error: roomError }, { data: roundData, error: roundError }] = await Promise.all([
          client.rpc("get_public_room_state", { p_room_code: code }),
          client.rpc("get_public_round_state", { p_room_code: code }),
        ]);

        if (roomError || roundError) throw roomError || roundError;
        if (!roomData) throw new Error("This room is no longer available.");

        setRoom(roomData as PublicRoom);
        const nextRound = roundData as PublicRound | null;
        setRound(nextRound);
        if (nextRound?.game_mode === "guess_image") {
          const { data: clueData, error: clueError } = await client.rpc("get_public_clue_heist_state", { p_room_code: code });
          if (clueError) throw clueError;
          setHeist(clueData as PublicClueHeist);
        } else {
          setHeist(null);
        }
        setError("");
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : "Could not load this room.");
      }
    };

    void load();

    // Shared displays deliberately are not room members, so RLS can suppress
    // raw-table Realtime events. Poll only the sanitized public RPC payloads
    // to keep the projector synchronized without reopening table visibility.
    const pollInterval = window.setInterval(() => {
      void load();
    }, 1000);

    const channel = client
      .channel("display-" + code)
      .on("postgres_changes", { event: "*", schema: "public", table: "rooms" }, load)
      .on("postgres_changes", { event: "*", schema: "public", table: "room_players" }, load)
      .on("postgres_changes", { event: "*", schema: "public", table: "game_rounds" }, load)
      .on("postgres_changes", { event: "*", schema: "public", table: "player_answers" }, load)
      .subscribe();

    return () => {
      window.clearInterval(pollInterval);
      void client.removeChannel(channel);
    };
  }, [code]);

  const title = room?.game_title || gameName[room?.game_mode ?? ""] || "Game Mavelas";
  const isLobby = !room || room.phase === "lobby" || room.phase === "selected" || room.status === "lobby";
  const isResults = room?.phase === "results" || room?.status === "results";
  const isRevealed = room?.phase === "revealed" || round?.status === "revealed";
  const isWhoAmI = round?.game_mode === "who_am_i";
  const isClueHeist = round?.game_mode === "guess_image";
  const flagDifficulty =
    round?.game_mode === "flag_frenzy" ? getFlagDifficulty(round.position) : null;

  const totalPlayers = room?.players.length ?? 0;
  const answeredCount = room?.answered_count ?? 0;
  const progressPercent = totalPlayers > 0 ? Math.min(100, Math.round((answeredCount / totalPlayers) * 100)) : 0;

  return (
    <main className="min-h-screen bg-[#101314] px-6 py-6 text-white lg:px-14 lg:py-10">
      <div className="mx-auto flex min-h-[calc(100vh-3rem)] max-w-7xl flex-col">
        {/* Header */}
        <header className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <span className="grid h-14 w-14 place-items-center rounded-2xl bg-[#d7ff3f] text-2xl font-black text-[#101314]">
              M
            </span>
            <div>
              <p className="text-2xl font-black tracking-[-.05em]">Game Mavelas</p>
              <p className="text-sm font-bold uppercase tracking-[.14em] text-white/45">Party Display</p>
            </div>
          </div>

          <div className="flex items-center gap-4">
            {!isLobby && !isResults && !isClueHeist && (
              <div
                className={`flex items-center gap-2 rounded-2xl border px-5 py-3 font-mono text-2xl font-black transition-colors ${
                  secondsRemaining !== null && secondsRemaining <= 5
                    ? "border-rose-500/40 bg-rose-500/10 text-rose-400 animate-pulse"
                    : "border-white/10 bg-white/[.05] text-[#d7ff3f]"
                }`}
              >
                <Clock size={22} />
                <span>{secondsRemaining !== null ? `${secondsRemaining}s` : isRevealed ? "Revealed" : "Live"}</span>
              </div>
            )}
            <div className="rounded-2xl border border-white/10 bg-white/[.05] px-5 py-3 text-right">
              <p className="text-xs font-bold uppercase tracking-[.14em] text-white/45">Room code</p>
              <p className="font-mono text-2xl font-black tracking-[.16em] text-[#d7ff3f]">{code || "----"}</p>
            </div>
          </div>
        </header>

        {/* Results Screen */}
        {isResults ? (
          <section className="my-auto py-12 text-center">
            <Trophy className="mx-auto text-[#d7ff3f]" size={72} />
            <p className="mt-6 text-sm font-black uppercase tracking-[.16em] text-[#d7ff3f]">Final Standings</p>
            <h1 className="mt-2 text-6xl font-black tracking-[-0.06em] sm:text-7xl">Game Over!</h1>
            <p className="mt-4 text-xl text-white/60">The scores are locked. Here is tonight’s champion:</p>

            <div className="mx-auto mt-10 max-w-2xl rounded-[2.5rem] bg-[#f0eee8] p-8 text-[#101314] shadow-2xl">
              {room?.players.slice(0, 5).map((player, index) => (
                <div
                  key={player.name + index}
                  className={`flex items-center justify-between rounded-2xl px-6 py-4 transition ${
                    index === 0 ? "bg-[#d7ff3f] font-black text-xl mb-3 shadow-md" : "bg-black/[.05] mb-2 font-bold"
                  }`}
                >
                  <div className="flex items-center gap-4">
                    <span className="flex h-8 w-8 items-center justify-center rounded-full bg-black text-sm text-[#d7ff3f]">
                      {index + 1}
                    </span>
                    <span>{player.name}</span>
                    {index === 0 && <span className="text-xs uppercase tracking-wider bg-black/10 px-2 py-0.5 rounded-full">Winner</span>}
                  </div>
                  <span className="font-mono font-black">{player.score} pts</span>
                </div>
              ))}
            </div>
          </section>
        ) : (
          /* Active Game or Lobby Screen */
          <section className="my-auto grid items-center gap-10 py-8 lg:grid-cols-[1.2fr_.8fr]">
            <div>
              <div className="flex items-center gap-3">
                <span className="text-sm font-black uppercase tracking-[.16em] text-[#d7ff3f]">
                  {isLobby
                    ? "Party Lobby"
                    : isRevealed
                    ? `${title}${flagDifficulty ? ` · ${flagDifficulty}` : ""} · Round ${round?.position} Reveal`
                    : `${title}${flagDifficulty ? ` · ${flagDifficulty}` : ""} · Round ${round?.position}`}
                </span>
                {!isLobby && (
                  <span
                    className={`rounded-full px-3 py-0.5 text-xs font-black uppercase tracking-wider ${
                      isRevealed ? "bg-[#d7ff3f] text-[#101314]" : "bg-white/10 text-white/70"
                    }`}
                  >
                    {isRevealed ? "Revealed" : "Answering"}
                  </span>
                )}
              </div>

              <h1 className="mt-4 max-w-4xl whitespace-pre-line text-5xl font-black leading-[.92] tracking-[-.07em] sm:text-7xl lg:text-8xl">
                {isLobby ? "THE TABLE\nIS GATHERING." : isClueHeist ? heist?.turn_phase === "steal" ? "STEAL\nTHE POINTS!" : `${(round?.active_player_name || "The player").toUpperCase()}\nIN THE SPOTLIGHT` : isWhoAmI ? `${(round?.active_player_name || "The guesser").toUpperCase()}\nIS UP!` : round?.prompt || "PLAY\nTOGETHER."}
              </h1>

              {isClueHeist && heist && heist.turn_phase !== "revealed" && (
                <div className="mt-8 max-w-4xl space-y-4">
                  <div className="flex flex-wrap items-center gap-3">
                    <span className="rounded-full bg-[#d7ff3f] px-4 py-2 font-mono text-xl font-black text-[#101314]">{heist.current_value} PTS</span>
                    <span className="rounded-full border border-white/15 bg-white/[.06] px-4 py-2 text-sm font-black uppercase tracking-wider">Clue {heist.clue_number} / 20</span>
                    {heist.turn_phase === "steal" && <span className="animate-pulse rounded-full bg-rose-500 px-4 py-2 text-sm font-black uppercase tracking-wider">Steal value: {Math.ceil(heist.current_value / 2)}</span>}
                  </div>
                  <div className="grid gap-3 sm:grid-cols-2">
                    {heist.clues.slice(-4).map((clue) => (
                      <div key={clue.position} className="rounded-3xl border border-white/15 bg-white/[.07] p-5">
                        <p className="text-xs font-black uppercase tracking-[.16em] text-[#d7ff3f]">Clue {clue.position}</p>
                        <p className="mt-2 text-xl font-black leading-tight sm:text-2xl">{clue.text}</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {isClueHeist && heist?.turn_phase === "revealed" && (
                <div className="mt-8 grid max-w-4xl gap-6 sm:grid-cols-[.75fr_1.25fr] sm:items-center">
                  {heist.image && <Image src={heist.image.url} alt={heist.image.alt} width={512} height={512} className="aspect-square w-full rounded-[2rem] bg-white object-cover shadow-2xl" />}
                  <div>
                    <p className="text-sm font-black uppercase tracking-[.16em] text-[#d7ff3f]">Mystery revealed</p>
                    <p className="mt-2 text-5xl font-black tracking-[-.06em]">{heist.answer}</p>
                    <p className="mt-3 text-lg font-bold text-white/65">{heist.winner_name ? `${heist.winner_name} won ${heist.awarded_points} points.` : "Nobody solved this mystery."}</p>
                    {heist.explanation && <p className="mt-4 text-base leading-6 text-white/65">{heist.explanation}</p>}
                  </div>
                </div>
              )}

              {isWhoAmI && !isRevealed && (
                <div className="mt-8 max-w-3xl rounded-[2rem] border border-white/15 bg-white/[.06] p-6 sm:p-8">
                  <p className="text-sm font-black uppercase tracking-[.16em] text-[#d7ff3f]">Who Am I?</p>
                  <p className="mt-3 text-2xl font-black leading-tight sm:text-4xl">{round?.active_player_name || "The active player"}, ask the table yes-or-no questions.</p>
                  <p className="mt-3 text-base font-bold leading-6 text-white/60">Everyone else: keep the identity secret, answer fairly, and help with clues. The guesser submits their final answer on their phone.</p>
                </div>
              )}

              {/* Media for Flag Frenzy */}
              {round?.media?.type === "flag" && (
                <div className="mt-8 flex items-center justify-start">
                  <img
                    src={round.media.url}
                    alt={round.media.alt}
                    className="h-44 w-auto max-w-md rounded-3xl bg-white object-contain p-4 shadow-2xl border-4 border-white/10"
                  />
                </div>
              )}

              {/* The TV is the source of truth for answer wording. Controllers
                  receive only matching A/B/C/D pads, keeping attention at the table. */}
              {!isLobby && !isWhoAmI && !isClueHeist && round && round.options.length > 0 && (
                <div className="mt-8 grid max-w-4xl grid-cols-2 gap-3 sm:gap-4">
                  {round.options.map((option) => {
                    const isCorrect = isRevealed && option.is_correct;
                    return (
                      <div
                        key={option.label}
                        className={`flex min-h-24 items-center gap-4 rounded-3xl border-2 px-5 py-4 sm:min-h-28 sm:px-7 ${
                          isCorrect
                            ? "border-[#d7ff3f] bg-[#d7ff3f] text-[#101314]"
                            : "border-white/15 bg-white/[.07] text-white"
                        }`}
                      >
                        <span className={`grid h-10 w-10 shrink-0 place-items-center rounded-xl font-mono text-xl font-black ${
                          isCorrect ? "bg-[#101314] text-[#d7ff3f]" : "bg-white/10 text-[#d7ff3f]"
                        }`}>
                          {option.label}
                        </span>
                        <span className="text-lg font-black leading-tight sm:text-2xl">{option.text}</span>
                      </div>
                    );
                  })}
                </div>
              )}

              {/* Reveal feedback on big screen */}
              {isRevealed && round?.correct_option && (
                <div className="mt-8 rounded-3xl border-2 border-[#d7ff3f] bg-[#d7ff3f]/15 p-6 max-w-2xl">
                  <p className="text-xs font-black uppercase tracking-[.16em] text-[#d7ff3f]">Correct Answer</p>
                  <p className="mt-2 text-3xl font-black text-white">{round.correct_option}</p>
                  {round.explanation && (
                    <p className="mt-2 text-base leading-6 text-white/75">{round.explanation}</p>
                  )}
                </div>
              )}

              {/* Answering Progress Bar on big screen */}
              {!isLobby && !isRevealed && (
                <div className="mt-8 max-w-xl rounded-2xl border border-white/10 bg-white/[.04] p-5">
                  <div className="flex items-center justify-between text-sm font-bold">
                    <span className="flex items-center gap-2 text-white/70">
                      <Users size={16} /> Players Answered
                    </span>
                    <span className="font-mono text-[#d7ff3f] text-base">
                      {answeredCount} / {totalPlayers}
                    </span>
                  </div>
                  <div className="mt-3 h-3 w-full overflow-hidden rounded-full bg-white/10">
                    <div
                      className="h-full bg-[#d7ff3f] transition-all duration-300 rounded-full"
                      style={{ width: `${progressPercent}%` }}
                    />
                  </div>
                </div>
              )}

              {/* Lobby QR Code Card */}
              {isLobby && (
                <div className="mt-8 flex max-w-3xl flex-wrap items-center gap-7 rounded-[2rem] border border-[#d7ff3f]/30 bg-white/[.06] p-6 shadow-2xl sm:p-8">
                  {qrDataUrl ? (
                    <img
                      src={qrDataUrl}
                      alt="Scan to join room"
                      className="h-48 w-48 rounded-3xl bg-white p-3 shadow-md shrink-0 sm:h-56 sm:w-56"
                    />
                  ) : (
                    <div className="grid h-48 w-48 place-items-center rounded-3xl bg-white/[.08] text-white/40 shrink-0 sm:h-56 sm:w-56">
                      <QrCode size={64} />
                    </div>
                  )}
                  <div className="min-w-[220px]">
                    <p className="text-xs font-black uppercase tracking-[.16em] text-[#d7ff3f]">Scan or enter this code</p>
                    <p className="mt-2 font-mono text-5xl font-black tracking-[.12em] text-white sm:text-6xl">{code}</p>
                    <p className="mt-5 text-xl font-black">First phone becomes host</p>
                    <p className="mt-1.5 max-w-sm text-sm leading-6 text-white/60">
                      Scan to claim the game controls. Everyone after that joins as a player at{" "}
                      <span className="font-mono text-white/80">
                        {typeof window !== "undefined" ? window.location.host : "gamemavelas"}
                      </span>
                    </p>
                  </div>
                </div>
              )}
            </div>

            {/* Sidebar Leaderboard */}
            <aside className="rounded-[2.5rem] bg-[#f0eee8] p-7 text-[#101314] shadow-2xl">
              <div className="flex items-center justify-between border-b border-black/10 pb-5">
                <div className="flex items-center gap-3">
                  <div className="grid h-12 w-12 place-items-center rounded-2xl bg-[#101314] text-[#d7ff3f]">
                    <Trophy size={23} />
                  </div>
                  <div>
                    <p className="text-xs font-black uppercase tracking-[.14em] text-black/45">
                      {isLobby ? "Table Roster" : "Leaderboard"}
                    </p>
                    <p className="text-2xl font-black">{totalPlayers} Players</p>
                  </div>
                </div>
                <span className="rounded-full bg-black/10 px-3 py-1 font-mono text-xs font-bold">
                  {isLobby ? "Lobby" : isRevealed ? "Round Reveal" : "In Play"}
                </span>
              </div>

              <div className="mt-6 space-y-2 max-h-[440px] overflow-y-auto pr-1">
                {room?.players.length ? (
                  room.players.map((player, index) => (
                    <div
                      className={`flex items-center justify-between rounded-2xl px-4 py-3.5 transition ${
                        index === 0 && !isLobby ? "bg-[#d7ff3f]/40 border-2 border-[#101314]" : "bg-black/[.05]"
                      }`}
                      key={player.name + index}
                    >
                      <div className="flex items-center gap-3">
                        <span className="flex h-7 w-7 items-center justify-center rounded-full bg-black text-xs font-bold text-[#d7ff3f]">
                          {index + 1}
                        </span>
                        <span className="font-bold text-[17px]">{player.name}</span>
                        {!isLobby && !isRevealed && player.has_answered && (
                          <span className="flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-[11px] font-black text-emerald-800">
                            <CheckCircle2 size={12} /> In
                          </span>
                        )}
                      </div>
                      <span className="font-mono font-black text-lg">{player.score} pts</span>
                    </div>
                  ))
                ) : (
                  <div className="py-12 text-center text-black/40">
                    <p className="font-bold">Waiting for players to join…</p>
                    <p className="text-xs mt-1">First phone to scan claims host controls</p>
                  </div>
                )}
              </div>
            </aside>
          </section>
        )}

        {/* Footer */}
        <footer className="flex items-center justify-between border-t border-white/10 pt-6 text-sm font-bold text-white/45">
          <span className="flex items-center gap-2">
            <Gamepad2 size={18} /> Keep your phone open
          </span>
          <span className="flex items-center gap-2">
            <Trophy size={18} /> {room?.state_version ? `Live sync v${room.state_version}` : "Connected"}
          </span>
        </footer>
        {error && <p role="alert" className="mt-4 text-center text-sm font-bold text-rose-300">{error}</p>}
      </div>
    </main>
  );
}
