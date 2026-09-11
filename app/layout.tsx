import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Game Mavelas",
  description: "A live Kenyan-rooted party game for the table.",
  other: {
    "codex-preview": "development",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
