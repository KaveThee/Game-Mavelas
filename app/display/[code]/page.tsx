"use client";

import { useEffect, useState } from "react";
import { Gamepad2, Trophy, Users } from "lucide-react";
import { ensureGameIdentity, supabase } from "@/lib/supabase";

type PublicRoom = {
  room_code: string;
  status: string;
  phase: string;
  game_mode: string;
  game_title?: string | null;
  state_version: number;
  players: { name: string; score: number; seat?: number | null }[];
};

type PublicRound = {
  position: number;
  game_mode: string;
  duration_seconds: number;
  prompt: string;
  media?: { type: string; url: string; alt: string } | null;
};

const gameName: Record<string, string> = {
  who_am_i: "Who Am I?",
  flag_frenzy: "Flag Frenzy",
  trivia: "Trivia Rush",
  guess_image: "Guess the Image",
};

export default function SharedDisplay({ params }: { params: Promise<{ code: string }> }) {
  const [code, setCode] = useState("");
  const [room, setRoom] = useState<PublicRoom | null>(null);
  const [round, setRound] = useState<PublicRound | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    void params.then(({ code: roomCode }) => setCode(roomCode.toUpperCase()));
  }, [params]);

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
        setRound(roundData as PublicRound | null);
        setError("");
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : "Could not load this room.");
      }
    };
    void load();
    const channel = client
      .channel("display-" + code)
      .on("postgres_changes", { event: "*", schema: "public", table: "rooms" }, load)
      .on("postgres_changes", { event: "*", schema: "public", table: "room_players" }, load)
      .subscribe();
    return () => { void client.removeChannel(channel); };
  }, [code]);

  const title = room?.game_title || gameName[room?.game_mode ?? ""] || "Game Mavelas";
  const isLobby = !room || room.phase === "lobby" || room.phase === "selected";

  return <main className="min-h-screen bg-[#101314] px-8 py-8 text-white lg:px-14 lg:py-12">
    <div className="mx-auto flex min-h-[calc(100vh-4rem)] max-w-7xl flex-col">
      <header className="flex items-center justify-between"><div className="flex items-center gap-4"><span className="grid h-14 w-14 place-items-center rounded-2xl bg-[#d7ff3f] text-2xl font-black text-[#101314]">M</span><div><p className="text-2xl font-black tracking-[-.05em]">Game Mavelas</p><p className="text-sm font-bold uppercase tracking-[.14em] text-white/45">Shared screen</p></div></div><div className="rounded-2xl border border-white/10 bg-white/[.05] px-5 py-3 text-right"><p className="text-xs font-bold uppercase tracking-[.14em] text-white/45">Room code</p><p className="font-mono text-2xl font-black tracking-[.16em] text-[#d7ff3f]">{code || "----"}</p></div></header>
      <section className="my-auto grid items-center gap-10 py-12 lg:grid-cols-[1.2fr_.8fr]">
        <div><p className="text-sm font-black uppercase tracking-[.16em] text-[#d7ff3f]">{isLobby ? "Get your phones ready" : `${title}${round ? ` · Round ${round.position}` : ""}`}</p><h1 className="mt-5 max-w-4xl whitespace-pre-line text-6xl font-black leading-[.86] tracking-[-.08em] sm:text-7xl lg:text-8xl">{isLobby ? "THE TABLE\nIS GATHERING." : round?.prompt || "PLAY\nTOGETHER."}</h1>{round?.media?.type === "flag" && <img src={round.media.url} alt={round.media.alt} className="mt-8 h-40 w-full max-w-md rounded-3xl bg-white object-contain p-4" />}<p className="mt-7 max-w-2xl text-xl leading-8 text-white/60">{isLobby ? "Join with the room code on your phone. The host will choose the game and start when everyone is ready." : "Your phone is your controller. Answer there; this screen keeps the room together."}</p></div>
        <aside className="rounded-[2rem] bg-[#f0eee8] p-7 text-[#101314]"><div className="flex items-center gap-3"><div className="grid h-12 w-12 place-items-center rounded-2xl bg-[#101314] text-[#d7ff3f]"><Users size={23} /></div><div><p className="text-xs font-black uppercase tracking-[.14em] text-black/45">Live table</p><p className="text-2xl font-black">{room?.players.length ?? 0} players joined</p></div></div><div className="mt-6 space-y-2">{room?.players.slice(0, 8).map((player, index) => <div className="flex items-center justify-between rounded-xl bg-black/[.05] px-4 py-3" key={player.name + index}><span className="font-bold">{player.name}</span><span className="font-mono font-black">{player.score}</span></div>)}</div></aside>
      </section>
      <footer className="flex items-center justify-between border-t border-white/10 pt-6 text-sm font-bold text-white/45"><span className="flex items-center gap-2"><Gamepad2 size={18} /> Keep your phone open</span><span className="flex items-center gap-2"><Trophy size={18} /> {room?.state_version ? `Live update ${room.state_version}` : "Waiting for host"}</span></footer>
      {error && <p role="alert" className="mt-4 text-center text-sm font-bold text-rose-300">{error}</p>}
    </div>
  </main>;
}
