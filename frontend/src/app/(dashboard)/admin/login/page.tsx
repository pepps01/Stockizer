"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { BrandMark } from "@/components/layout/BrandMark";

/** Admin console sign-in (web only). Only admin accounts get through; anyone
 * else is signed straight back out. The API enforces the role regardless. */
export default function AdminLoginPage() {
  const router = useRouter();
  const { user, isLoading, login, logout } = useAuth();
  const [form, setForm] = useState({ email: "", password: "" });
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Already signed in as an admin: go straight to the console.
  useEffect(() => {
    if (!isLoading && user?.is_admin) router.replace("/admin");
  }, [isLoading, user, router]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const signedIn = await login(form.email, form.password);
      if (!signedIn.is_admin) {
        logout();
        setError("This account doesn't have admin access.");
        return;
      }
      router.replace("/admin");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="flex min-h-screen flex-1 items-center justify-center bg-surface-muted px-4 py-16">
      <div className="w-full max-w-sm">
        <div className="mb-8 flex items-center gap-3">
          <BrandMark size={36} />
          <div>
            <p className="text-lg font-bold leading-tight">Stockiser</p>
            <p className="label-caps">Admin console</p>
          </div>
        </div>
        <form onSubmit={submit} className="space-y-5 rounded-2xl bg-surface p-7 shadow-[0_20px_50px_-30px_rgba(16,20,24,0.35)]">
          <div>
            <h1 className="text-2xl font-bold">Sign in</h1>
            <p className="mt-1 text-sm text-muted-foreground">Restricted to Stockiser administrators.</p>
          </div>
          <label className="block">
            <span className="mb-1.5 block text-sm font-bold">Email</span>
            <input
              type="email"
              required
              autoComplete="username"
              className="input"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
            />
          </label>
          <label className="block">
            <span className="mb-1.5 block text-sm font-bold">Password</span>
            <input
              type="password"
              required
              autoComplete="current-password"
              className="input"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
            />
          </label>
          {error && (
            <p role="alert" className="rounded-xl bg-loss-soft px-3 py-2 text-sm text-loss">
              {error}
            </p>
          )}
          <button type="submit" className="btn-primary w-full" disabled={submitting}>
            {submitting ? "Signing in…" : "Sign in to admin"}
          </button>
        </form>
        <p className="mt-6 text-center text-sm text-muted-foreground">
          Not an admin?{" "}
          <Link href="/login" className="font-bold text-foreground underline underline-offset-4">
            Investor login
          </Link>
        </p>
      </div>
    </main>
  );
}
