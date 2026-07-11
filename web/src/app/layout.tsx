import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "HowTune Dashboard",
  description: "自分の聴き方（How カード）を振り返る",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
