import { RegisterForm } from "@/components/auth/RegisterForm";

export default function RegisterPage() {
  return (
    <main className="mx-auto w-full max-w-md flex-1 px-4 py-16 sm:px-6">
      <h1 className="mb-8 text-[32px] font-bold leading-tight">Create your Stockiser account</h1>
      <RegisterForm />
    </main>
  );
}
