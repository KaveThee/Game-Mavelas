import { GameController } from "@/app/page";

export default async function HostControllerPage({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  return <GameController hostCode={code.toUpperCase()} />;
}
