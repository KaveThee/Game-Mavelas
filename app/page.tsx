$ next build
▲ Next.js 16.2.6 (Turbopack)

  Creating an optimized production build ...
✓ Compiled successfully in 6.3s
  Running TypeScript ...
  Finished TypeScript in 12.6s ...
  Collecting page data using 4 workers ...
  Generating static pages using 4 workers (0/3) ...
✓ Generating static pages using 4 workers (3/3) in 739ms
  Finalizing page optimization ...

Route (app)
┌ ○ /
└ ○ /_not-found


○  (Static)  prerendered as static content

"use client";

import { useEffect, useMemo, useState } from "react";
import { ArrowRight, Crown, Gamepad2, ImageIcon, MapPinned, Play, Plus, ScanLine, Sparkles, Trophy, Users } from "lucide-react";
import { ensureGameIdentity, supabase } from "@/lib/supabase";

const games = [
  { id: "who", title: "Who Am I?", kicker: "The picture game", icon: ImageIcon, color: "lime", description: "Guess your hidden identity while the table gives clues.", meta: "Kenya · East Africa · World" },
  { id: "flags", title: "Flag Frenzy", kicker: "Fastest finger wins", icon: MapPinned, color: "yellow", description: "Spot the country before time runs out.", meta: "Africa · World · Expert" },
  { id: "trivia", title: "Trivia Rush", kicker: "Multi-phase quiz", icon: Sparkles, color: "pink", description: "Warm-up, risk round, then the final showdown.", meta: "8 categories · 3 phases" },
  { id: "image", title: "Guess the Image", kicker: "Reveal & race", icon: ScanLine, color: "blue", description: "Name what you see before the image becomes clear.", meta: "Animals · Places · Culture" },
];

type Screen = "home" | "create" | "join" | "lobby" | "game" | "results";
type GameQuestion = {
  round_id: string;
  position: number;
  prompt: string;
  explanation?: string | null;
  game_mode: string;
  duration_seconds: number;
  base_points: number;
  media?: { type: string; url: string; alt: string } | null;
  options: { id: string; text: string }[];
};

const templateByGame: Record<string, string | undefined> = {
  who: "who_am_i_kenya",
  flags: "flag_frenzy_africa",
  trivia: "trivia_rush_classic",
};

export default function Home() {
  const [screen, setScreen] = useState<Screen>("home");
  const [name, setName] = useState("");
  const [roomCode, setRoomCode] = useState("");
  const [selectedGame, setSelectedGame] = useState("who");
  const [isConnecting, setIsConnecting] = useState(false);
  const [connectionError, setConnectionError] = useState("");
  const [liveRoomId, setLiveRoomId] = useState("");
  const [players, setPlayers] = useState<string[]>([]);
  const [isHost, setIsHost] = useState(false);
  const [question, setQuestion] = useState<GameQuestion | null>(null);
  const [answerResult, setAnswerResult] = useState<{ is_correct: boolean; points_awarded: number } | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const room = useMemo(() => roomCode || "KAVE", [roomCode]);
  const chosenGame = games.find((game) => game.id === selectedGame) ?? games[0];

  useEffect(() => {
    if (!liveRoomId || !supabase) return;
    const client = supabase;
    const loadPlayers = async () => {
      const { data } = await client.from("room_players").select("nickname").eq("room_id", liveRoomId).order("joined_at");
      setPlayers((data ?? []).map((player) => player.nickname));
    };
    void loadPlayers();
    const channel = client
      .channel("room-" + liveRoomId)
      .on("postgres_changes", { event: "*", schema: "public", table: "room_players", filter: "room_id=eq." + liveRoomId }, loadPlayers)
      .on("postgres_changes", { event: "*", schema: "public", table: "game_rounds", filter: "room_id=eq." + liveRoomId }, () => {
        if (screen === "game") void loadCurrentQuestion();
      })
      .subscribe();
    return () => { void client.removeChannel(channel); };
  }, [liveRoomId, screen]);

  async function loadCurrentQuestion() {
    if (!supabase || !liveRoomId) return;
    const { data, error } = await supabase.rpc("current_game_question", { p_room_id: liveRoomId });
    if (error) {
      setConnectionError(error.message);
      return;
    }
    if (!data) {
      setScreen("results");
      return;
    }
    setQuestion(data as GameQuestion);
    setAnswerResult(null);
  }

  async function createLiveRoom() {
    setConnectionError("");
    setIsConnecting(true);
    try {
      const user = await ensureGameIdentity();
      if (!supabase) throw new Error("The live game service is not configured yet.");
      const code = Array.from({ length: 4 }, () => "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[Math.floor(Math.random() * 32)]).join("");
      const { data: created, error: roomError } = await supabase
        .from("rooms")
        .insert({ code, host_id: user.id })
        .select("id, code")
        .single();
      if (roomError || !created) throw roomError ?? new Error("Could not create the room.");
      const { error: playerError } = await supabase
        .from("room_players")
        .insert({ room_id: created.id, user_id: user.id, nickname: name.trim() });
      if (playerError) throw playerError;
      setLiveRoomId(created.id);
      setPlayers([name.trim()]);
      setRoomCode(created.code);
      setIsHost(true);
      setScreen("lobby");
    } catch (error) {
      setConnectionError(error instanceof Error ? error.message : "Could not create the room. Try again.");
    } finally {
      setIsConnecting(false);
    }
  }

  async function joinLiveRoom() {
    setConnectionError("");
    setIsConnecting(true);
    try {
      const user = await ensureGameIdentity();
      if (!supabase) throw new Error("The live game service is not configured yet.");
      const { data: room, error: lookupError } = await supabase
        .from("rooms")
        .select("id, code")
        .eq("code", roomCode)
        .eq("status", "lobby")
        .single();
      if (lookupError || !room) throw new Error("That room was not found or has already started.");
      const { error: playerError } = await supabase
        .from("room_players")
        .upsert({ room_id: room.id, user_id: user.id, nickname: name.trim() }, { onConflict: "room_id,user_id" });
      if (playerError) throw playerError;
      setLiveRoomId(room.id);
      setPlayers([name.trim()]);
      setIsHost(false);
      setScreen("lobby");
    } catch (error) {
      setConnectionError(error instanceof Error ? error.message : "Could not join the room. Try again.");
    } finally {
      setIsConnecting(false);
    }
  }

  async function startGame() {
    const template = templateByGame[selectedGame];
    if (!template) {
      setConnectionError("Guess the Image is being prepared with licensed image rounds. Choose another live deck for now.");
      return;
    }
    if (!supabase || !liveRoomId) return;
    setConnectionError("");
    setIsPlaying(true);
    const { error } = await supabase.rpc("start_game", { p_room_id: liveRoomId, p_template_code: template });
    if (error) {
      setConnectionError(error.message);
      setIsPlaying(false);
      return;
    }
    setScreen("game");
    await loadCurrentQuestion();
    setIsPlaying(false);
  }

  async function submitAnswer(optionId: string) {
    if (!supabase || !question || answerResult) return;
    setIsPlaying(true);
    const { data, error } = await supabase.rpc("submit_game_answer", { p_round_id: question.round_id, p_option_id: optionId });
    if (error) setConnectionError(error.message);
    else setAnswerResult(data as { is_correct: boolean; points_awarded: number });
    setIsPlaying(false);
  }

  async function advanceRound() {
    if (!supabase || !liveRoomId) return;
    setIsPlaying(true);
    const { data, error } = await supabase.rpc("advance_game_round", { p_room_id: liveRoomId });
    if (error) setConnectionError(error.message);
    else if ((data as { finished?: boolean }).finished) setScreen("results");
    else await loadCurrentQuestion();
    setIsPlaying(false);
  }

  if (screen === "game" && question) return <GameScreen room={room} question={question} isHost={isHost} isPlaying={isPlaying} answerResult={answerResult} error={connectionError} onAnswer={submitAnswer} onNext={advanceRound} />;
  if (screen === "results") return <ResultsScreen room={room} players={players} onHome={() => setScreen("home")} />;
  if (screen === "lobby") return <Lobby room={room} players={players} selectedGame={selectedGame} setSelectedGame={setSelectedGame} chosenGame={chosenGame} isHost={isHost} isPlaying={isPlaying} error={connectionError} onStart={startGame} onHome={() => setScreen("home")} />;

  if (screen === "create" || screen === "join") {
    const isCreate = screen === "create";
    return <main className="min-h-screen bg-[#101314] text-white"><div className="mx-auto flex min-h-screen max-w-xl flex-col px-5 pb-10 pt-5 sm:px-8">
      <Topbar compact onHome={() => setScreen("home")} />
      <section className="my-auto rounded-[2rem] bg-[#f0eee8] p-6 text-[#101314] sm:p-9">
        <span className="eyebrow-dark">{isCreate ? "Host a session" : "Join the table"}</span>
        <h1 className="mt-3 text-4xl font-black tracking-[-0.06em]">{isCreate ? "Start the vibe." : "You are invited."}</h1>
        <p className="mt-3 text-[15px] leading-6 text-black/60">{isCreate ? "Make a room. Your friends can join with a code or QR link." : "Enter the room code and your game name to join."}</p>
        <label className="field-label mt-7" htmlFor="name">Your game name</label>
        <input id="name" autoFocus value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Kave" className="field" />
        {!isCreate && <><label className="field-label mt-5" htmlFor="room">Room code</label><input id="room" value={roomCode} onChange={(e) => setRoomCode(e.target.value.toUpperCase().slice(0, 4))} placeholder="KAVE" className="field font-mono uppercase tracking-[.2em]" /></>}
        {connectionError && <p role="alert" className="mt-4 text-sm font-bold text-rose-700">{connectionError}</p>}
        <button className="button-dark mt-7 w-full" disabled={!name || (!isCreate && roomCode.length !== 4) || isConnecting} onClick={isCreate ? createLiveRoom : joinLiveRoom}>{isConnecting ? "Connecting..." : isCreate ? "Create room" : "Join room"} <ArrowRight size={18} /></button>
        <button className="mt-4 w-full text-sm font-bold text-black/50 hover:text-black" onClick={() => setScreen("home")}>Back</button>
      </section>
    </div></main>;
  }

  return <main className="min-h-screen overflow-hidden bg-[#101314] text-white"><div className="noise" /><div className="mx-auto max-w-6xl px-5 pb-12 pt-5 sm:px-8">
    <Topbar onCreate={() => setScreen("create")} onJoin={() => setScreen("join")} />
    <section className="grid min-h-[500px] items-center gap-10 py-16 lg:grid-cols-[1.15fr_.85fr] lg:py-20">
      <div className="relative z-10"><span className="eyebrow">A live party game for your people</span>
        <h1 className="mt-4 max-w-3xl text-[3.6rem] font-black leading-[.86] tracking-[-.085em] sm:text-[5.8rem] lg:text-[7rem]">LET THE<br /><span className="text-[#d7ff3f]">TABLE</span> TALK.</h1>
        <p className="mt-7 max-w-lg text-lg leading-7 text-white/60">Kenyan-rooted games for the group chat that finally left the group chat. Create a room, scan in, and play together.</p>
        <div className="mt-8 flex flex-wrap gap-3"><button className="button-lime" onClick={() => setScreen("create")}>Create a game <Plus size={18} /></button><button className="button-secondary" onClick={() => setScreen("join")}>Join with code <ArrowRight size={17} /></button></div>
        <div className="mt-10 flex items-center gap-5 text-sm text-white/45"><span className="flex items-center gap-2"><Users size={16} /> 2–12 players</span><span className="flex items-center gap-2"><Gamepad2 size={16} /> Phones only</span></div>
      </div>
      <div className="relative mx-auto w-full max-w-md"><div className="absolute -inset-10 rounded-full bg-[#d7ff3f]/15 blur-3xl" /><div className="relative rotate-[-5deg] rounded-[2rem] bg-[#f0eee8] p-4 text-[#101314] shadow-[20px_24px_0_#d7ff3f] sm:p-6">
        <div className="flex items-center justify-between border-b border-black/10 pb-4"><span className="rounded-full bg-black px-3 py-1 text-xs font-black tracking-wide text-white">WHO AM I?</span><span className="font-mono text-sm font-bold">00:42</span></div>
        <div className="my-5 grid aspect-[4/3] place-items-center rounded-[1.3rem] bg-[#d7ff3f]"><span className="text-[7rem] font-black leading-none tracking-[-.15em]">?</span></div>
        <p className="text-xs font-bold uppercase tracking-[.15em] text-black/45">Category</p><p className="mt-1 text-2xl font-black tracking-[-.05em]">Kenyan Music</p>
        <div className="mt-5 grid grid-cols-2 gap-2"><button className="rounded-xl bg-[#101314] px-4 py-3 text-sm font-black text-white">CORRECT +1</button><button className="rounded-xl border-2 border-[#101314] px-4 py-3 text-sm font-black">PASS</button></div>
      </div><div className="absolute -right-1 -top-7 rounded-2xl bg-[#ff4fa3] px-4 py-3 font-black text-[#101314] shadow-lg">your turn!</div></div>
    </section>
    <section className="border-t border-white/10 pt-8"><div className="mb-5 flex items-end justify-between gap-4"><div><p className="eyebrow">Pick your challenge</p><h2 className="mt-2 text-3xl font-black tracking-[-.06em]">Four ways to start.</h2></div><span className="hidden text-sm text-white/40 sm:block">More decks are coming.</span></div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">{games.map((game) => { const Icon = game.icon; return <article className={"game-card " + game.color} key={game.id}><Icon size={26} strokeWidth={2.6} /><p className="mt-8 text-xs font-black uppercase tracking-[.14em] opacity-60">{game.kicker}</p><h3 className="mt-1 text-2xl font-black tracking-[-.055em]">{game.title}</h3><p className="mt-3 text-sm leading-5 opacity-75">{game.description}</p><p className="mt-5 text-xs font-bold opacity-60">{game.meta}</p></article>; })}</div>
    </section>
    <section className="mt-12 rounded-[2rem] bg-white/[.06] p-6 sm:flex sm:items-center sm:justify-between sm:p-8"><div className="flex items-center gap-4"><div className="grid h-12 w-12 place-items-center rounded-2xl bg-[#d7ff3f] text-[#101314]"><Trophy size={24} /></div><div><p className="font-black">One leaderboard. One table.</p><p className="text-sm text-white/55">Your scores follow every game in the session.</p></div></div><button className="button-secondary mt-5 sm:mt-0" onClick={() => setScreen("create")}>Host tonight <Crown size={17} /></button></section>
  </div></main>;
}

function Lobby({ room, players, selectedGame, setSelectedGame, chosenGame, isHost, isPlaying, error, onStart, onHome }: { room: string; players: string[]; selectedGame: string; setSelectedGame: (id: string) => void; chosenGame: typeof games[number]; isHost: boolean; isPlaying: boolean; error: string; onStart: () => void; onHome: () => void }) {
  return <main className="min-h-screen bg-[#101314] text-white"><div className="mx-auto flex min-h-screen max-w-5xl flex-col px-5 pb-10 pt-5 sm:px-8"><Topbar compact onHome={onHome} />
    <section className="mt-10 grid gap-8 lg:grid-cols-[1.2fr_.8fr] lg:items-start"><div><span className="eyebrow">Live lobby</span><h1 className="mt-3 text-4xl font-black tracking-[-0.06em] sm:text-6xl">The room is<br />ready.</h1><p className="mt-4 max-w-md text-base leading-7 text-white/60">Share this code with your people. Everyone joins on their phone, then you choose the game.</p>
      <div className="mt-7 rounded-[2rem] border border-white/10 bg-white/[.05] p-5 sm:p-7"><div className="flex flex-wrap items-end justify-between gap-5"><div><p className="text-xs font-bold uppercase tracking-[.16em] text-white/45">Room code</p><p className="mt-1 font-mono text-5xl font-black tracking-[.12em] text-[#d7ff3f] sm:text-6xl">{room}</p></div><button className="button-secondary">Copy invite</button></div></div>
      <div className="mt-8 flex items-center gap-3"><div className="flex -space-x-2">{players.slice(0, 4).map((player,index) => <span className={"avatar avatar-" + (index % 3)} key={player}>{player.slice(0, 1).toUpperCase()}</span>)}</div><p className="text-sm text-white/55"><strong className="text-white">{players.length} player{players.length === 1 ? "" : "s"}</strong> in the room · {players.length < 2 ? "waiting for more" : "ready to play"}</p></div>
    </div><aside className="rounded-[2rem] bg-[#f0eee8] p-5 text-[#101314] sm:p-7"><p className="eyebrow-dark">Choose a game</p><div className="mt-4 space-y-2">{games.map((game) => { const Icon = game.icon; return <button className={"game-select " + (selectedGame === game.id ? "selected" : "")} key={game.id} onClick={() => setSelectedGame(game.id)}><Icon size={19} strokeWidth={2.5} /><span>{game.title}</span>{selectedGame === game.id && <span className="pick-dot" />}</button>; })}</div>
      <div className="mt-6 rounded-2xl bg-[#101314] p-5 text-white"><p className="text-xs font-bold uppercase tracking-[.14em] text-white/40">Selected</p><p className="mt-2 text-xl font-black">{chosenGame.title}</p><p className="mt-1 text-sm text-white/60">{chosenGame.description}</p>{error && <p role="alert" className="mt-4 text-sm font-bold text-rose-300">{error}</p>}<button className="button-lime mt-5 w-full" disabled={!isHost || isPlaying} onClick={onStart}>{isPlaying ? "Starting..." : isHost ? "Start game" : "Host starts the game"} <Play size={16} fill="currentColor" /></button></div>
    </aside></section></div></main>;
}

function GameScreen({ room, question, isHost, isPlaying, answerResult, error, onAnswer, onNext }: { room: string; question: GameQuestion; isHost: boolean; isPlaying: boolean; answerResult: { is_correct: boolean; points_awarded: number } | null; error: string; onAnswer: (optionId: string) => void; onNext: () => void }) {
  const modeLabel = games.find((game) => (question.game_mode === "flag_frenzy" ? game.id === "flags" : question.game_mode === "who_am_i" ? game.id === "who" : game.id === "trivia"))?.title ?? "Game Mavelas";
  return <main className="min-h-screen bg-[#101314] text-white"><div className="mx-auto flex min-h-screen max-w-3xl flex-col px-5 pb-10 pt-5 sm:px-8"><Topbar compact />
    <section className="my-auto py-10"><div className="flex items-center justify-between text-sm font-bold text-white/50"><span>{modeLabel} · Round {question.position}</span><span className="font-mono text-[#d7ff3f]">{question.duration_seconds}s</span></div>
      <div className="mt-5 rounded-[2rem] bg-[#f0eee8] p-6 text-[#101314] sm:p-9">{question.media?.type === "flag" && <img src={question.media.url} alt={question.media.alt} className="mx-auto mb-7 h-36 w-full max-w-xs rounded-2xl bg-white object-contain shadow-sm" />}
        <p className="text-xs font-black uppercase tracking-[.16em] text-black/45">Room {room}</p><h1 className="mt-3 text-3xl font-black leading-tight tracking-[-.055em] sm:text-5xl">{question.prompt}</h1>
        <div className="mt-7 grid gap-3 sm:grid-cols-2">{question.options.map((option) => <button key={option.id} disabled={Boolean(answerResult) || isPlaying} onClick={() => onAnswer(option.id)} className="rounded-2xl border-2 border-black/10 bg-white px-5 py-4 text-left font-black transition hover:border-[#101314] disabled:cursor-not-allowed disabled:opacity-60">{option.text}</button>)}</div>
        {answerResult && <div className={"mt-6 rounded-2xl p-5 font-bold " + (answerResult.is_correct ? "bg-[#d7ff3f]" : "bg-rose-100 text-rose-950")}><p>{answerResult.is_correct ? `Correct! +${answerResult.points_awarded}` : "Not this one — keep your head in the game."}</p>{question.explanation && <p className="mt-2 text-sm font-medium">{question.explanation}</p>}</div>}
        {error && <p role="alert" className="mt-5 text-sm font-bold text-rose-700">{error}</p>}
      </div>
      {isHost && <button className="button-lime mt-5 w-full" disabled={isPlaying} onClick={onNext}>{isPlaying ? "Loading..." : answerResult ? "Next question" : "Reveal / next question"} <ArrowRight size={17} /></button>}
      {!isHost && <p className="mt-5 text-center text-sm text-white/55">{answerResult ? "Waiting for the host to move on…" : "Choose once — your answer is locked in."}</p>}
    </section></div></main>;
}

function ResultsScreen({ room, players, onHome }: { room: string; players: string[]; onHome: () => void }) {
  return <main className="min-h-screen bg-[#101314] text-white"><div className="mx-auto flex min-h-screen max-w-xl flex-col px-5 pb-10 pt-5 sm:px-8"><Topbar compact onHome={onHome} /><section className="my-auto rounded-[2rem] bg-[#f0eee8] p-8 text-center text-[#101314]"><Trophy className="mx-auto text-[#101314]" size={46} /><p className="mt-6 text-xs font-black uppercase tracking-[.16em] text-black/45">Room {room}</p><h1 className="mt-3 text-5xl font-black tracking-[-.07em]">Game over.</h1><p className="mt-4 text-black/60">The table has spoken. {players.length} player{players.length === 1 ? "" : "s"} made the leaderboard.</p><button className="button-dark mt-7 w-full" onClick={onHome}>Play again <ArrowRight size={17} /></button></section></div></main>;
}

function Topbar({ compact = false, onHome, onCreate, onJoin }: { compact?: boolean; onHome?: () => void; onCreate?: () => void; onJoin?: () => void }) {
  return <header className="relative z-10 flex items-center justify-between"><button className="flex items-center gap-3 text-left" onClick={onHome} aria-label="Return home"><span className="grid h-10 w-10 place-items-center rounded-[.8rem] bg-[#d7ff3f] text-xl font-black text-[#101314]">M</span><span className="font-black tracking-[-.055em]">Game Mavelas</span></button>{!compact && <nav className="flex items-center gap-2"><button className="nav-button" onClick={onJoin}>Join room</button><button className="button-lime small" onClick={onCreate}>Create room</button></nav>}</header>;
}
