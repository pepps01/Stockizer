"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { api, ApiError } from "@/lib/api";

function VerifyEmailContent() {
  const searchParams = useSearchParams();
  const token = searchParams.get("token");
  const [status, setStatus] = useState<"loading" | "success" | "error">("loading");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) {
      setStatus("error");
      setError("Missing verification token.");
      return;
    }
    api
      .verifyEmail(token)
      .then(() => setStatus("success"))
      .catch((err) => {
        setStatus("error");
        setError(err instanceof ApiError ? err.message : "Verification failed.");
      });
  }, [token]);

  return (
    <div className="rounded-xl border border-border bg-surface p-6 text-center">
      {status === "loading" && <p className="text-sm text-muted-foreground">Verifying your email…</p>}
      {status === "success" && (
        <>
          <h2 className="text-lg font-semibold text-gain">Email verified</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Your account is active.{" "}
            <Link href="/login" className="text-brand hover:underline">
              Log in
            </Link>{" "}
            to continue.
          </p>
        </>
      )}
      {status === "error" && (
        <>
          <h2 className="text-lg font-semibold text-loss">Verification failed</h2>
          <p className="mt-2 text-sm text-muted-foreground">{error}</p>
        </>
      )}
    </div>
  );
}

export default function VerifyEmailPage() {
  return (
    <main className="mx-auto w-full max-w-md flex-1 px-4 py-16 sm:px-6">
      <h1 className="mb-6 text-center text-2xl font-semibold">Verify your email</h1>
      <Suspense fallback={<p className="text-center text-sm text-muted-foreground">Loading…</p>}>
        <VerifyEmailContent />
      </Suspense>
    </main>
  );
}
