"use client";

import { useEffect, useMemo, useState, useCallback } from "react";
import Image from "next/image";
import Link from "next/link";
import {
  ArrowRight,
  Check,
  Clock,
  Copy,
  Crown,
  ExternalLink,
  Gamepad2,
  ImageIcon,
  LogOut,
  MapPinned,
  Monitor,
  Play,
  Plus,
  RotateCcw,
  ScanLine,
  Sparkles,
  Trophy,
  Users,
} from "lucide-react";
import { ensureGameIdentity, supabase } from "@/lib/supabase";

const triviaBranches = [
  {
    id: "trivia-kenya",
    title: "Home Turf",
    kicker: "Kenya & East Africa",
    icon: Sparkles,
    color: "pink",
    template: "trivia_vault_kenya",
    description: "A three-round Kenya and East Africa challenge, from warm-up facts to proper local knowledge.",
    meta: "15 questions · 100 → 200 points · Kenya focus",
    instructions: "Choose an answer on your phone before the timer ends. Each round gets tougher and earns more points.",
    isSupported: true,
  },
  {
    id: "trivia-scitech",
    title: "Brain Buzz",
    kicker: "Science & Technology",
    icon: Sparkles,
    color: "pink",
    template: "trivia_vault_scitech",
    description: "Test the table on science and technology through three escalating rounds.",
    meta: "15 questions · 100 → 200 points · Science + tech",
    instructions: "Start with a warm-up, then progress into technology and the final hard round.",
    isSupported: true,
  },
  {
    id: "trivia-mix",
    title: "Anything Goes",
    kicker: "Mixed knowledge",
    icon: Sparkles,
    color: "pink",
    template: "trivia_vault_mix",
    description: "A broad general-knowledge run for mixed groups, with a clear Easy, Medium and Hard finish.",
    meta: "15 questions · 100 → 200 points · Mixed topics",
    instructions: "Every correct tap scores. The final round is worth the most, so no lead is safe.",
    isSupported: true,
  },
];

const games = [
  {
    id: "trivia",
    title: "Trivia Vault",
    kicker: "Pick your branch",
    icon: Sparkles,
    color: "pink",
    description: "Choose a themed quiz branch: Home Turf, Brain Buzz, or Anything Goes.",
    meta: "3 branches · 15 questions · 100 → 200 points",
    template: "",
    instructions: "Pick a Trivia Vault branch before starting.",
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
    meta: "15, 30, 45 or 60 flags · 30 seconds each",
    instructions: "A flag will display on the screen. Tap the matching country name as fast as you can to score points!",
    isSupported: true,
  },
  {
    id: "who",
    title: "Who Am I?",
    kicker: "Talk, clue, guess",
    icon: ImageIcon,
    color: "lime",
    template: "who_am_i_kenya",
    description: "One player at a time discovers a famous face through yes-or-no questions from the table.",
    meta: "Kenyan, African & global icons · Conversation rounds",
    instructions: "The active player asks yes-or-no questions. Everyone else can see the secret identity and gives helpful clues. The active player then types a final guess.",
    isSupported: true,
  },
  {
    id: "image",
    title: "Clue Heist",
    kicker: "Guess early or steal",
    icon: ScanLine,
    color: "blue",
    template: "clue_heist_classic",
    description: "Solve a hidden image from up to 20 clues. Every extra clue lowers its value, and missed answers open the heist.",
    meta: "20 clues · 100→5 points · Live steals",
    instructions: "The spotlight player guesses first. A wrong answer opens the steal to everyone else for half the available points.",
    isSupported: true,
  },
];

const playableGames = [...triviaBranches, ...games.filter((game) => game.id !== "trivia")];

const flagRoundOptions = [15, 30, 45, 60] as const;
type FlagRoundCount = (typeof flagRoundOptions)[number];

const modeNames: Record<string, string> = {
  trivia: "Trivia Vault",
  flag_frenzy: "Flag Frenzy",
  who_am_i: "Who Am I?",
  guess_image: "Clue Heist",
};

function getFlagDifficulty(position?: number, totalRounds = 15): "Easy" | "Medium" | "Hard" | null {
  if (!position) return null;
  if (position <= Math.round(totalRounds * 0.3)) return "Easy";
  if (position <= Math.round(totalRounds * 0.7)) return "Medium";
  return "Hard";
}

type Screen = "home" | "create" | "join" | "lobby" | "game" | "results" | "host-denied";

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
  active_player_name?: string | null;
  is_active_player?: boolean;
  secret_identity?: string | null;
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

type ClueHeistState = {
  clue_number: number;
  current_value: number;
  turn_phase: "spotlight" | "steal" | "revealed";
  is_spotlight: boolean;
  has_attempted: boolean;
  can_guess: boolean;
  clues: Array<{ position: number; text: string }>;
  answer?: string | null;
  image?: { url: string; alt: string } | null;
  explanation?: string | null;
  winner_name?: string | null;
  awarded_points: number;
};

type ServerGameState = {
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
  slowest_player_name?: string | null;
  current_question: CurrentQuestion | null;
  my_answer: MyAnswer;
  leaderboard: LeaderboardEntry[];
  clue_heist?: ClueHeistState | null;
};

function getAllInMessage(name?: string | null, position = 0) {
  if (!name) return "Everyone is locked in. The truth is loading…";
  const lines = [
    `${name} made that timer earn its salary.`,
    `${name} has finally released the suspense.`,
    `${name} arrived fashionably late to the answer party.`,
    `${name} checked the answer twice. Very responsible. Very dramatic.`,
  ];
  const seed = [...name].reduce((total, character) => total + character.charCodeAt(0), position);
  return lines[seed % lines.length];
}

export function GameController({ hostCode }: { hostCode?: string } = {}) {
  const [screen, setScreen] = useState<Screen>("home");
  const [name, setName] = useState("");
  const [roomCode, setRoomCode] = useState("");
  const [selectedGame, setSelectedGame] = useState("trivia-kenya");
  const [flagRoundCount, setFlagRoundCount] = useState<FlagRoundCount>(15);
  const [isConnecting, setIsConnecting] = useState(false);
  const [connectionError, setConnectionError] = useState("");
  const [liveRoomId, setLiveRoomId] = useState("");
  const [isHost, setIsHost] = useState(false);
  const [hostName, setHostName] = useState("");
  const [serverState, setServerState] = useState<ServerGameState | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [copied, setCopied] = useState(false);
  const [secondsRemaining, setSecondsRemaining] = useState<number | null>(null);

  const room = useMemo(() => serverState?.room_code || roomCode || "MAV1", [serverState?.room_code, roomCode]);
  const chosenGame = playableGames.find((g) => g.id === selectedGame) ?? playableGames[0];
  const livePhase = serverState?.phase;
  const liveRoundId = serverState?.current_question?.round_id;
  const liveRoundClosesAt = serverState?.current_question?.closes_at;
  const liveRoundPosition = serverState?.current_question?.position;

  // Refresh Game State from Server Authority
  const refreshGameState = useCallback(async (roomId?: string) => {
    const id = roomId || liveRoomId;
    if (!id || !supabase) return;

    try {
      await ensureGameIdentity();
      const { data, error } = await supabase.rpc("get_player_game_state", { p_room_id: id });

      if (error) {
        // Room may no longer exist
        if (error.message.includes("Room not found") || error.message.includes("not a player")) {
          sessionStorage.removeItem("mavelas_room_id");
          setLiveRoomId("");
          setScreen("home");
        }
        return;
      }

      if (data) {
        const state = data as ServerGameState;
        if (state.phase === "all_answered") {
          const { data: publicState } = await supabase.rpc("get_public_room_state", {
            p_room_code: state.room_code,
          });
          state.slowest_player_name = (publicState as { slowest_player_name?: string | null } | null)?.slowest_player_name;
        }
        if (state.current_question?.game_mode === "guess_image") {
          const { data: clueData } = await supabase.rpc("get_clue_heist_state", {
            p_round_id: state.current_question.round_id,
          });
          state.clue_heist = clueData as ClueHeistState | null;
        }
        setServerState(state);
        setIsHost(state.is_host);
        setHostName(state.host_name);
        if (state.room_code) setRoomCode(state.room_code);

        // Sync selected game if in lobby
        if (state.status === "lobby") {
          const matched = playableGames.find((g) => g.id === state.selected_game || g.template === state.selected_game);
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

  // Restore a host controller only from the dedicated /host/[code] surface.
  // Authority is always verified against rooms.host_id on the server-facing database,
  // never inferred from device type, screen size, or local browser state.
  useEffect(() => {
    if (!hostCode || !supabase) return;
    const client = supabase;

    let cancelled = false;
    const restoreHostController = async () => {
      setConnectionError("");
      setRoomCode(hostCode);
      try {
        const user = await ensureGameIdentity();
        const { data: roomData, error } = await client
          .from("rooms")
          .select("id, code, host_id")
          .eq("code", hostCode)
          .single();

        if (error || !roomData) throw new Error("Host room not found. Check the room link.");
        if (roomData.host_id !== user.id) {
          if (!cancelled) setScreen("host-denied");
          return;
        }

        if (cancelled) return;
        sessionStorage.setItem("mavelas_room_id", roomData.id);
        setLiveRoomId(roomData.id);
        setRoomCode(roomData.code);
        setIsHost(true);
        await refreshGameState(roomData.id);
      } catch (err) {
        if (!cancelled) {
          setConnectionError(err instanceof Error ? err.message : "Could not restore the host controller.");
          setScreen("host-denied");
        }
      }
    };

    void restoreHostController();
    return () => {
      cancelled = true;
    };
  }, [hostCode, refreshGameState]);

  // Check URL parameters and sessionStorage for seamless refresh recovery.
  // A dedicated host route always wins over a previous room saved in this browser.
  useEffect(() => {
    if (typeof window === "undefined") return;

    if (hostCode) return;

    const timer = window.setTimeout(() => {
      const params = new URLSearchParams(window.location.search);
      const codeParam = params.get("code");
      if (codeParam) {
        setRoomCode(codeParam.toUpperCase().slice(0, 6));
        setScreen("join");
      }

      const savedRoomId = sessionStorage.getItem("mavelas_room_id");
      const savedName = sessionStorage.getItem("mavelas_player_name");
      if (savedName) setName(savedName);
      if (savedRoomId) {
        setLiveRoomId(savedRoomId);
        void refreshGameState(savedRoomId);
      }
    }, 0);
    return () => window.clearTimeout(timer);
  }, [hostCode, refreshGameState]);

  // Realtime subscription to room changes
  useEffect(() => {
    if (!liveRoomId || !supabase) return;
    const client = supabase;

    const initialRefresh = window.setTimeout(() => void refreshGameState(), 0);

    const channel = client
      .channel("room-player-" + liveRoomId)
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
      window.clearTimeout(initialRefresh);
      void client.removeChannel(channel);
    };
  }, [liveRoomId, refreshGameState]);

  // Any connected controller can safely trigger the server-checked reveal.
  // All-in rounds pause for the intermission; expired timers reveal immediately.
  useEffect(() => {
    const allInReady = livePhase === "all_answered";
    const timerExpired = livePhase === "playing" && secondsRemaining === 0;
    if ((!allInReady && !timerExpired) || !liveRoundId || !liveRoomId || !supabase) return;
    const client = supabase;

    const timer = window.setTimeout(() => {
      void client
        .rpc("auto_reveal_round", { p_room_id: liveRoomId })
        .then(() => refreshGameState());
    }, allInReady ? 3100 : 250);

    return () => window.clearTimeout(timer);
  }, [livePhase, liveRoundId, liveRoomId, refreshGameState, secondsRemaining]);

  // Reveals stay on screen long enough to celebrate, then the server advances.
  useEffect(() => {
    if (livePhase !== "revealed" || !liveRoundId || !liveRoomId || !supabase) return;
    const client = supabase;

    const timer = window.setTimeout(() => {
      void client
        .rpc("auto_advance_round", { p_room_id: liveRoomId })
        .then(() => refreshGameState());
    }, 6200);

    return () => window.clearTimeout(timer);
  }, [livePhase, liveRoundId, liveRoomId, refreshGameState]);

  // Synchronized countdown timer for player controller
  useEffect(() => {
    if (!liveRoundClosesAt || livePhase !== "playing") {
      const resetTimer = window.setTimeout(() => setSecondsRemaining(null), 0);
      return () => window.clearTimeout(resetTimer);
    }

    const targetTime = new Date(liveRoundClosesAt).getTime();

    const updateTimer = () => {
      const now = Date.now();
      const diff = Math.max(0, Math.ceil((targetTime - now) / 1000));
      setSecondsRemaining(diff);
    };

    updateTimer();
    const interval = setInterval(updateTimer, 500);
    return () => clearInterval(interval);
  }, [liveRoundClosesAt, livePhase, liveRoundPosition]);

  async function createLiveRoom() {
    setConnectionError("");
    setIsConnecting(true);
    try {
      await ensureGameIdentity();
      if (!supabase) throw new Error("Live game service not configured.");
      const { data: created, error: roomError } = await supabase.rpc("create_game_room", {
        p_nickname: name.trim(),
        p_selected_game: selectedGame,
      });
      if (roomError || !created) throw roomError ?? new Error("Could not create the room.");

      const room = created as { id: string; code: string };

      sessionStorage.setItem("mavelas_room_id", room.id);
      sessionStorage.setItem("mavelas_player_name", name.trim());
      // A creator always continues on the explicit host-controller surface.
      // The TV/display is opened separately at /display/[code].
      window.location.assign(`/host/${room.code}`);
      return;
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not create room.");
    } finally {
      setIsConnecting(false);
    }
  }

  async function createDisplayRoom() {
    setConnectionError("");
    setIsConnecting(true);
    try {
      await ensureGameIdentity();
      if (!supabase) throw new Error("Live game service not configured.");

      const { data: created, error: roomError } = await supabase.rpc("create_display_room");
      if (roomError || !created) throw roomError ?? new Error("Could not open a display room.");

      const displayRoom = created as { code: string };
      window.location.assign(`/display/${displayRoom.code}`);
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not open a display room.");
    } finally {
      setIsConnecting(false);
    }
  }

  async function joinLiveRoom() {
    setConnectionError("");
    setIsConnecting(true);
    try {
      await ensureGameIdentity();
      if (!supabase) throw new Error("Live game service not configured.");

      const { data: joined, error: joinError } = await supabase.rpc("join_game_room", {
        p_room_code: roomCode.toUpperCase().trim(),
        p_nickname: name.trim(),
      });
      if (joinError || !joined) throw joinError ?? new Error("Could not join the room.");

      const roomData = joined as {
        id: string;
        code: string;
        status: string;
        selected_game: string;
        role: "host" | "player" | "spectator";
      };

      sessionStorage.setItem("mavelas_room_id", roomData.id);
      sessionStorage.setItem("mavelas_player_name", name.trim());
      setLiveRoomId(roomData.id);
      setRoomCode(roomData.code);
      // Keep the first display scanner in this controller instead of relying on
      // a route handoff. The server-issued role is authoritative and the
      // immediate host state keeps the game chooser/start button available.
      setIsHost(roomData.role === "host");
      if (roomData.role === "host") setHostName(name.trim());
      await refreshGameState(roomData.id);
      setScreen(roomData.status === "playing" ? "game" : "lobby");
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not join room.");
    } finally {
      setIsConnecting(false);
    }
  }

  async function handleSelectGame(gameId: string) {
    if (!isHost || !liveRoomId || !supabase) return;
    setConnectionError("");
    const { error } = await supabase.rpc("select_room_game", {
      p_room_id: liveRoomId,
      p_selected_game: gameId,
    });
    if (error) {
      setConnectionError(error.message);
      return;
    }
    setSelectedGame(gameId);
    await refreshGameState();
  }

  async function handleStartGame() {
    const game = playableGames.find((g) => g.id === selectedGame);
    if (!game || !game.template) {
      setConnectionError("Choose a playable game or Trivia Vault branch first.");
      return;
    }
    if (!supabase || !liveRoomId) return;

    setConnectionError("");
    setIsSubmitting(true);
    try {
      const { error } = await supabase.rpc("start_game", {
        p_room_id: liveRoomId,
        p_template_code: game.template,
        ...(game.id === "flags" ? { p_round_count: flagRoundCount } : {}),
      });
      if (error) throw error;
      await refreshGameState();
      setScreen("game");
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not start game.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleSubmitAnswer(optionId: string) {
    if (!supabase || !serverState?.current_question?.round_id || isSubmitting) return;

    setConnectionError("");
    setIsSubmitting(true);
    try {
      const { error } = await supabase.rpc("submit_game_answer", {
        p_round_id: serverState.current_question.round_id,
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

  async function handleWhoAmIGuess(guess: string) {
    if (!supabase || !serverState?.current_question?.round_id || isSubmitting) return;

    setConnectionError("");
    setIsSubmitting(true);
    try {
      const { error } = await supabase.rpc("submit_who_am_i_guess", {
        p_round_id: serverState.current_question.round_id,
        p_guess: guess.trim(),
      });
      if (error) throw error;
      await refreshGameState();
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not submit your guess.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleClueHeistGuess(guess: string) {
    if (!supabase || !serverState?.current_question?.round_id || isSubmitting) return;
    setConnectionError("");
    setIsSubmitting(true);
    try {
      const { error } = await supabase.rpc("submit_clue_heist_guess", {
        p_round_id: serverState.current_question.round_id,
        p_guess: guess.trim(),
      });
      if (error) throw error;
      await refreshGameState();
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not submit your guess.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleNextClue() {
    if (!supabase || !serverState?.current_question?.round_id || isSubmitting) return;
    setConnectionError("");
    setIsSubmitting(true);
    try {
      const { error } = await supabase.rpc("advance_clue_heist_clue", {
        p_round_id: serverState.current_question.round_id,
      });
      if (error) throw error;
      await refreshGameState();
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not reveal the next clue.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleReplayGame() {
    if (!supabase || !liveRoomId || !isHost || isSubmitting) return;
    setConnectionError("");
    setIsSubmitting(true);
    try {
      const { error } = await supabase.rpc("host_replay_game", { p_room_id: liveRoomId });
      if (error) throw error;
      await refreshGameState();
      setScreen("game");
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not replay this game.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleReturnToLobby() {
    if (!supabase || !liveRoomId || !isHost || isSubmitting) return;
    setConnectionError("");
    setIsSubmitting(true);
    try {
      const { error } = await supabase.rpc("host_return_to_lobby", { p_room_id: liveRoomId });
      if (error) throw error;
      await refreshGameState();
      setScreen("lobby");
    } catch (err) {
      setConnectionError(err instanceof Error ? err.message : "Could not return to the lobby.");
    } finally {
      setIsSubmitting(false);
    }
  }

  function handleCopyInvite() {
    if (typeof window === "undefined") return;
    const url = `${window.location.origin}/?code=${room}`;
    navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2500);
  }

  function handleLeaveRoom() {
    sessionStorage.removeItem("mavelas_room_id");
    setLiveRoomId("");
    setServerState(null);
    setScreen("home");
  }

  if (screen === "host-denied") {
    return <HostAccessScreen roomCode={roomCode} error={connectionError} />;
  }

  // ROUTING RENDER

  if (screen === "game" && serverState) {
    return (
      <GameScreen
        state={serverState}
        secondsRemaining={secondsRemaining}
        isSubmitting={isSubmitting}
        error={connectionError}
        onAnswer={handleSubmitAnswer}
        onWhoAmIGuess={handleWhoAmIGuess}
        onClueHeistGuess={handleClueHeistGuess}
        onNextClue={handleNextClue}
      />
    );
  }

  if (screen === "results" && serverState) {
    return (
      <ResultsScreen
        room={room}
        isHost={isHost}
        leaderboard={serverState.leaderboard}
        isSubmitting={isSubmitting}
        error={connectionError}
        onReplay={isHost ? handleReplayGame : undefined}
        onEndGame={isHost ? handleReturnToLobby : undefined}
        onHome={handleLeaveRoom}
      />
    );
  }

  if (screen === "lobby") {
    const playersList = serverState?.leaderboard || (name ? [{ name, score: 0, is_me: true, is_host: isHost }] : []);
    return (
      <Lobby
        room={room}
        players={playersList}
        hostName={hostName || (isHost ? name : "Host")}
        selectedGame={selectedGame}
        setSelectedGame={handleSelectGame}
        chosenGame={chosenGame}
        flagRoundCount={flagRoundCount}
        setFlagRoundCount={setFlagRoundCount}
        isHost={isHost}
        isPlaying={isSubmitting}
        copied={copied}
        onCopyInvite={handleCopyInvite}
        error={connectionError}
        onStart={handleStartGame}
        onLeave={handleLeaveRoom}
        onHome={handleLeaveRoom}
      />
    );
  }

  if (screen === "create" || screen === "join") {
    const isCreate = screen === "create";
    return (
      <main className="min-h-screen bg-[#101314] text-white">
        <div className="mx-auto flex min-h-screen max-w-xl flex-col px-5 pb-10 pt-5 sm:px-8">
          <Topbar compact onHome={() => setScreen("home")} />
          <section className="my-auto rounded-[2.2rem] bg-[#f0eee8] p-6 text-[#101314] sm:p-9 shadow-2xl">
            <span className="eyebrow-dark">{isCreate ? "Host a session" : "Join the table"}</span>
            <h1 className="mt-3 text-4xl font-black tracking-[-0.06em]">
              {isCreate ? "Start the vibe." : "You are invited."}
            </h1>
            <p className="mt-3 text-[15px] leading-6 text-black/60">
              {isCreate
                ? "Make a room. Connect your TV and phones together."
                : "Enter your nickname to join the room and controller."}
            </p>

            <label className="field-label mt-7" htmlFor="name">
              Your game name
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
              className="button-dark mt-7 w-full"
              disabled={!name.trim() || (!isCreate && roomCode.length < 4) || isConnecting}
              onClick={isCreate ? createLiveRoom : joinLiveRoom}
            >
              {isConnecting ? "Connecting..." : isCreate ? "Create room" : "Join room"} <ArrowRight size={18} />
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

  // Home Screen
  return (
    <main className="min-h-screen overflow-hidden bg-[#101314] text-white">
      <div className="noise" />
      <div className="mx-auto max-w-6xl px-5 pb-12 pt-5 sm:px-8">
        <Topbar onCreate={() => setScreen("create")} onJoin={() => setScreen("join")} />

        <section className="grid min-h-[500px] items-center gap-10 py-16 lg:grid-cols-[1.15fr_.85fr] lg:py-20">
          <div className="relative z-10">
            <span className="eyebrow">A live party game for your people</span>
            <h1 className="mt-4 max-w-3xl text-[3.6rem] font-black leading-[.86] tracking-[-.085em] sm:text-[5.8rem] lg:text-[7rem]">
              LET THE<br />
              <span className="text-[#d7ff3f]">TABLE</span> TALK.
            </h1>
            <p className="mt-7 max-w-lg text-lg leading-7 text-white/60">
              Kenyan & African-rooted party games. Big screen for the room, smartphones for the controllers.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <button className="button-lime" onClick={createDisplayRoom} disabled={isConnecting}>
                <Monitor size={18} />
                {isConnecting ? "Opening display..." : "Display"}
              </button>
              <button className="button-secondary" onClick={() => setScreen("create")} disabled={isConnecting}>
                Create as host <Plus size={18} />
              </button>
              <button className="button-secondary" onClick={() => setScreen("join")} disabled={isConnecting}>
                Join with code <ArrowRight size={17} />
              </button>
            </div>
            {connectionError && (
              <p role="alert" className="mt-4 max-w-lg text-sm font-bold text-rose-400">
                {connectionError}
              </p>
            )}
            <div className="mt-10 flex items-center gap-5 text-sm text-white/45">
              <span className="flex items-center gap-2">
                <Users size={16} /> 2–12 players
              </span>
              <span className="flex items-center gap-2">
                <Gamepad2 size={16} /> Realtime controllers
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
                  alt="Kenya flag preview"
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
            <div className="absolute -right-2 -top-6 rounded-2xl bg-[#ff4fa3] px-4 py-2.5 font-black text-[#101314] shadow-lg">
              Live Engine Ready!
            </div>
          </div>
        </section>

        <section className="border-t border-white/10 pt-8">
          <div className="mb-5 flex items-end justify-between gap-4">
            <div>
              <p className="eyebrow">Playable decks</p>
              <h2 className="mt-2 text-3xl font-black tracking-[-.06em]">Party Modes</h2>
            </div>
            <span className="text-sm text-[#d7ff3f] font-bold">Phase 3 Live</span>
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

        <section className="mt-12 rounded-[2rem] bg-white/[.06] p-6 sm:flex sm:items-center sm:justify-between sm:p-8">
          <div className="flex items-center gap-4">
            <div className="grid h-12 w-12 place-items-center rounded-2xl bg-[#d7ff3f] text-[#101314]">
              <Trophy size={24} />
            </div>
            <div>
              <p className="font-black">Two Surfaces. One Table.</p>
              <p className="text-sm text-white/55">Cast to the TV, keep phone controllers in hand.</p>
            </div>
          </div>
          <button className="button-secondary mt-5 sm:mt-0" onClick={() => setScreen("create")}>
            Host tonight <Crown size={17} />
          </button>
        </section>
      </div>
    </main>
  );
}

// LOBBY COMPONENT
function Lobby({
  room,
  players,
  hostName,
  selectedGame,
  setSelectedGame,
  chosenGame,
  flagRoundCount,
  setFlagRoundCount,
  isHost,
  isPlaying,
  copied,
  onCopyInvite,
  error,
  onStart,
  onLeave,
  onHome,
}: {
  room: string;
  players: LeaderboardEntry[];
  hostName: string;
  selectedGame: string;
  setSelectedGame: (id: string) => void;
  chosenGame: typeof playableGames[number];
  flagRoundCount: FlagRoundCount;
  setFlagRoundCount: (count: FlagRoundCount) => void;
  isHost: boolean;
  isPlaying: boolean;
  copied: boolean;
  onCopyInvite: () => void;
  error: string;
  onStart: () => void;
  onLeave: () => void;
  onHome: () => void;
}) {
  const displayUrl = `/display/${room}`;

  return (
    <main className="min-h-screen bg-[#101314] text-white">
      <div className="mx-auto flex min-h-screen max-w-5xl flex-col px-5 pb-10 pt-5 sm:px-8">
        <Topbar compact onHome={onHome} />

        <section className="mt-10 grid gap-8 lg:grid-cols-[1.2fr_.8fr] lg:items-start">
          <div>
            <span className="eyebrow">{isHost ? "Host Console" : "Player Controller"}</span>
            <h1 className="mt-3 text-4xl font-black tracking-[-0.06em] sm:text-6xl">
              {isHost ? "The room is\nready." : `You're in ${hostName || "Host"}'s\nroom.`}
            </h1>
            <p className="mt-4 max-w-md text-base leading-7 text-white/60">
              {isHost
                ? "Choose a game or Trivia Vault branch, open the shared TV screen, and start when everyone is ready."
                : `Waiting for ${hostName || "the host"} to start the game. Keep this phone open.`}
            </p>

            <div className="mt-7 rounded-[2rem] border border-white/10 bg-white/[.05] p-5 sm:p-7 shadow-lg">
              <div className="flex flex-wrap items-end justify-between gap-5">
                <div>
                  <p className="text-xs font-bold uppercase tracking-[.16em] text-white/45">Room code</p>
                  <p className="mt-1 font-mono text-5xl font-black tracking-[.12em] text-[#d7ff3f] sm:text-6xl">{room}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <button className="button-secondary text-sm" onClick={onCopyInvite}>
                    {copied ? <Check size={16} className="text-[#d7ff3f]" /> : <Copy size={16} />}
                    {copied ? "Copied!" : "Copy link"}
                  </button>
                  {isHost && (
                    <a
                      href={displayUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="button-lime text-sm flex items-center gap-2"
                    >
                      <Monitor size={16} /> Open TV Display <ExternalLink size={14} />
                    </a>
                  )}
                </div>
              </div>
            </div>

            <div className="mt-8 rounded-2xl border border-white/10 bg-white/[.03] p-5">
              <div className="flex items-center justify-between pb-3 border-b border-white/10">
                <p className="text-xs font-black uppercase tracking-[.14em] text-white/50">
                  Players at table ({players.length})
                </p>
                <span className="text-xs text-[#d7ff3f] font-bold">
                  {players.length < 2 ? "Waiting for players" : "Ready to play"}
                </span>
              </div>
              <div className="mt-4 flex flex-wrap gap-2.5">
                {players.map((player) => {
                  const isPlayerHost = player.is_host;
                  return (
                    <div
                      key={player.name + (player.is_me ? "-me" : "")}
                      className={`flex items-center gap-2 rounded-xl px-3.5 py-2 text-sm font-bold ${
                        isPlayerHost ? "bg-[#d7ff3f] text-[#101314]" : "bg-white/10 text-white"
                      }`}
                    >
                      {isPlayerHost ? <Crown size={15} fill="currentColor" /> : <Users size={15} />}
                      <span>{player.name}{player.is_me ? " (You)" : ""}</span>
                      <span className="text-[11px] font-black uppercase tracking-wider opacity-70">
                        {isPlayerHost ? "Host" : "Player"}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="mt-6 flex items-center gap-3">
              <button
                onClick={onLeave}
                className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-white/40 hover:text-rose-400 transition"
              >
                <LogOut size={14} /> Leave room
              </button>
            </div>
          </div>

          <aside className="rounded-[2.2rem] bg-[#f0eee8] p-6 text-[#101314] sm:p-7 shadow-2xl">
            {isHost ? (
              <>
                <p className="eyebrow-dark">Select Game Mode</p>
                <div className="mt-4 space-y-2">
                  <div className="rounded-2xl bg-[#101314] p-3 text-white">
                    <div className="flex items-center gap-2 px-2 pb-2 text-sm font-black">
                      <Sparkles size={17} className="text-[#d7ff3f]" /> Trivia Vault
                    </div>
                    <div className="space-y-1">
                      {triviaBranches.map((game) => (
                        <button
                          type="button"
                          aria-pressed={selectedGame === game.id}
                          className={`game-select ${selectedGame === game.id ? "selected" : ""}`}
                          key={game.id}
                          onClick={() => setSelectedGame(game.id)}
                        >
                          <span>{game.title}</span>
                          {selectedGame === game.id && <span className="pick-dot" />}
                        </button>
                      ))}
                    </div>
                  </div>
                  {games.filter((game) => game.id !== "trivia").map((game) => {
                    const Icon = game.icon;
                    return (
                      <button
                        type="button"
                        aria-pressed={selectedGame === game.id}
                        className={`game-select ${selectedGame === game.id ? "selected" : ""}`}
                        key={game.id}
                        onClick={() => setSelectedGame(game.id)}
                      >
                        <Icon size={19} strokeWidth={2.5} />
                        <span>{game.title}</span>
                        {selectedGame === game.id && <span className="pick-dot" />}
                      </button>
                    );
                  })}
                </div>

                <div className="mt-6 rounded-2xl bg-[#101314] p-5 text-white shadow-lg">
                  <p className="text-xs font-bold uppercase tracking-[.14em] text-white/40">Active Deck</p>
                  <p className="mt-2 text-xl font-black">{chosenGame.title}</p>
                  <p className="mt-1 text-sm text-white/60">{chosenGame.description}</p>
                  <p className="mt-3 text-xs text-[#d7ff3f] font-bold">{chosenGame.meta}</p>

                  {selectedGame === "flags" && (
                    <fieldset className="mt-5 border-t border-white/10 pt-4">
                      <legend className="text-xs font-black uppercase tracking-[.14em] text-white/55">
                        Number of flags
                      </legend>
                      <div className="mt-3 grid grid-cols-4 gap-2">
                        {flagRoundOptions.map((count) => (
                          <button
                            type="button"
                            key={count}
                            aria-pressed={flagRoundCount === count}
                            onClick={() => setFlagRoundCount(count)}
                            className={`rounded-xl border px-2 py-2.5 font-mono text-sm font-black transition ${
                              flagRoundCount === count
                                ? "border-[#d7ff3f] bg-[#d7ff3f] text-[#101314]"
                                : "border-white/15 bg-white/[.06] text-white hover:border-white/40"
                            }`}
                          >
                            {count}
                          </button>
                        ))}
                      </div>
                      <p className="mt-3 text-xs font-bold text-white/50">
                        {flagRoundCount} flags · 30 seconds each
                      </p>
                    </fieldset>
                  )}

                  {error && <p role="alert" className="mt-4 text-sm font-bold text-rose-300">{error}</p>}

                  <button
                    className="button-lime mt-5 w-full flex items-center justify-center gap-2"
                    disabled={isPlaying || !chosenGame.isSupported}
                    onClick={onStart}
                  >
                    <Play size={16} fill="currentColor" />
                    {isPlaying ? "Launching..." : "Start Game"}
                  </button>
                </div>
              </>
            ) : (
              <div>
                <p className="eyebrow-dark">Active Session</p>
                <div className="mt-4 rounded-2xl bg-[#101314] p-6 text-white shadow-md">
                  <div className="flex items-center gap-3">
                    <span className="grid h-10 w-10 place-items-center rounded-xl bg-[#d7ff3f] text-[#101314]">
                      <Gamepad2 size={20} />
                    </span>
                    <div>
                      <p className="text-xs font-bold uppercase tracking-[.14em] text-white/40">Selected by Host</p>
                      <p className="text-xl font-black">{chosenGame.title}</p>
                    </div>
                  </div>
                  <p className="mt-4 text-sm leading-6 text-white/70">{chosenGame.description}</p>
                  <div className="mt-5 border-t border-white/10 pt-4">
                    <p className="text-xs font-black uppercase tracking-[.14em] text-[#d7ff3f]">How to play</p>
                    <p className="mt-1.5 text-xs leading-5 text-white/60">{chosenGame.instructions}</p>
                  </div>
                </div>

                <div className="mt-6 rounded-2xl border-2 border-black/10 bg-white/60 p-5 text-center">
                  <div className="inline-block h-3 w-3 rounded-full bg-emerald-500 animate-pulse mr-2" />
                  <span className="text-sm font-bold text-black/70">Connected as player</span>
                  <p className="mt-2 text-xs text-black/50">
                    Questions will appear here. Waiting for {hostName || "the host"} to start.
                  </p>
                </div>
                {error && <p role="alert" className="mt-4 text-sm font-bold text-rose-700">{error}</p>}
              </div>
            )}
          </aside>
        </section>
      </div>
    </main>
  );
}

// PLAYABLE CONTROLLER SCREEN
function GameScreen({
  state,
  secondsRemaining,
  isSubmitting,
  error,
  onAnswer,
  onWhoAmIGuess,
  onClueHeistGuess,
  onNextClue,
}: {
  state: ServerGameState;
  secondsRemaining: number | null;
  isSubmitting: boolean;
  error: string;
  onAnswer: (optionId: string) => void;
  onWhoAmIGuess: (guess: string) => void;
  onClueHeistGuess: (guess: string) => void;
  onNextClue: () => void;
}) {
  const question = state.current_question;
  const myAnswer = state.my_answer;
  const isRevealed = state.phase === "revealed" || myAnswer.is_revealed;
  const allAnswersIn = state.phase === "all_answered" && !isRevealed;
  const hasAnswered = myAnswer.has_answered;
  const isWhoAmI = question?.game_mode === "who_am_i";
  const isClueHeist = question?.game_mode === "guess_image";
  const heist = state.clue_heist;
  const [guess, setGuess] = useState("");

  const modeLabel = modeNames[question?.game_mode || ""] || "Game Mavelas";
  const flagDifficulty =
    question?.game_mode === "flag_frenzy" ? getFlagDifficulty(question.position, question.total_rounds) : null;

  return (
    <main className="min-h-screen bg-[#101314] text-white">
      {allAnswersIn && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-[#101314] px-6 text-center">
          <div className="max-w-xl">
            <p className="text-xs font-black uppercase tracking-[.24em] text-[#d7ff3f]">Pens down. Ego pending.</p>
            <h1 className="mt-5 text-5xl font-black leading-[.9] tracking-[-.07em] sm:text-7xl">ALL ANSWERS<br />ARE IN.</h1>
            <p className="mt-7 text-xl font-black text-white/75">
              {getAllInMessage(state.slowest_player_name, question?.position)}
            </p>
            <p className="mt-7 animate-pulse text-sm font-bold uppercase tracking-[.18em] text-[#d7ff3f]">Reveal incoming…</p>
          </div>
        </div>
      )}
      <div className="mx-auto flex min-h-screen max-w-3xl flex-col px-5 pb-12 pt-5 sm:px-8">
        {/* Game Header */}
        <header className="flex items-center justify-between border-b border-white/10 pb-4">
          <div>
            <span className="text-xs font-black uppercase tracking-[.16em] text-[#d7ff3f]">
              {modeLabel}{flagDifficulty ? ` · ${flagDifficulty}` : ""} · Round {question?.position} of {question?.total_rounds || 10}
            </span>
            <p className="text-sm text-white/50">Score: <strong className="text-white font-mono">{state.my_score} pts</strong></p>
          </div>

          <div className="flex items-center gap-3">
            {secondsRemaining !== null && !isRevealed && !isClueHeist && (
              <div
                className={`flex items-center gap-1.5 rounded-xl px-3 py-1.5 font-mono text-lg font-black ${
                  secondsRemaining <= 5 ? "bg-rose-500/20 text-rose-400 animate-pulse" : "bg-white/10 text-[#d7ff3f]"
                }`}
              >
                <Clock size={16} />
                <span>{secondsRemaining}s</span>
              </div>
            )}
            <span className="rounded-xl border border-white/15 bg-white/[.06] px-3 py-1 font-mono text-xs font-bold text-white/80">
              {state.room_code}
            </span>
          </div>
        </header>

        {/* Question Area */}
        <section className="my-auto py-8">
          {question ? (
            <div className="rounded-[2.2rem] bg-[#f0eee8] p-6 text-[#101314] sm:p-9 shadow-2xl">
              <p className="text-xs font-black uppercase tracking-[.16em] text-black/45">
                {isRevealed ? "Answer Revealed" : isClueHeist ? `Clue ${heist?.clue_number || 1} of 20 · ${heist?.current_value || 100} points` : isWhoAmI ? "Conversation Round" : "Phone Controller"}
              </p>
              <h1 className="mt-2 text-3xl font-black leading-tight tracking-[-.06em] sm:text-4xl">
                {isRevealed ? "Round complete." : isClueHeist ? heist?.turn_phase === "steal" ? "The heist is open!" : heist?.is_spotlight ? "You are in the spotlight." : `${question?.active_player_name || "A player"} has priority.` : isWhoAmI ? question?.is_active_player ? "You are the guesser." : `${question?.active_player_name || "A player"} is the guesser.` : "Look at the shared screen."}
              </h1>
              {!isRevealed && !isWhoAmI && !isClueHeist && <p className="mt-2 text-sm font-bold text-black/55">Tap the letter that matches the answer on TV.</p>}

              {isClueHeist && !isRevealed && (
                <div className="mt-6 space-y-4">
                  <div className={`rounded-2xl p-4 ${heist?.turn_phase === "steal" ? "bg-rose-100 text-rose-950" : "bg-black/[.06]"}`}>
                    <p className="text-sm font-black">
                      {heist?.turn_phase === "steal"
                        ? `STEAL OPEN · worth ${Math.ceil((heist.current_value || 100) / 2)} points`
                        : heist?.is_spotlight
                        ? "Guess now or request another clue."
                        : `Watch the clues. You can steal if ${question?.active_player_name || "the spotlight player"} misses.`}
                    </p>
                  </div>
                  {heist?.can_guess && (
                    <form className="flex gap-2" onSubmit={(event) => { event.preventDefault(); if (guess.trim()) onClueHeistGuess(guess); }}>
                      <input value={guess} onChange={(event) => setGuess(event.target.value)} maxLength={80} placeholder="Type your guess…" className="min-w-0 flex-1 rounded-xl border-2 border-[#101314] bg-white px-4 py-3 text-base font-bold outline-none focus:ring-4 focus:ring-[#39a7ff]/40" />
                      <button className="button-dark px-4 text-sm" disabled={isSubmitting || !guess.trim()} type="submit">{heist.turn_phase === "steal" ? "Steal" : "Guess"}</button>
                    </form>
                  )}
                  {heist?.is_spotlight && heist?.turn_phase !== "revealed" && (
                    <button className="button-light w-full" onClick={onNextClue} disabled={isSubmitting}>Reveal next clue · value drops 5</button>
                  )}
                  {heist?.has_attempted && !heist.can_guess && <p className="text-center text-sm font-bold text-black/55">Your attempt is locked. Watch the heist continue.</p>}
                </div>
              )}

              {isWhoAmI && !isRevealed && (
                question?.is_active_player ? (
                  <div className="mt-6 rounded-2xl bg-black/[.06] p-5">
                    <p className="text-sm font-bold text-black/65">Ask the table yes-or-no questions. When you are ready, type your one final guess.</p>
                    <form
                      className="mt-4 flex gap-2"
                      onSubmit={(event) => {
                        event.preventDefault();
                        if (guess.trim()) onWhoAmIGuess(guess);
                      }}
                    >
                      <input
                        value={guess}
                        onChange={(event) => setGuess(event.target.value)}
                        disabled={hasAnswered || isSubmitting}
                        maxLength={80}
                        placeholder="Type your identity…"
                        className="min-w-0 flex-1 rounded-xl border-2 border-[#101314] bg-white px-4 py-3 text-base font-bold outline-none placeholder:text-black/35 focus:ring-4 focus:ring-[#d7ff3f]/50"
                      />
                      <button className="button-dark px-4 text-sm" disabled={hasAnswered || isSubmitting || !guess.trim()} type="submit">
                        Guess
                      </button>
                    </form>
                  </div>
                ) : (
                  <div className="mt-6 rounded-2xl border-2 border-[#101314] bg-[#101314] p-5 text-[#d7ff3f] shadow-[0_6px_0_#101314]">
                    <p className="text-xs font-black uppercase tracking-[.16em] text-[#d7ff3f]/70">Keep it secret from {question?.active_player_name || "the guesser"}</p>
                    {question?.media?.type === "image" && (
                      <Image
                        src={question.media.url}
                        alt={question.media.alt}
                        width={512}
                        height={512}
                        className="mt-4 aspect-square w-full max-w-sm rounded-3xl border-4 border-white/10 bg-[#d7ff3f] object-cover"
                      />
                    )}
                    <p className="mt-2 text-3xl font-black tracking-[-.05em]">{question?.secret_identity || "Identity loading…"}</p>
                    <p className="mt-2 text-sm font-bold text-white/65">Answer only yes-or-no questions and give fair clues.</p>
                  </div>
                )
              )}
              {/* Options Grid */}
              {!isWhoAmI && !isClueHeist && <div className="mt-7 grid grid-cols-2 gap-3">
                {question.options.map((option, index) => {
                  const optionLetter = String.fromCharCode(65 + index);
                  const isSelected = myAnswer.selected_option_id === option.id;
                  const isCorrect = isRevealed && myAnswer.correct_option_id === option.id;
                  const isWrongSelected = isRevealed && isSelected && !myAnswer.is_correct;

                  let buttonStyle = "border-2 border-[#101314] bg-[#101314] text-[#d7ff3f] shadow-[0_6px_0_#101314] hover:-translate-y-0.5 hover:bg-[#1b2022]";
                  if (isCorrect) {
                    buttonStyle = "border-2 border-[#101314] bg-[#d7ff3f] text-[#101314] font-black shadow-[0_6px_0_#101314]";
                  } else if (isWrongSelected) {
                    buttonStyle = "border-2 border-rose-700 bg-rose-500/20 text-rose-800 opacity-80 shadow-[0_6px_0_#9f1239]";
                  } else if (isSelected) {
                    buttonStyle = "border-2 border-[#101314] bg-[#d7ff3f] text-[#101314] shadow-[0_6px_0_#101314]";
                  }

                  return (
                    <button
                      key={option.id}
                      aria-label={`Answer ${optionLetter}`}
                      disabled={hasAnswered || isRevealed || isSubmitting || (secondsRemaining !== null && secondsRemaining <= 0)}
                      onClick={() => onAnswer(option.id)}
                      className={`controller-pad flex min-h-32 items-center justify-center rounded-[1.5rem] px-4 py-4 text-center font-mono font-black transition disabled:cursor-not-allowed disabled:translate-y-0 disabled:shadow-none sm:min-h-36 ${buttonStyle}`}
                      style={{ fontSize: "clamp(5.5rem, 22vw, 9rem)", fontWeight: 900, lineHeight: 1 }}
                    >
                      <span>{optionLetter}</span>
                    </button>
                  );
                })}
              </div>}

              {/* Answer Status / Feedback */}
              {hasAnswered && !isRevealed && !allAnswersIn && (
                <div className="mt-6 flex items-center justify-center gap-3 rounded-2xl bg-black/[.06] p-4 text-center">
                  <div className="h-2.5 w-2.5 rounded-full bg-emerald-500 animate-ping" />
                  <p className="text-sm font-bold text-black/70">
                    {isWhoAmI ? "Guess locked in — reveal incoming…" : isClueHeist ? "Attempt locked — the heist continues…" : "Answer locked in — waiting for the table…"}
                  </p>
                </div>
              )}

              {/* Timer expired before answer */}
              {!hasAnswered && !isRevealed && !isClueHeist && secondsRemaining === 0 && (
                <div className="mt-6 rounded-2xl bg-rose-100 p-4 text-center text-sm font-bold text-rose-900">
                  Time is up! Submissions closed for this question.
                </div>
              )}

              {/* Reveal Result Banner */}
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
                    <span className="font-mono text-sm font-bold">Total: {state.my_score} pts</span>
                  </div>
                  {isClueHeist && heist?.image && (
                    <Image src={heist.image.url} alt={heist.image.alt} width={1200} height={900} className="mt-5 aspect-[4/3] w-full rounded-3xl bg-white object-contain" />
                  )}
                  {isClueHeist && <p className="mt-4 text-2xl font-black">{heist?.answer}</p>}
                  {myAnswer.explanation && (
                    <p className="mt-2 text-sm font-medium leading-relaxed opacity-90">{myAnswer.explanation}</p>
                  )}
                </div>
              )}

              {error && <p role="alert" className="mt-4 text-sm font-bold text-rose-700">{error}</p>}
            </div>
          ) : (
            <div className="rounded-[2.2rem] bg-[#f0eee8] p-10 text-center text-black">
              <p className="text-lg font-bold">Waiting for round to load…</p>
            </div>
          )}

          <p className="mt-6 text-center text-xs text-white/50">
            {isRevealed
              ? "Next question loading automatically…"
              : "Your phone is your controller. Answers are locked once tapped."}
          </p>
        </section>
      </div>
    </main>
  );
}

// RESULTS SCREEN
function ResultsScreen({
  room,
  isHost,
  leaderboard,
  isSubmitting,
  error,
  onReplay,
  onEndGame,
  onHome,
}: {
  room: string;
  isHost: boolean;
  leaderboard: LeaderboardEntry[];
  isSubmitting: boolean;
  error: string;
  onReplay?: () => void;
  onEndGame?: () => void;
  onHome: () => void;
}) {
  return (
    <main className="min-h-screen bg-[#101314] text-white">
      <div className="mx-auto flex min-h-screen max-w-xl flex-col px-5 pb-10 pt-5 sm:px-8">
        <Topbar compact onHome={onHome} />
        <section className="my-auto rounded-[2.2rem] bg-[#f0eee8] p-8 text-center text-[#101314] shadow-2xl">
          <Trophy className="mx-auto text-[#101314]" size={56} />
          <p className="mt-6 text-xs font-black uppercase tracking-[.16em] text-black/45">Room {room}</p>
          <h1 className="mt-2 text-5xl font-black tracking-[-.07em]">Game Over!</h1>
          <p className="mt-3 text-sm text-black/60">Here is how the table finished:</p>

          <div className="mt-7 space-y-2 text-left">
            {leaderboard.map((entry, index) => (
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
                  <span className="font-bold">{entry.name}</span>
                  {entry.is_me && <span className="text-[10px] uppercase font-bold text-black/60">(You)</span>}
                  {entry.is_host && <span className="text-[10px] uppercase font-bold bg-black/10 px-1.5 py-0.5 rounded">Host</span>}
                </div>
                <span className="font-mono font-black">{entry.score} pts</span>
              </div>
            ))}
          </div>

          <div className="mt-8 flex flex-col gap-3">
            {isHost && onReplay && onEndGame ? (
              <>
                <button type="button" className="button-dark w-full flex items-center justify-center gap-2" disabled={isSubmitting} onClick={onReplay}>
                  <RotateCcw size={16} /> {isSubmitting ? "Please wait…" : "Replay"}
                </button>
                <button type="button" className="w-full rounded-xl border-2 border-[#101314] px-4 py-3 text-sm font-black transition hover:bg-black/10 disabled:opacity-50" disabled={isSubmitting} onClick={onEndGame}>
                  End Game · Return Everyone to Lobby
                </button>
              </>
            ) : (
              <p className="rounded-xl bg-black/[.06] px-4 py-3 text-sm font-bold text-black/60">
                Waiting for the host to replay or return everyone to the lobby…
              </p>
            )}
            {error && <p role="alert" className="text-sm font-bold text-rose-700">{error}</p>}
            <button type="button" className="text-sm font-bold text-black/60 hover:text-black py-2" onClick={onHome}>
              Leave Room
            </button>
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
            Create room
          </button>
        </nav>
      )}
    </header>
  );
}

function HostAccessScreen({ roomCode, error }: { roomCode: string; error: string }) {
  return (
    <main className="min-h-screen bg-[#101314] px-5 py-8 text-white sm:px-8">
      <section className="mx-auto flex min-h-[80vh] max-w-xl flex-col justify-center">
        <span className="eyebrow">Host controller</span>
        <h1 className="mt-3 text-5xl font-black tracking-[-.07em]">This phone is not the host.</h1>
        <p className="mt-5 text-lg leading-7 text-white/60">
          Open the host link on the same phone that created room <strong className="font-mono text-[#d7ff3f]">{roomCode}</strong>.
          The shared display has no controls by design.
        </p>
        {error && <p role="alert" className="mt-5 rounded-2xl bg-rose-500/10 p-4 text-sm font-bold text-rose-300">{error}</p>}
        <Link href="/" className="button-lime mt-8 w-fit">Return to Game Mavelas</Link>
      </section>
    </main>
  );
}

export default function Home() {
  return <GameController />;
}
