import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "@/lib/auth-context";
import { Navbar } from "@/components/layout/Navbar";
import { SignalToaster } from "@/components/layout/SignalToaster";

const geistSans = Geist({ variable: "--font-geist-sans", subsets: ["latin"] });
const geistMono = Geist_Mono({ variable: "--font-geist-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  title: { default: "Algizer — algebraic trading adviser", template: "%s · Algizer" },
  description: "Evalucre Capital's Algizer ranks stocks across global exchanges, tunes an algebraic signal, and streams live buy / sell / hold advice.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col">
        <AuthProvider>
          <Navbar />
          {children}
          <SignalToaster />
          <footer className="border-t border-border py-6 text-center text-xs text-muted-foreground">
            Algizer emits signals only and never places trades. Prices marked “Simulated” are model-generated. Not investment advice.
          </footer>
        </AuthProvider>
      </body>
    </html>
  );
}
