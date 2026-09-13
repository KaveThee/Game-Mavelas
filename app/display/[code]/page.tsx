"use client";

import { useEffect, useState } from "react";
import { Gamepad2, Trophy, Users, Clock, QrCode } from "lucide-react";
import QRCode from "qrcode";
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
  const [qrDataUrl, setQrDataUrl] = useState<string>("");
  const [timeLeft, setTimeLeft] = useState<number | null>(null);

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

  useEffect(() => {
    if (!round?.duration_seconds) {
      setTimeLeft(null);
      return;
    }
    setTimeLeft(round.duration_seconds);
    const timer = setInterval(() => {
      setTimeLeft((prev) => (prev !== null && prev > 0 ? prev - 1 : 0));
    }, 1000);
    return () => clearInterval(timer);
  }, [round?.position, round?.duration_seconds]);

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
      .on("postgres_changes", { event: "*", schema: "public", table: "game_rounds" }, load)
      .subscribe();
    return () => { void client.removeChannel(channel); };
  }, [code]);

  const title = room?.game_title || gameName[room?.game_mode ?? ""] || "Game Mavelas";
  const isLobby = !room || room.phase === "lobby" || room.phase === "selected" || room.status === "lobby";

  return (
    <main className="min-h-screen bg-[#101314] px-6 py-6 text-white lg:px-14 lg:py-10">
      <div className="mx-auto flex min-h-[calc(100vh-3rem)] max-w-7xl flex-col">
        <header className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <span className="grid h-14 w-14 place-items-center rounded-2xl bg-[#d7ff3f] text-2xl font-black text-[#101314]">
              M
            </span>
            <div>
              <p className="text-2xl font-black tracking-[-.05em]">Game Mavelas</p>
              <p className="text-sm font-bold uppercase tracking-[.14em] text-white/45">Shared screen</p>
            </div>
          </div>
          <div className="flex items-center gap-4">
            {!isLobby && timeLeft !== null && (
              <div className="flex items-center gap-2 rounded-2xl border border-white/10 bg-white/[.05] px-5 py-3 font-mono text-2xl font-black text-[#d7ff3f]">
                <Clock size={22} className="text-[#d7ff3f]" />
                <span>{timeLeft}s</span>
              </div>
            )}
            <div className="rounded-2xl border border-white/10 bg-white/[.05] px-5 py-3 text-right">
              <p className="text-xs font-bold uppercase tracking-[.14em] text-white/45">Room code</p>
              <p className="font-mono text-2xl font-black tracking-[.16em] text-[#d7ff3f]">{code || "----"}</p>
            </div>
          </div>
        </header>

        <section className="my-auto grid items-center gap-10 py-8 lg:grid-cols-[1.2fr_.8fr]">
          <div>
            <p className="text-sm font-black uppercase tracking-[.16em] text-[#d7ff3f]">
              {isLobby ? "Get your phones ready" : `${title}${round ? ` · Round ${round.position}` : ""}`}
            </p>
            <h1 className="mt-4 max-w-4xl whitespace-pre-line text-5xl font-black leading-[.92] tracking-[-.07em] sm:text-7xl lg:text-8xl">
              {isLobby ? "THE TABLE\nIS GATHERING." : round?.prompt || "PLAY\nTOGETHER."}
            </h1>
            {round?.media?.type === "flag" && (
              <img
                src={round.media.url}
                alt={round.media.alt}
                className="mt-8 h-44 w-full max-w-md rounded-3xl bg-white object-contain p-4 shadow-lg"
              />
            )}
            <p className="mt-6 max-w-2xl text-xl leading-8 text-white/60">
              {isLobby
                ? "Scan the QR code or enter the room code on your phone to join. The host will choose the game and start when everyone is in."
                : "Your phone is your controller. Answer there; this screen keeps the room together."}
            </p>

            {isLobby && (
              <div className="mt-8 flex flex-wrap items-center gap-5 rounded-[2rem] border border-white/10 bg-white/[.04] p-5 max-w-xl">
                {qrDataUrl ? (
                  <img
                    src={qrDataUrl}
                    alt="Scan to join room"
                    className="h-28 w-28 rounded-2xl bg-white p-2 shadow-md shrink-0"
                  />
                ) : (
                  <div className="grid h-28 w-28 place-items-center rounded-2xl bg-white/[.08] text-white/40 shrink-0">
                    <QrCode size={36} />
                  </div>
                )}
                <div>
                  <p className="text-xs font-black uppercase tracking-[.16em] text-[#d7ff3f]">Instant Join</p>
                  <p className="mt-1 text-lg font-black">Scan with your phone camera</p>
                  <p className="mt-1 text-sm text-white/60">
                    or enter code <strong className="font-mono text-[#d7ff3f]">{code}</strong> at{" "}
                    <span className="font-mono text-white/80">
                      {typeof window !== "undefined" ? window.location.host : "gamemavelas"}
                    </span>
                  </p>
                </div>
              </div>
            )}
          </div>

          <aside className="rounded-[2.5rem] bg-[#f0eee8] p-7 text-[#101314] shadow-2xl">
            <div className="flex items-center justify-between border-b border-black/10 pb-5">
              <div className="flex items-center gap-3">
                <div className="grid h-12 w-12 place-items-center rounded-2xl bg-[#101314] text-[#d7ff3f]">
                  <Users size={23} />
                </div>
                <div>
                  <p className="text-xs font-black uppercase tracking-[.14em] text-black/45">Live table</p>
                  <p className="text-2xl font-black">{room?.players.length ?? 0} joined</p>
                </div>
              </div>
              <span className="rounded-full bg-black/10 px-3 py-1 font-mono text-xs font-bold">
                {isLobby ? "Lobby" : "In Play"}
              </span>
            </div>
            <div className="mt-6 space-y-2 max-h-[420px] overflow-y-auto pr-1">
              {room?.players.length ? (
                room.players.map((player, index) => (
                  <div
                    className="flex items-center justify-between rounded-2xl bg-black/[.05] px-4 py-3.5 transition"
                    key={player.name + index}
                  >
                    <div className="flex items-center gap-3">
                      <span className="flex h-7 w-7 items-center justify-center rounded-full bg-black text-xs font-bold text-[#d7ff3f]">
                        {index + 1}
                      </span>
                      <span className="font-bold text-[17px]">{player.name}</span>
                    </div>
                    <span className="font-mono font-black text-lg">{player.score} pts</span>
                  </div>
                ))
              ) : (
                <div className="py-12 text-center text-black/40">
                  <p className="font-bold">Waiting for players to join…</p>
                  <p className="text-xs mt-1">Scan the QR code to take the first seat</p>
                </div>
              )}
            </div>
          </aside>
        </section>

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
