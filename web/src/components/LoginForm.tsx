"use client";

import { useState } from "react";
import { signInWithEmailAndPassword } from "firebase/auth";
import { auth } from "@/lib/firebase";

export default function LoginForm() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch {
      setError("メールアドレスまたはパスワードが違います");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="login">
      <div className="login-card">
        <div className="brand">
          <div className="brand-badge">🎧</div>
          <h1>HowTune</h1>
          <p>自分の聴き方を振り返る</p>
        </div>

        <form onSubmit={onSubmit}>
          <div>
            <label htmlFor="email">メールアドレス</label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div>
            <label htmlFor="password">パスワード</label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          {error && <p className="error">{error}</p>}

          <button className="primary" type="submit" disabled={busy}>
            {busy ? "ログイン中…" : "ログイン"}
          </button>
        </form>

        <p
          className="faint"
          style={{ fontSize: 12, marginTop: 18, textAlign: "center" }}
        >
          iOS アプリと同じアカウントでログインできます
        </p>
      </div>
    </main>
  );
}
