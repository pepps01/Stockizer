"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { api, ApiError } from "@/lib/api";

export default function ProfilePage() {
  const router = useRouter();
  const { user, token, isLoading, refreshUser } = useAuth();
  const [form, setForm] = useState({ first_name: "", last_name: "" });
  const [status, setStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!isLoading && !user) router.push("/login");
  }, [isLoading, user, router]);

  useEffect(() => {
    if (user) setForm({ first_name: user.first_name, last_name: user.last_name });
  }, [user]);

  if (isLoading || !user || !token) {
    return (
      <main className="mx-auto w-full max-w-md flex-1 px-4 py-16 sm:px-6">
        <p className="text-center text-sm text-muted-foreground">Loading…</p>
      </main>
    );
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("saving");
    setError(null);
    try {
      await api.updateMe(token, form);
      await refreshUser();
      setStatus("saved");
    } catch (err) {
      setStatus("error");
      setError(err instanceof ApiError ? err.message : "Failed to save changes");
    }
  };

  return (
    <main className="mx-auto w-full max-w-md flex-1 px-4 py-16 sm:px-6">
      <h1 className="mb-6 text-center text-2xl font-semibold">Your profile</h1>
      <form onSubmit={handleSubmit} className="rounded-xl border border-border bg-surface p-6 space-y-4">
        <label className="block">
          <span className="mb-1.5 block text-sm font-medium">First name</span>
          <input
            required
            className="input"
            value={form.first_name}
            onChange={(e) => setForm({ ...form, first_name: e.target.value })}
          />
        </label>
        <label className="block">
          <span className="mb-1.5 block text-sm font-medium">Last name</span>
          <input
            required
            className="input"
            value={form.last_name}
            onChange={(e) => setForm({ ...form, last_name: e.target.value })}
          />
        </label>
        <label className="block">
          <span className="mb-1.5 block text-sm font-medium">Email</span>
          <input className="input opacity-60" value={user.email} disabled />
        </label>

        {error && <p className="text-sm text-loss">{error}</p>}
        {status === "saved" && <p className="text-sm text-gain">Profile updated.</p>}

        <button
          type="submit"
          disabled={status === "saving"}
          className="w-full rounded-lg bg-brand py-2.5 text-sm font-medium text-brand-foreground hover:opacity-90 disabled:opacity-50"
        >
          {status === "saving" ? "Saving…" : "Save changes"}
        </button>
      </form>
    </main>
  );
}
