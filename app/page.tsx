"use client";

import { useEffect, useMemo, useState, useCallback } from "react";
import {
  ArrowRight,
  Check,
  CheckCircle2,
  Clock,
  Crown,
  Gamepad2,
  ImageIcon,
  LogOut,
  MapPinned,
  Plus,
  ScanLine,
  Sparkles,
  Trophy,
  Users,
  XCircle,
} from "lucide-react";
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
    meta: "8 categories · 15 questions · Fast rounds",
    instructions: "Questions appear on the shared TV screen and your phone. Tap the right option before time runs out!",
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
    meta: "Africa & East Africa · 10 rounds · 12s per flag",
    instructions: "A flag will display on the screen. Tap the matching country name as fast as you can!",
    isSupported: true,
  },
  {
    id: "who",
    title: "Who Am I?",
    kicker: "The picture game",
    icon: ImageIcon,
    color: "lime",
    template: "who_am_i_kenya",
    description: "Guess your secret identity while the table gives clues.",
    meta: "Kenyan Icons · Coming Phase 4",
    instructions: "Everyone knows who you are except you. Ask the table questions to work out your identity.",
    isSupported: false,
  },
  {
    id: "image",
    title: "Guess the Image",
    kicker: "Reveal & race",
    icon: ScanLine,
    color: "blue",
    template: undefined,
    description: "Name what you see before the image becomes clear.",
    meta: "Culture & Places · Coming Phase 4",
    instructions: "An image is revealed pixel-by-pixel. Buzz in and guess first!",
    isSupported: false,
  },
];

type Screen = "home" | "create" | "join" | "lobby" | "game" | "results";

type GameOption = {
  id: string;
  text: string;
};

type CurrentQuestion = {
  round_id: string;
  position: number;
  total_rounds: number;
  prompt: string;
  game_mode: string;
  duration_seconds: number;
  opens_at?: string | null;
  closes_at?: string | null;
  media?: { type: string; url: string; alt: string } | null;
  options: GameOption[];
};

type MyAnswer = {
  has_answered: boolean;
  selected_option_id?: string | null;
  is_revealed: boolean;
  is_correct?: boolean | null;
  points_awarded?: number | null;
  correct_option_id?: string | null;
  explanation?: string | null;
};

type LeaderboardEntry = {
  name: string;
  score: number;
  is_me: boolean;
  is_host: boolean;
};

type PlayerGameState = {
  room_id: string;
  room_code: string;
  status: string;
  phase: string;
  is_host: boolean;
  host_name: string;
  selected_game: string;
  state_version: number;
  my_score: number;
  total_players: number;
  answered_count: number;
  current_question: CurrentQuestion | null;
  my_answer: MyAnswer;
  leaderboard: LeaderboardEntry[];
};

export default function Home() {
  const [screen, setScreen] = useState<Screen>("home");
  const [name, setName] = useState("");
  const [roomCode, setRoomCode] = useState("");
  const [selectedGame, setSelectedGame] = useState("trivia");
  const [isConnecting, setIsConnecting] = useState(false);
  const [connectionError, setConnectionError] = useState("");
  const [liveRoomId, setLiveRoomId] = useState("");
  const [playerState, setPlayerState] = useState<PlayerGameState | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [secondsRemaining, setSecondsRemaining] = useState<number | null>(null);

  const room = useMemo(() => playerState?.room_code || roomCode || "MAV1", [playerState?.room_code, roomCode]);
  const chosenGame = games.find((g) => g.id === selectedGame) ?? games[0];

  // Refresh Player State from Server
  const refreshGameState = useCallback(async (roomId?: string) => {
    const id = roomId || liveRoomId;
    if (!id || !supabase) return;

    try {
      await ensureGameIdentity();
      const { data, error } = await supabase.rpc("get_player_game_state", { p_room_id: id });

      if (error) {
        if (error.message.includes("Room not found") || error.message.includes("not a player")) {
          sessionStorage.removeItem("mavelas_player_room_id");
          setLiveRoomId("");
          setScreen("home");
        }
        return;
      }

      if (data) {
        const state = data as PlayerGameState;
        setPlayerState(state);
        if (state.room_code) setRoomCode(state.room_code);

        // If this user was the host on the player controller route, redirect to the explicit Host Controller!
        if (state.is_host) {
          window.location.href = `/host/${state.room_code}`;
          return;
        }

        if (state.status === "lobby") {
          const matched = games.find((g) => g.id === state.selected_game || g.template === state.selected_game);
          if (matched) setSelectedGame(matched.id);
          setScreen("lobby");
        } else if (state.status === "playing") {
          setScreen("game");
        } else if (state.status === "results") {
          setScreen("results");
        }
      }
    } catch {
      // Ignore network errors gracefully
    }
  }, [liveRoomId]);

  // Read URL param ?code=ABCD and session persistence
  useEffect(() => {
    if (typeof window === "undefined") return;

    const params = new URLSearchParams(window.location.search);
    const codeParam = params.get("code");
    if (codeParam) {
      setRoomCode(codeParam.toUpperCase().slice(0, 6));
      setScreen("join");
    }

    const savedRoomId = sessionStorage.getItem("mavelas_player_room_id");
    const savedName = sessionStorage.getItem("mavelas_player_name");
    if (savedName) setName(savedName);
    if (savedRoomId && !codeParam) {
      setLiveRoomId(savedRoomId);
      void refreshGameState(savedRoomId);
    }
  }, [refreshGameState]);

  // Realtime subscription for player controller
  useEffect(() => {
    if (!liveRoomId || !supabase) return;
    const client = supabase;

    void refreshGameState();

    const channel = client
      .channel("player-controller-" + liveRoomId)
      .on("postgres_changes", { event: "*", schema: "public", table: "rooms", filter: "id=eq." + liveRoomId }, () => {
        void refreshGameState();
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "game_rounds", filter: "room_id=eq." + liveRoomId }, () => {
        void refreshGameState();
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "room_players", filter: "room_id=eq." + liveRoomId }, () => {
        void refreshGameState();
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "player_answers", filter: "room_id=eq." + liveRoomId }, () => {
        void refreshGameState();
      })
      .subscribe();

    return () => {
      void client.removeChannel(channel);
    };
  }, [liveRoomId, refreshGameState]);

  // Synchronized countdown timer
  useEffect(() => {
    const round = playerState?.current_question;
    if (!round?.closes_at || playerState?.phase !== "playing") {
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
  }, [playerState?.current_question?.closes_at, playerState?.phase, playerState?.current_question?.position]);

  // CREATE ROOM: Immediately routes the creator device to /host/[code]
  async function createLiveRoom() {
    setConnectionError("");
    setIsConnecting(true);
    try {
      const user = await ensureGameIdentity();
      if (!supabase) throw new Error("Live game service not configured.");
      const code = Array.from({ length: 4 }, () => "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[Math.floor(Math.random() * 32)]).join("");

      const { data: created, error: roomError } = await supabase
        .from("rooms")
        .insert({ code, host_id: user.id, selected_game: selectedGame, status: "lobby", phase: "lobby" })
        .select("id, code")
        .single();
      if (roomError || !created) throw roomError ?? new Error("Could not create the room.");

      const { error: playerError } = await supabase
        .from("room_players")
        .insert({ room_id: created.id, user_id: user.id, nickname: name.trim(), role: "host" });
      if (playerError) throw playerError;

      // EXPLICIT SURFACE ROUTING: The host device routes directly to /host/[code]!
      window.location.href = `/host/${created.code}`;
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not create room.");
      setIsConnecting(false);
    }
  }

  // JOIN ROOM: Joins as player only and remains on player controller surface
  async function joinLiveRoom() {
    setConnectionError("");
    setIsConnecting(true);
    try {
      const user = await ensureGameIdentity();
      if (!supabase) throw new Error("Live game service not configured.");

      const { data: roomData, error: lookupError } = await supabase
        .from("rooms")
        .select("id, code, host_id, selected_game, status")
        .eq("code", roomCode.toUpperCase().trim())
        .single();
      if (lookupError || !roomData) throw new Error("Room not found. Check the code and try again.");
      if (roomData.status === "closed") throw new Error("This room is closed.");

      // Check if this user is actually the host returning
      if (roomData.host_id === user.id) {
        window.location.href = `/host/${roomData.code}`;
        return;
      }

      const { error: playerError } = await supabase
        .from("room_players")
        .upsert({ room_id: roomData.id, user_id: user.id, nickname: name.trim(), role: "player" }, { onConflict: "room_id,user_id" });
      if (playerError) throw playerError;

      sessionStorage.setItem("mavelas_player_room_id", roomData.id);
      sessionStorage.setItem("mavelas_player_name", name.trim());
      setLiveRoomId(roomData.id);
      setRoomCode(roomData.code);
      await refreshGameState(roomData.id);
      setScreen(roomData.status === "playing" ? "game" : "lobby");
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not join room.");
    } finally {
      setIsConnecting(false);
    }
  }

  async function handleSubmitAnswer(optionId: string) {
    if (!supabase || !playerState?.current_question?.round_id || isSubmitting) return;

    setConnectionError("");
    setIsSubmitting(true);
    try {
      const { error } = await supabase.rpc("submit_game_answer", {
        p_round_id: playerState.current_question.round_id,
        p_option_id: optionId,
      });
      if (error) throw error;
      await refreshGameState();
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not submit answer.");
    } finally {
      setIsSubmitting(false);
    }
  }

  function handleLeaveRoom() {
    sessionStorage.removeItem("mavelas_player_room_id");
    setLiveRoomId("");
    setPlayerState(null);
    setScreen("home");
  }

  // PLAYER CONTROLLER VIEWS

  if (screen === "game" && playerState) {
    const question = playerState.current_question;
    const myAnswer = playerState.my_answer;
    const isRevealed = playerState.phase === "revealed" || myAnswer.is_revealed;
    const hasAnswered = myAnswer.has_answered;

    return (
      <main className="min-h-screen bg-[#101314] text-white">
        <div className="mx-auto flex min-h-screen max-w-2xl flex-col px-5 pb-12 pt-6 sm:px-8">
          {/* Header */}
          <header className="flex items-center justify-between border-b border-white/10 pb-4">
            <div>
              <span className="text-xs font-black uppercase tracking-[.16em] text-[#d7ff3f]">
                {chosenGame.title} · Round {question?.position} of {question?.total_rounds || 10}
              </span>
              <p className="text-sm text-white/50">Score: <strong className="text-white font-mono">{playerState.my_score} pts</strong></p>
            </div>

            <div className="flex items-center gap-2">
              {secondsRemaining !== null && !isRevealed && (
                <div
                  className={`flex items-center gap-1.5 rounded-xl px-3 py-1 font-mono text-base font-black ${
                    secondsRemaining <= 5 ? "bg-rose-500/20 text-rose-400 animate-pulse" : "bg-white/10 text-[#d7ff3f]"
                  }`}
                >
                  <Clock size={16} />
                  <span>{secondsRemaining}s</span>
                </div>
              )}
              <span className="rounded-xl border border-white/15 bg-white/[.06] px-3 py-1 font-mono text-xs font-bold text-white/80">
                {playerState.room_code}
              </span>
            </div>
          </header>

          {/* Question & Options Area */}
          <section className="my-auto py-6">
            {question ? (
              <div className="rounded-[2.2rem] bg-[#f0eee8] p-6 text-[#101314] sm:p-8 shadow-2xl">
                {question.media?.type === "flag" && (
                  <div className="mx-auto mb-6 flex justify-center">
                    <img
                      src={question.media.url}
                      alt={question.media.alt}
                      className="h-32 w-auto max-w-xs rounded-2xl bg-white object-contain p-3 shadow-md border-2 border-black/10"
                    />
                  </div>
                )}

                <p className="text-xs font-black uppercase tracking-[.16em] text-black/45">
                  {isRevealed ? "Round Reveal" : "Choose your answer"}
                </p>
                <h1 className="mt-2 text-2xl font-black leading-tight tracking-[-0.04em] sm:text-3xl">
                  {question.prompt}
                </h1>

                {/* Options Grid */}
                <div className="mt-6 grid gap-3 sm:grid-cols-2">
                  {question.options.map((option) => {
                    const isSelected = myAnswer.selected_option_id === option.id;
                    const isCorrect = isRevealed && myAnswer.correct_option_id === option.id;
                    const isWrongSelected = isRevealed && isSelected && !myAnswer.is_correct;

                    let buttonStyle = "border-2 border-black/15 bg-white text-black hover:border-black";
                    if (isCorrect) {
                      buttonStyle = "border-2 border-emerald-600 bg-emerald-100 text-emerald-950 font-black shadow";
                    } else if (isWrongSelected) {
                      buttonStyle = "border-2 border-rose-500 bg-rose-100 text-rose-950 line-through opacity-80";
                    } else if (isSelected) {
                      buttonStyle = "border-2 border-[#101314] bg-[#101314] text-[#d7ff3f] shadow-md";
                    }

                    return (
                      <button
                        key={option.id}
                        disabled={hasAnswered || isRevealed || isSubmitting || (secondsRemaining !== null && secondsRemaining <= 0)}
                        onClick={() => handleSubmitAnswer(option.id)}
                        className={`flex items-center justify-between rounded-2xl px-5 py-4 text-left font-black transition disabled:cursor-not-allowed ${buttonStyle}`}
                      >
                        <span>{option.text}</span>
                        {isSelected && !isRevealed && <Check size={18} />}
                        {isCorrect && <CheckCircle2 size={18} className="text-emerald-700" />}
                        {isWrongSelected && <XCircle size={18} className="text-rose-600" />}
                      </button>
                    );
                  })}
                </div>

                {/* Answer Locked Message */}
                {hasAnswered && !isRevealed && (
                  <div className="mt-6 flex items-center justify-center gap-3 rounded-2xl bg-black/[.06] p-4 text-center">
                    <div className="h-2.5 w-2.5 rounded-full bg-emerald-500 animate-ping" />
                    <p className="text-sm font-bold text-black/70">
                      Answer locked in — waiting for {playerState.host_name || "the host"} to reveal…
                    </p>
                  </div>
                )}

                {/* Time Expired */}
                {!hasAnswered && !isRevealed && secondsRemaining === 0 && (
                  <div className="mt-6 rounded-2xl bg-rose-100 p-4 text-center text-sm font-bold text-rose-900">
                    Time is up for this question!
                  </div>
                )}

                {/* Post-Reveal Feedback */}
                {isRevealed && (
                  <div
                    className={`mt-6 rounded-2xl p-5 shadow-sm transition ${
                      myAnswer.is_correct
                        ? "bg-[#d7ff3f] text-[#101314]"
                        : hasAnswered
                        ? "bg-rose-100 text-rose-950"
                        : "bg-black/10 text-black"
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <p className="text-lg font-black">
                        {myAnswer.is_correct
                          ? `Correct! +${myAnswer.points_awarded || 100} pts`
                          : hasAnswered
                          ? "Not this one!"
                          : "Did not answer in time"}
                      </p>
                      <span className="font-mono text-sm font-bold">Total: {playerState.my_score} pts</span>
                    </div>
                    {myAnswer.explanation && (
                      <p className="mt-2 text-sm font-medium leading-relaxed opacity-90">{myAnswer.explanation}</p>
                    )}
                  </div>
                )}

                {connectionError && <p role="alert" className="mt-4 text-sm font-bold text-rose-700">{connectionError}</p>}
              </div>
            ) : (
              <div className="rounded-[2.2rem] bg-[#f0eee8] p-10 text-center text-black">
                <p className="text-lg font-bold">Waiting for round to load…</p>
              </div>
            )}

            <p className="mt-6 text-center text-xs text-white/50">
              {isRevealed
                ? `Waiting for ${playerState.host_name || "the host"} to load the next question…`
                : "Your phone is your controller. Answers are locked once tapped."}
            </p>
          </section>
        </div>
      </main>
    );
  }

  // PLAYER RESULTS SCREEN
  if (screen === "results" && playerState) {
    return (
      <main className="min-h-screen bg-[#101314] text-white">
        <div className="mx-auto flex min-h-screen max-w-xl flex-col px-5 pb-10 pt-6 sm:px-8">
          <Topbar compact onHome={handleLeaveRoom} />
          <section className="my-auto rounded-[2.2rem] bg-[#f0eee8] p-8 text-center text-[#101314] shadow-2xl">
            <Trophy className="mx-auto text-[#101314]" size={56} />
            <p className="mt-6 text-xs font-black uppercase tracking-[.16em] text-black/45">Room {room}</p>
            <h1 className="mt-2 text-5xl font-black tracking-[-0.07em]">Game Over!</h1>
            <p className="mt-3 text-sm text-black/60">Final Standings:</p>

            <div className="mt-7 space-y-2 text-left">
              {playerState.leaderboard.map((entry, index) => (
                <div
                  key={entry.name + index}
                  className={`flex items-center justify-between rounded-xl px-4 py-3 ${
                    index === 0
                      ? "bg-[#d7ff3f] font-black shadow"
                      : entry.is_me
                      ? "bg-black/15 font-bold"
                      : "bg-black/[.05]"
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <span className="flex h-6 w-6 items-center justify-center rounded-full bg-black text-xs font-bold text-[#d7ff3f]">
                      {index + 1}
                    </span>
                    <span>{entry.name}</span>
                    {entry.is_me && <span className="text-[10px] uppercase font-bold text-black/60">(You)</span>}
                  </div>
                  <span className="font-mono font-black">{entry.score} pts</span>
                </div>
              ))}
            </div>

            <button className="button-dark mt-8 w-full py-3 text-sm font-bold" onClick={handleLeaveRoom}>
              Exit Room
            </button>
          </section>
        </div>
      </main>
    );
  }

  // PLAYER LOBBY (WAITING FOR HOST)
  if (screen === "lobby" && playerState) {
    return (
      <main className="min-h-screen bg-[#101314] text-white">
        <div className="mx-auto flex min-h-screen max-w-xl flex-col px-5 pb-10 pt-6 sm:px-8">
          <Topbar compact onHome={handleLeaveRoom} />

          <section className="my-auto">
            <div className="rounded-[2.2rem] bg-[#f0eee8] p-7 text-[#101314] shadow-2xl">
              <span className="eyebrow-dark">Player Controller</span>
              <h1 className="mt-2 text-3xl font-black tracking-tight sm:text-4xl">
                You’re in {playerState.host_name}’s Room.
              </h1>
              <p className="mt-2 text-sm text-black/60">
                Waiting for <strong>{playerState.host_name}</strong> to start the game. Keep this screen open.
              </p>

              {/* Selected Deck View */}
              <div className="mt-6 rounded-2xl bg-[#101314] p-5 text-white shadow-md">
                <div className="flex items-center gap-3">
                  <span className="grid h-10 w-10 place-items-center rounded-xl bg-[#d7ff3f] text-[#101314]">
                    <Gamepad2 size={20} />
                  </span>
                  <div>
                    <p className="text-xs font-bold uppercase tracking-[.14em] text-white/40">Deck Selected</p>
                    <p className="text-xl font-black">{chosenGame.title}</p>
                  </div>
                </div>
                <p className="mt-3 text-xs leading-5 text-white/70">{chosenGame.description}</p>
                <div className="mt-4 border-t border-white/10 pt-3">
                  <p className="text-[11px] font-black uppercase tracking-wider text-[#d7ff3f]">How to play</p>
                  <p className="mt-1 text-xs text-white/60">{chosenGame.instructions}</p>
                </div>
              </div>

              {/* Connected Roster */}
              <div className="mt-6 rounded-2xl border-2 border-black/10 bg-white/70 p-5">
                <div className="flex items-center justify-between pb-3 border-b border-black/10">
                  <p className="text-xs font-black uppercase tracking-[.14em] text-black/50">
                    Players in Room ({playerState.leaderboard.length})
                  </p>
                  <span className="text-xs text-emerald-700 font-bold flex items-center gap-1">
                    <span className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" /> Connected
                  </span>
                </div>
                <div className="mt-3 flex flex-wrap gap-2">
                  {playerState.leaderboard.map((p) => (
                    <div
                      key={p.name}
                      className={`flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-bold ${
                        p.is_host ? "bg-[#101314] text-[#d7ff3f]" : "bg-black/10 text-black"
                      }`}
                    >
                      {p.is_host && <Crown size={13} fill="currentColor" />}
                      <span>{p.name}</span>
                      {p.is_me && <span className="text-[10px] opacity-60">(You)</span>}
                    </div>
                  ))}
                </div>
              </div>

              <div className="mt-6">
                <button
                  onClick={handleLeaveRoom}
                  className="flex items-center justify-center gap-2 w-full text-xs font-bold uppercase tracking-wider text-black/40 hover:text-rose-600 transition py-2"
                >
                  <LogOut size={14} /> Leave Room
                </button>
              </div>
            </div>
          </section>
        </div>
      </main>
    );
  }

  // CREATE / JOIN FORM
  if (screen === "create" || screen === "join") {
    const isCreate = screen === "create";
    return (
      <main className="min-h-screen bg-[#101314] text-white">
        <div className="mx-auto flex min-h-screen max-w-xl flex-col px-5 pb-10 pt-6 sm:px-8">
          <Topbar compact onHome={() => setScreen("home")} />
          <section className="my-auto rounded-[2.2rem] bg-[#f0eee8] p-6 text-[#101314] sm:p-9 shadow-2xl">
            <span className="eyebrow-dark">{isCreate ? "Host a session" : "Join the table"}</span>
            <h1 className="mt-3 text-4xl font-black tracking-[-0.06em]">
              {isCreate ? "Host the room." : "You are invited."}
            </h1>
            <p className="mt-3 text-[15px] leading-6 text-black/60">
              {isCreate
                ? "Create a room and get instant host controls on this phone."
                : "Enter your nickname to join the room controller."}
            </p>

            <label className="field-label mt-7" htmlFor="name">
              Your nickname
            </label>
            <input
              id="name"
              autoFocus
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Kave"
              className="field"
            />

            {!isCreate && (
              <>
                <label className="field-label mt-5" htmlFor="room">
                  Room code
                </label>
                <input
                  id="room"
                  value={roomCode}
                  onChange={(e) => setRoomCode(e.target.value.toUpperCase().slice(0, 6))}
                  placeholder="MAV1"
                  className="field font-mono uppercase tracking-[.2em]"
                />
              </>
            )}

            {connectionError && <p role="alert" className="mt-4 text-sm font-bold text-rose-700">{connectionError}</p>}

            <button
              className="button-dark mt-7 w-full flex items-center justify-center gap-2"
              disabled={!name.trim() || (!isCreate && roomCode.length < 4) || isConnecting}
              onClick={isCreate ? createLiveRoom : joinLiveRoom}
            >
              {isConnecting ? "Connecting..." : isCreate ? "Create Room & Host" : "Join Game Table"}{" "}
              <ArrowRight size={18} />
            </button>

            <button
              className="mt-4 w-full text-sm font-bold text-black/50 hover:text-black"
              onClick={() => setScreen("home")}
            >
              Back
            </button>
          </section>
        </div>
      </main>
    );
  }

  // HOME SCREEN
  return (
    <main className="min-h-screen overflow-hidden bg-[#101314] text-white">
      <div className="noise" />
      <div className="mx-auto max-w-6xl px-5 pb-12 pt-6 sm:px-8">
        <Topbar onCreate={() => setScreen("create")} onJoin={() => setScreen("join")} />

        <section className="grid min-h-[500px] items-center gap-10 py-16 lg:grid-cols-[1.15fr_.85fr] lg:py-20">
          <div className="relative z-10">
            <span className="eyebrow">A live party game for your people</span>
            <h1 className="mt-4 max-w-3xl text-[3.6rem] font-black leading-[.86] tracking-[-.085em] sm:text-[5.8rem] lg:text-[7rem]">
              LET THE<br />
              <span className="text-[#d7ff3f]">TABLE</span> TALK.
            </h1>
            <p className="mt-7 max-w-lg text-lg leading-7 text-white/60">
              Three-surface party platform: host on your phone, join with friends, cast the display to your TV.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <button className="button-lime" onClick={() => setScreen("create")}>
                Host a Game <Plus size={18} />
              </button>
              <button className="button-secondary" onClick={() => setScreen("join")}>
                Join with Code <ArrowRight size={17} />
              </button>
            </div>
            <div className="mt-10 flex items-center gap-5 text-sm text-white/45">
              <span className="flex items-center gap-2">
                <Users size={16} /> 2–12 players
              </span>
              <span className="flex items-center gap-2">
                <Gamepad2 size={16} /> Phones as controllers
              </span>
            </div>
          </div>

          <div className="relative mx-auto w-full max-w-md">
            <div className="absolute -inset-10 rounded-full bg-[#d7ff3f]/15 blur-3xl" />
            <div className="relative rotate-[-4deg] rounded-[2.2rem] bg-[#f0eee8] p-5 text-[#101314] shadow-[20px_24px_0_#d7ff3f] sm:p-7">
              <div className="flex items-center justify-between border-b border-black/10 pb-4">
                <span className="rounded-full bg-black px-3 py-1 text-xs font-black tracking-wide text-white">
                  FLAG FRENZY
                </span>
                <span className="font-mono text-sm font-bold text-rose-600">00:12</span>
              </div>
              <div className="my-5 flex items-center justify-center rounded-2xl bg-white p-4 shadow-sm">
                <img
                  src="https://flagcdn.com/ke.svg"
                  alt="Kenya flag"
                  className="h-28 w-auto object-contain shadow"
                />
              </div>
              <p className="text-xs font-bold uppercase tracking-[.15em] text-black/45">Question 1 of 10</p>
              <p className="mt-1 text-2xl font-black tracking-[-.05em]">Which country is this?</p>
              <div className="mt-5 grid grid-cols-2 gap-2">
                <button className="rounded-xl bg-[#101314] px-4 py-3 text-sm font-black text-[#d7ff3f]">
                  Kenya
                </button>
                <button className="rounded-xl border-2 border-black/15 px-4 py-3 text-sm font-bold">
                  Uganda
                </button>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-white/10 pt-8">
          <div className="mb-5 flex items-end justify-between gap-4">
            <div>
              <p className="eyebrow">Playable decks</p>
              <h2 className="mt-2 text-3xl font-black tracking-[-.06em]">Party Modes</h2>
            </div>
            <span className="text-sm text-[#d7ff3f] font-bold">Phase 3.1 Architecture</span>
          </div>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {games.map((game) => {
              const Icon = game.icon;
              return (
                <article
                  className={`game-card ${game.color} ${!game.isSupported ? "opacity-65" : ""}`}
                  key={game.id}
                >
                  <div className="flex items-center justify-between">
                    <Icon size={26} strokeWidth={2.6} />
                    {game.isSupported && (
                      <span className="rounded-full bg-black/20 px-2.5 py-0.5 text-[10px] font-black uppercase tracking-wider">
                        Playable
                      </span>
                    )}
                  </div>
                  <p className="mt-8 text-xs font-black uppercase tracking-[.14em] opacity-60">{game.kicker}</p>
                  <h3 className="mt-1 text-2xl font-black tracking-[-.055em]">{game.title}</h3>
                  <p className="mt-3 text-sm leading-5 opacity-75">{game.description}</p>
                  <p className="mt-5 text-xs font-bold opacity-60">{game.meta}</p>
                </article>
              );
            })}
          </div>
        </section>
      </div>
    </main>
  );
}

function Topbar({
  compact = false,
  onHome,
  onCreate,
  onJoin,
}: {
  compact?: boolean;
  onHome?: () => void;
  onCreate?: () => void;
  onJoin?: () => void;
}) {
  return (
    <header className="relative z-10 flex items-center justify-between">
      <button className="flex items-center gap-3 text-left" onClick={onHome} aria-label="Return home">
        <span className="grid h-10 w-10 place-items-center rounded-[.8rem] bg-[#d7ff3f] text-xl font-black text-[#101314]">
          M
        </span>
        <span className="font-black tracking-[-.055em]">Game Mavelas</span>
      </button>
      {!compact && (
        <nav className="flex items-center gap-2">
          <button className="nav-button" onClick={onJoin}>
            Join room
          </button>
          <button className="button-lime small" onClick={onCreate}>
            Host a game
          </button>
        </nav>
      )}
    </header>
  );
}
