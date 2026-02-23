"use client"

import { Suspense, useMemo } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { MailCheck, Loader2 } from "lucide-react"
import { AUTH_ROUTES } from "@/lib/auth-navigation"

function VerifyEmailContent() {
  const searchParams = useSearchParams()
  const router = useRouter()

  const email = useMemo(() => searchParams.get("email") || "your inbox", [searchParams])

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-8 text-center">
        <MailCheck className="mx-auto mb-4 h-12 w-12 text-primary" />
        <h1 className="text-xl font-semibold text-foreground">Check your email</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          We sent a sign-in link to <span className="font-medium text-foreground">{email}</span>.
          Click the link to continue.
        </p>

        <button
          onClick={() => router.push(AUTH_ROUTES.HOME)}
          className="mt-6 w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground hover:brightness-110 transition-all"
        >
          Back to home
        </button>
      </div>
    </div>
  )
}

export default function VerifyEmailPendingPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    }>
      <VerifyEmailContent />
    </Suspense>
  )
}
