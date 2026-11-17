import type { Metadata } from "next";
import { Lato } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "@/lib/auth-context";
import { Sidebar } from "@/components/layout/Sidebar";
import { SignalToaster } from "@/components/layout/SignalToaster";
import { AppFooter } from "@/components/layout/AppFooter";
import { THEME_BOOT_SCRIPT } from "@/lib/theme-boot";

// Lato is the house typeface (static font, so the weights are listed).
const lato = Lato({ variable: "--font-lato", weight: ["300", "400", "700", "900"], subsets: ["latin"] });

export const metadata: Metadata = {
  title: { default: "Stockiser — signals, not noise", template: "%s · Stockiser" },
  description: "Stockiser ranks stocks across global exchanges, tunes an algebraic signal on their history, and streams live buy / sell / hold advice.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    // The boot script sets data-theme before React hydrates, so the attribute differs from the server's.
    <html lang="en" className={`${lato.variable} h-full antialiased`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_BOOT_SCRIPT }} />
      </head>
      <body className="min-h-full">
        <AuthProvider>
          <div className="flex min-h-screen flex-col lg:flex-row">
            <Sidebar />
            <div className="flex min-w-0 flex-1 flex-col">
              {children}
              <AppFooter />
            </div>
          </div>
          <SignalToaster />
        </AuthProvider>
      </body>
    </html>
  );
}
