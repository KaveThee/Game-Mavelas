"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import {
  ArrowRight,
  Check,
  CheckCircle2,
  Clock,
  Copy,
  Crown,
  ExternalLink,
  Eye,
  Gamepad2,
  MapPinned,
  Monitor,
  Play,
  QrCode,
  RotateCcw,
  SkipForward,
  Sparkles,
  Trophy,
  Users,
  AlertTriangle,
} from "lucide-react";
import QRCode from "qrcode";
import { ensureGameIdentity, supabase } from "@/lib/supabase";

const games = [
  {
    id: "trivia",
    title: "Trivia Rush",
    kicker: "Multi-phase quiz",
    icon: Sparkles,
    color: "pink",
    template: "trivia_rush_classic",
    description: "Rapid-fire quiz on Kenyan and African history, science, geography, and culture.",
    meta: "8 categories · 15 questions",
    isSupported: true,
  },
  {
    id: "flags",
    title: "Flag Frenzy",
    kicker: "Fastest finger wins",
    icon: MapPinned,
    color: "yellow",
    template: "flag_frenzy_africa",
    description: "Spot the country from its flag before the countdown runs down.",
    meta: "Africa & East Africa · 10 rounds",
    isSupported: true,
  },
];

type HostPlayer = {
  name: string;
  score: number;
  role: string;
  has_answered: boolean;
};

type HostRound = {
  round_id: string;
  position: number;
  total_rounds: number;
  prompt: string;
  game_mode: string;
  duration_seconds: number;
  opens_at?: string | null;
  closes_at?: string | null;
  status: string;
  explanation?: string | null;
  correct_option?: string | null;
  media?: { type: string; url: string; alt: string } | null;
  options: { id: string; text: string }[];
};

type HostGameState = {
  is_host: boolean;
  room_id: string;
  room_code: string;
  status: string;
  phase: string;
  selected_game: string;
  game_title?: string | null;
  state_version: number;
  total_players: number;
  answered_count: number;
  current_round: HostRound | null;
  players: HostPlayer[];
  error?: string;
};

export default function HostController({ params }: { params: Promise<{ code: string }> }) {
  const [code, setCode] = useState("");
  const [hostState, setHostState] = useState<HostGameState | null>(null);
  const [selectedDeck, setSelectedDeck] = useState("trivia");
  const [isLoading, setIsLoading] = useState(true);
  const [isActionLoading, setIsActionLoading] = useState(false);
  const [actionError, setActionError] = useState("");
  const [copied, setCopied] = useState(false);
  const [qrDataUrl, setQrDataUrl] = useState("");
  const [secondsRemaining, setSecondsRemaining] = useState<number | null>(null);

  useEffect(() => {
    void params.then(({ code: roomCode }) => setCode(roomCode.toUpperCase()));
  }, [params]);

  // Load Host State
  const loadHostState = useCallback(async () => {
    if (!code || !supabase) return;
    try {
      await ensureGameIdentity();
      const { data, error } = await supabase.rpc("get_host_game_state", { p_room_code: code });

      if (error) {
        setActionError(error.message);
        return;
      }

      if (data) {
        const state = data as HostGameState;
        setHostState(state);
        if (state.selected_game) {
          const match = games.find((g) => g.id === state.selected_game || g.template === state.selected_game);
          if (match) setSelectedDeck(match.id);
        }
      }
    } catch (err) {
      setActionError(err instanceof Error ? err.message : "Error connecting to room");
    } finally {
      setIsLoading(false);
    }
  }, [code]);

  useEffect(() => {
    void loadHostState();
  }, [loadHostState]);

  // Realtime subscription
  useEffect(() => {
    if (!hostState?.room_id || !supabase) return;
    const client = supabase;

    const channel = client
      .channel("host-room-" + hostState.room_id)
      .on("postgres_changes", { event: "*", schema: "public", table: "rooms", filter: "id=eq." + hostState.room_id }, () => {
        void loadHostState();
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "room_players", filter: "room_id=eq." + hostState.room_id }, () => {
        void loadHostState();
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "game_rounds", filter: "room_id=eq." + hostState.room_id }, () => {
        void loadHostState();
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "player_answers", filter: "room_id=eq." + hostState.room_id }, () => {
        void loadHostState();
      })
      .subscribe();

    return () => {
      void client.removeChannel(channel);
    };
  }, [hostState?.room_id, loadHostState]);

  // Generate QR for joiners
  useEffect(() => {
    if (!code || typeof window === "undefined") return;
    const joinUrl = `${window.location.origin}/?code=${code}`;
    QRCode.toDataURL(joinUrl, {
      width: 220,
      margin: 1,
      color: { dark: "#101314", light: "#ffffff" },
    })
      .then(setQrDataUrl)
      .catch(console.error);
  }, [code]);

  // Timer calculation
  useEffect(() => {
    const round = hostState?.current_round;
    if (!round?.closes_at || hostState?.phase !== "playing") {
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
  }, [hostState?.current_round?.closes_at, hostState?.phase, hostState?.current_round?.position]);

  // Host Action Handlers
  async function handleSelectDeck(deckId: string) {
    setSelectedDeck(deckId);
    if (hostState?.room_id && supabase) {
      await supabase.from("rooms").update({ selected_game: deckId }).eq("id", hostState.room_id);
    }
  }

  async function handleStartGame() {
    const deck = games.find((g) => g.id === selectedDeck);
    if (!deck?.template || !supabase) return;

    setActionError("");
    setIsActionLoading(true);
    try {
      const { error } = await supabase.rpc("host_start_game", {
        p_room_code: code,
        p_template_code: deck.template,
      });
      if (error) throw error;
      await loadHostState();
    } catch (err) {
      setActionError(err instanceof Error ? err.message : "Could not start game.");
    } finally {
      setIsActionLoading(false);
    }
  }

  async function handleReveal() {
    if (!supabase) return;
    setActionError("");
    setIsActionLoading(true);
    try {
      const { error } = await supabase.rpc("host_reveal_round", { p_room_code: code });
      if (error) throw error;
      await loadHostState();
    } catch (err) {
      setActionError(err instanceof Error ? err.message : "Could not reveal round.");
    } finally {
      setIsActionLoading(false);
    }
  }

  async function handleAdvance() {
    if (!supabase) return;
    setActionError("");
    setIsActionLoading(true);
    try {
      const { error } = await supabase.rpc("host_advance_round", { p_room_code: code });
      if (error) throw error;
      await loadHostState();
    } catch (err) {
      setActionError(err instanceof Error ? err.message : "Could not advance round.");
    } finally {
      setIsActionLoading(false);
    }
  }

  async function handleEndGame() {
    if (!supabase) return;
    setActionError("");
    setIsActionLoading(true);
    try {
      const { error } = await supabase.rpc("host_end_game", { p_room_code: code });
      if (error) throw error;
      await loadHostState();
    } catch (err) {
      setActionError(err instanceof Error ? err.message : "Could not end game.");
    } finally {
      setIsActionLoading(false);
    }
  }

  function handleCopyInvite() {
    if (typeof window === "undefined") return;
    const url = `${window.location.origin}/?code=${code}`;
    navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2500);
  }

  const chosenDeck = useMemo(() => games.find((g) => g.id === selectedDeck) ?? games[0], [selectedDeck]);
  const displayUrl = `/display/${code}`;

  // Unauthorized / Checking State
  if (isLoading) {
    return (
      <main className="min-h-screen bg-[#101314] text-white grid place-items-center p-6">
        <div className="text-center">
          <div className="mx-auto h-10 w-10 animate-spin rounded-full border-4 border-[#d7ff3f] border-t-transparent mb-4" />
          <p className="font-bold text-lg">Connecting to Host Console…</p>
        </div>
      </main>
    );
  }

  if (!hostState?.is_host) {
    return (
      <main className="min-h-screen bg-[#101314] text-white grid place-items-center p-6">
        <div className="max-w-md rounded-[2.5rem] bg-[#f0eee8] p-8 text-[#101314] text-center shadow-2xl">
          <AlertTriangle className="mx-auto text-amber-600 mb-4" size={48} />
          <h1 className="text-3xl font-black tracking-tight">Host Verification Failed</h1>
          <p className="mt-3 text-sm text-black/60 leading-relaxed">
            This device is not authenticated as the host of room <strong className="font-mono text-black">{code}</strong>.
          </p>
          <div className="mt-7 space-y-3">
            <a
              href={`/?code=${code}`}
              className="button-dark block w-full text-center text-sm font-bold"
            >
              Join as a Player
            </a>
            <a href="/" className="block text-xs font-bold text-black/50 hover:text-black pt-2">
              Return to Home
            </a>
          </div>
        </div>
      </main>
    );
  }

  const isLobby = hostState.status === "lobby" || hostState.phase === "lobby";
  const isPlaying = hostState.status === "playing" && hostState.phase === "playing";
  const isRevealed = hostState.phase === "revealed" || hostState.current_round?.status === "revealed";
  const isResults = hostState.status === "results" || hostState.phase === "results";

  return (
    <main className="min-h-screen bg-[#101314] text-white">
      <div className="mx-auto flex min-h-screen max-w-4xl flex-col px-5 pb-12 pt-6 sm:px-8">
        {/* Top bar */}
        <header className="flex items-center justify-between border-b border-white/10 pb-4">
          <div className="flex items-center gap-3">
            <span className="grid h-10 w-10 place-items-center rounded-xl bg-[#d7ff3f] text-lg font-black text-[#101314]">
              M
            </span>
            <div>
              <p className="font-black tracking-[-0.04em] flex items-center gap-1.5">
                Game Mavelas <span className="text-xs uppercase bg-[#d7ff3f] text-[#101314] font-black px-2 py-0.5 rounded-full">Host</span>
              </p>
              <p className="text-xs text-white/50">Room Code: <strong className="font-mono text-[#d7ff3f]">{code}</strong></p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <a
              href={displayUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="button-secondary text-xs flex items-center gap-1.5 py-2 px-3"
            >
              <Monitor size={14} /> Open Display <ExternalLink size={12} />
            </a>
          </div>
        </header>

        {/* LOBBY PHASE */}
        {isLobby && (
          <section className="mt-8 grid gap-8 md:grid-cols-[1.1fr_.9fr] items-start">
            <div>
              <span className="eyebrow">Host Console</span>
              <h1 className="mt-2 text-4xl font-black tracking-[-0.06em] sm:text-5xl">
                Ready to Launch.
              </h1>
              <p className="mt-3 text-sm text-white/60 leading-relaxed">
                Connect your TV at <code className="text-white">/display/{code}</code>. Players join on their phones.
              </p>

              {/* Room Code & Invite Card */}
              <div className="mt-6 rounded-[2rem] border border-white/10 bg-white/[.04] p-5 sm:p-6 shadow-xl">
                <div className="flex items-end justify-between gap-4">
                  <div>
                    <p className="text-xs font-bold uppercase tracking-[.14em] text-white/45">Room Code</p>
                    <p className="mt-1 font-mono text-5xl font-black tracking-[.14em] text-[#d7ff3f]">{code}</p>
                  </div>
                  <button className="button-secondary text-xs flex items-center gap-1.5" onClick={handleCopyInvite}>
                    {copied ? <Check size={14} className="text-[#d7ff3f]" /> : <Copy size={14} />}
                    {copied ? "Copied!" : "Copy Link"}
                  </button>
                </div>
              </div>

              {/* Connected Players Roster */}
              <div className="mt-6 rounded-2xl border border-white/10 bg-white/[.03] p-5">
                <div className="flex items-center justify-between pb-3 border-b border-white/10">
                  <p className="text-xs font-black uppercase tracking-[.14em] text-white/60">
                    Connected Players ({hostState.players.length})
                  </p>
                  <span className="text-xs text-[#d7ff3f] font-bold">
                    {hostState.players.length < 2 ? "Waiting for joiners" : "Ready to start"}
                  </span>
                </div>
                <div className="mt-4 flex flex-wrap gap-2">
                  {hostState.players.map((player) => (
                    <div
                      key={player.name}
                      className={`flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-bold ${
                        player.role === "host" ? "bg-[#d7ff3f] text-[#101314]" : "bg-white/10 text-white"
                      }`}
                    >
                      {player.role === "host" && <Crown size={13} fill="currentColor" />}
                      <span>{player.name}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* QR Code Quick View */}
              {qrDataUrl && (
                <div className="mt-6 flex items-center gap-4 rounded-2xl border border-white/10 bg-white/[.03] p-4">
                  <img src={qrDataUrl} alt="Join QR" className="h-20 w-20 rounded-xl bg-white p-1" />
                  <div>
                    <p className="text-xs font-bold uppercase tracking-wider text-[#d7ff3f]">Scan to join</p>
                    <p className="text-xs text-white/70 mt-1">
                      Players can scan this code or visit <span className="font-mono text-white">/?code={code}</span>
                    </p>
                  </div>
                </div>
              )}
            </div>

            {/* Deck Selector & Start Button */}
            <aside className="rounded-[2.2rem] bg-[#f0eee8] p-6 text-[#101314] shadow-2xl">
              <p className="eyebrow-dark">Select Game Mode</p>
              <div className="mt-4 space-y-2">
                {games.map((deck) => {
                  const Icon = deck.icon;
                  return (
                    <button
                      key={deck.id}
                      onClick={() => handleSelectDeck(deck.id)}
                      className={`game-select ${selectedDeck === deck.id ? "selected" : ""}`}
                    >
                      <Icon size={20} strokeWidth={2.5} />
                      <span>{deck.title}</span>
                      {selectedDeck === deck.id && <span className="pick-dot" />}
                    </button>
                  );
                })}
              </div>

              <div className="mt-6 rounded-2xl bg-[#101314] p-5 text-white shadow-xl">
                <p className="text-xs font-bold uppercase tracking-[.14em] text-white/40">Chosen Deck</p>
                <p className="mt-1 text-2xl font-black">{chosenDeck.title}</p>
                <p className="mt-2 text-xs leading-5 text-white/60">{chosenDeck.description}</p>
                <p className="mt-3 text-xs font-bold text-[#d7ff3f]">{chosenDeck.meta}</p>

                {actionError && <p role="alert" className="mt-4 text-xs font-bold text-rose-300">{actionError}</p>}

                {/* PROMINENT START GAME BUTTON */}
                <button
                  className="button-lime mt-6 w-full flex items-center justify-center gap-2 py-4 text-base font-black shadow-lg"
                  disabled={isActionLoading}
                  onClick={handleStartGame}
                >
                  <Play size={18} fill="currentColor" />
                  {isActionLoading ? "Starting Game…" : "Start Game Now"}
                </button>
              </div>
            </aside>
          </section>
        )}

        {/* IN-GAME CONTROLS (PLAYING OR REVEALED) */}
        {(isPlaying || isRevealed) && hostState.current_round && (
          <section className="my-auto py-8">
            <div className="rounded-[2.2rem] bg-[#f0eee8] p-6 text-[#101314] sm:p-9 shadow-2xl">
              <div className="flex items-center justify-between border-b border-black/10 pb-4">
                <div>
                  <span className="text-xs font-black uppercase tracking-[.16em] text-black/50">
                    Round {hostState.current_round.position} of {hostState.current_round.total_rounds}
                  </span>
                  <p className="text-xl font-black">{chosenDeck.title}</p>
                </div>

                <div className="flex items-center gap-3">
                  {secondsRemaining !== null && !isRevealed && (
                    <div
                      className={`flex items-center gap-1 rounded-xl px-3 py-1 font-mono text-base font-black ${
                        secondsRemaining <= 5 ? "bg-rose-600 text-white animate-pulse" : "bg-black text-[#d7ff3f]"
                      }`}
                    >
                      <Clock size={16} />
                      <span>{secondsRemaining}s</span>
                    </div>
                  )}
                  <span
                    className={`rounded-xl px-3 py-1 text-xs font-black uppercase tracking-wider ${
                      isRevealed ? "bg-[#d7ff3f] text-[#101314]" : "bg-black/10 text-black/70"
                    }`}
                  >
                    {isRevealed ? "Answer Revealed" : "Answering Active"}
                  </span>
                </div>
              </div>

              {/* Media for flags */}
              {hostState.current_round.media?.type === "flag" && (
                <div className="my-6 flex justify-center">
                  <img
                    src={hostState.current_round.media.url}
                    alt={hostState.current_round.media.alt}
                    className="h-32 w-auto object-contain rounded-2xl bg-white p-3 border-2 border-black/10 shadow"
                  />
                </div>
              )}

              {/* Prompt */}
              <h2 className="mt-5 text-2xl font-black tracking-tight sm:text-3xl">
                {hostState.current_round.prompt}
              </h2>

              {/* Live Answer Progress */}
              <div className="mt-6 rounded-2xl bg-black/[.05] p-4 flex items-center justify-between">
                <span className="text-xs font-bold text-black/70 flex items-center gap-2">
                  <Users size={16} /> Player Responses
                </span>
                <span className="font-mono text-base font-black text-[#101314]">
                  {hostState.answered_count} / {hostState.total_players} answered
                </span>
              </div>

              {/* Revealed Answer Display */}
              {isRevealed && hostState.current_round.correct_option && (
                <div className="mt-6 rounded-2xl border-2 border-[#101314] bg-[#d7ff3f] p-5 text-[#101314]">
                  <p className="text-xs font-black uppercase tracking-wider opacity-70">Correct Answer</p>
                  <p className="text-2xl font-black mt-1">{hostState.current_round.correct_option}</p>
                  {hostState.current_round.explanation && (
                    <p className="mt-2 text-xs font-semibold leading-5 opacity-85">
                      {hostState.current_round.explanation}
                    </p>
                  )}
                </div>
              )}

              {actionError && <p role="alert" className="mt-4 text-xs font-bold text-rose-700">{actionError}</p>}
            </div>

            {/* Host Master Actions Bar */}
            <div className="mt-6 rounded-2xl border border-white/10 bg-white/[.04] p-5">
              <p className="text-xs font-black uppercase tracking-[.14em] text-[#d7ff3f] mb-3">Host Actions</p>
              <div className="flex flex-wrap gap-3">
                {!isRevealed ? (
                  <>
                    <button
                      className="button-lime flex-1 flex items-center justify-center gap-2 py-3 text-sm font-black"
                      disabled={isActionLoading}
                      onClick={handleReveal}
                    >
                      <Eye size={18} /> Reveal Answer
                    </button>
                    <button
                      className="button-secondary flex items-center gap-2 py-3 text-sm font-bold"
                      disabled={isActionLoading}
                      onClick={handleAdvance}
                    >
                      <SkipForward size={16} /> Skip Round
                    </button>
                  </>
                ) : (
                  <button
                    className="button-lime flex-1 flex items-center justify-center gap-2 py-3 text-sm font-black"
                    disabled={isActionLoading}
                    onClick={handleAdvance}
                  >
                    <ArrowRight size={18} /> Next Question
                  </button>
                )}
                <button
                  className="rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-xs font-bold text-rose-300 hover:bg-rose-500/20"
                  disabled={isActionLoading}
                  onClick={handleEndGame}
                >
                  End Game
                </button>
              </div>
            </div>
          </section>
        )}

        {/* RESULTS PHASE */}
        {isResults && (
          <section className="my-auto py-8 text-center max-w-xl mx-auto">
            <div className="rounded-[2.5rem] bg-[#f0eee8] p-8 text-[#101314] shadow-2xl">
              <Trophy className="mx-auto text-[#101314]" size={56} />
              <p className="mt-4 text-xs font-black uppercase tracking-[.14em] text-black/50">Room {code}</p>
              <h1 className="mt-1 text-4xl font-black tracking-tight">Game Finished!</h1>
              <p className="mt-2 text-xs text-black/60">Leaderboard standings:</p>

              <div className="mt-6 space-y-2 text-left">
                {hostState.players.map((player, index) => (
                  <div
                    key={player.name + index}
                    className={`flex items-center justify-between rounded-xl px-4 py-3 ${
                      index === 0 ? "bg-[#d7ff3f] font-black" : "bg-black/[.05] font-bold"
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <span className="flex h-6 w-6 items-center justify-center rounded-full bg-black text-xs text-[#d7ff3f]">
                        {index + 1}
                      </span>
                      <span>{player.name}</span>
                    </div>
                    <span className="font-mono font-black">{player.score} pts</span>
                  </div>
                ))}
              </div>

              <button
                className="button-dark mt-7 w-full flex items-center justify-center gap-2 py-3 text-sm font-black"
                disabled={isActionLoading}
                onClick={handleStartGame}
              >
                <RotateCcw size={16} /> Play Again
              </button>
            </div>
          </section>
        )}
      </div>
    </main>
  );
}
