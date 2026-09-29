import { LoginForm } from "@/components/auth/LoginForm";

export default function LoginPage() {
  return (
    <main className="mx-auto w-full max-w-md flex-1 px-4 py-16 sm:px-6">
      <h1 className="mb-6 text-center text-2xl font-semibold">Log in to Tickizer</h1>
      <LoginForm />
    </main>
  );
}
