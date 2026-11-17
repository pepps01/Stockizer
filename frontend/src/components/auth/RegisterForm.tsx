"use client";

import { useState } from "react";
import Link from "next/link";
import { api, ApiError } from "@/lib/api";

export function RegisterForm() {
  const [form, setForm] = useState({ first_name: "", last_name: "", email: "", password: "" });
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<null | "verify" | "ready">(null);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const { user } = await api.register(form);
      setSuccess(user.is_verified ? "ready" : "verify");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong");
    } finally {
      setSubmitting(false);
    }
  };

  if (success === "ready") {
    return (
      <div className="panel p-8 text-center">
        <h2 className="text-lg font-semibold">Your account is ready</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          <Link href="/login" className="font-bold text-foreground underline underline-offset-4">
            Log in
          </Link>{" "}
          with <span className="font-medium">{form.email}</span> to get started.
        </p>
      </div>
    );
  }

  if (success) {
    return (
      <div className="panel p-8 text-center">
        <h2 className="text-lg font-semibold">Check your email</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          We sent a verification link to <span className="font-medium">{form.email}</span>. Click it to activate
          your account, then{" "}
          <Link href="/login" className="font-bold text-foreground underline underline-offset-4">
            log in
          </Link>
          .
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      <div className="grid grid-cols-2 gap-4">
        <Field label="First name">
          <input
            required
            className="input"
            value={form.first_name}
            onChange={(e) => setForm({ ...form, first_name: e.target.value })}
          />
        </Field>
        <Field label="Last name">
          <input
            required
            className="input"
            value={form.last_name}
            onChange={(e) => setForm({ ...form, last_name: e.target.value })}
          />
        </Field>
      </div>
      <Field label="Email">
        <input
          type="email"
          required
          className="input"
          value={form.email}
          onChange={(e) => setForm({ ...form, email: e.target.value })}
        />
      </Field>
      <Field label="Password">
        <input
          type="password"
          required
          minLength={8}
          className="input"
          value={form.password}
          onChange={(e) => setForm({ ...form, password: e.target.value })}
        />
      </Field>

      {error && <p className="text-sm text-loss">{error}</p>}

      <button
        type="submit"
        disabled={submitting}
        className="btn-primary w-full"
      >
        {submitting ? "Creating account…" : "Create account"}
      </button>

      <p className="text-center text-sm text-muted-foreground">
        Already have an account?{" "}
        <Link href="/login" className="font-bold text-foreground underline underline-offset-4">
          Log in
        </Link>
      </p>
    </form>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-bold">{label}</span>
      {children}
    </label>
  );
}
