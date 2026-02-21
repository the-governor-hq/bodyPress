"use client"

import { useEffect, useState } from "react"
import { useSearchParams, useRouter } from "next/navigation"
import { CheckCircle2, XCircle, Loader2 } from "lucide-react"
import { verifyMagicLink, updateProfile, ApiError } from "@/lib/api"
import { setToken, getOnboardingData, clearOnboardingData } from "@/lib/auth"

type State = "verifying" | "success" | "error"

export default function VerifyPage() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const [state, setState] = useState<State>("verifying")
  const [message, setMessage] = useState("")

  useEffect(() => {
    const token = searchParams.get("token")
    if (!token) {
      setState("error")
      setMessage("Missing verification token.")
      return
    }

    verifyMagicLink(token)
      .then(async (res) => {
        setToken(res.token)

        // Flush any saved onboarding preferences
        const saved = getOnboardingData()
        if (saved.name || saved.goals?.length || saved.timezone) {
          try {
            await updateProfile({
              name: saved.name || undefined,
              goals: saved.goals,
              timezone: saved.timezone || undefined,
            })
          } catch {
            // Non-blocking
          }
        }

        setState("success")

        // If onboarding is not done, go back to onboarding connect step
        const destination = res.user.onboardingDone ? "/dashboard" : "/onboarding"
        setTimeout(() => {
          clearOnboardingData()
          router.replace(destination)
        }, 1500)
      })
      .catch((err) => {
        setState("error")
        setMessage(
          err instanceof ApiError
            ? err.message
            : "Verification failed. The link may have expired.",
        )
      })
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-8 text-center">
        {state === "verifying" && (
          <>
            <Loader2 className="mx-auto mb-4 h-12 w-12 animate-spin text-primary" />
            <h1 className="text-xl font-semibold">Verifying your link…</h1>
          </>
        )}

        {state === "success" && (
          <>
            <CheckCircle2 className="mx-auto mb-4 h-12 w-12 text-primary" />
            <h1 className="text-xl font-semibold text-foreground">You're in!</h1>
            <p className="mt-2 text-sm text-muted-foreground">Redirecting you now…</p>
          </>
        )}

        {state === "error" && (
          <>
            <XCircle className="mx-auto mb-4 h-12 w-12 text-destructive" />
            <h1 className="text-xl font-semibold text-foreground">Link invalid</h1>
            <p className="mt-2 text-sm text-muted-foreground">{message}</p>
            <button
              onClick={() => router.push("/")}
              className="mt-6 w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground hover:brightness-110 transition-all"
            >
              Back to home
            </button>
          </>
        )}
      </div>
    </div>
  )
}
