"use client"

import { Suspense, useEffect, useState } from "react"
import { useSearchParams, useRouter } from "next/navigation"
import { CheckCircle2, XCircle, Loader2, WifiOff } from "lucide-react"
import { verifyMagicLink, updateProfile, ApiError, getUserFriendlyErrorMessage, isNetworkError } from "@/lib/api"
import { setToken, getOnboardingData, clearOnboardingData, markKnownEmail } from "@/lib/auth"
import { AUTH_ROUTES } from "@/lib/auth-navigation"
import { useNetworkStatus } from "@/hooks/use-network-status"
import { toast } from "@/hooks/use-toast"

type State = "verifying" | "success" | "error" | "network-error"

const VERIFY_INFLIGHT_PREFIX = "bp_verify_inflight_"
const VERIFY_DONE_PREFIX = "bp_verify_done_"
const VERIFY_DEST_PREFIX = "bp_verify_dest_"

function VerifyContent() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const { isOnline } = useNetworkStatus()
  const [state, setState] = useState<State>("verifying")
  const [message, setMessage] = useState("")
  const [token, setTokenState] = useState<string | null>(null)

  useEffect(() => {
    const verifyToken = searchParams.get("token")
    if (!verifyToken) {
      setState("error")
      setMessage("Missing verification token.")
      return
    }

    setTokenState(verifyToken)

    const inflightKey = `${VERIFY_INFLIGHT_PREFIX}${verifyToken}`
    const doneKey = `${VERIFY_DONE_PREFIX}${verifyToken}`
    const destinationKey = `${VERIFY_DEST_PREFIX}${verifyToken}`

    if (sessionStorage.getItem(doneKey) === "true") {
      const destination = sessionStorage.getItem(destinationKey) || AUTH_ROUTES.DASHBOARD
      setState("success")
      setTimeout(() => {
        clearOnboardingData()
        router.replace(destination)
      }, 150)
      return
    }

    if (sessionStorage.getItem(inflightKey) === "true") {
      return
    }

    sessionStorage.setItem(inflightKey, "true")

    verifyMagicLink(verifyToken)
      .then(async (res) => {
        setToken(res.token)
        markKnownEmail(res.user.email)

        // Flush any saved onboarding preferences
        const saved = getOnboardingData()
        if (saved.name || saved.goals?.length || saved.timezone) {
          try {
            await updateProfile({
              name: saved.name || undefined,
              goals: saved.goals,
              timezone: saved.timezone || undefined,
            })
          } catch (err) {
            // Non-blocking - log but continue
            console.warn("[Verify] Failed to update profile:", err)
          }
        }

        setState("success")
        setMessage("")

        const destination = AUTH_ROUTES.DASHBOARD
        sessionStorage.setItem(doneKey, "true")
        sessionStorage.setItem(destinationKey, destination)
        
        toast({
          title: "Welcome back!",
          description: "You've been signed in successfully.",
          duration: 3000,
        })
        
        setTimeout(() => {
          clearOnboardingData()
          router.replace(destination)
        }, 1500)
      })
      .catch((err) => {
        const alreadyDone = sessionStorage.getItem(doneKey) === "true"
        if (alreadyDone) {
          console.warn("[Verify] Ignoring stale verify error after successful verification")
          return
        }

        sessionStorage.removeItem(doneKey)
        sessionStorage.removeItem(destinationKey)
        
        const errorMsg = getUserFriendlyErrorMessage(err)
        const isNetworkErr = isNetworkError(err)
        
        setState(isNetworkErr ? "network-error" : "error")
        setMessage(errorMsg)
        
        if (isNetworkErr) {
          toast({
            title: "Connection Error",
            description: "Unable to verify your sign-in link. Please check your connection and try again.",
            variant: "destructive",
            duration: 5000,
          })
        }
      })
      .finally(() => {
        sessionStorage.removeItem(inflightKey)
      })
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const handleRetry = () => {
    if (token) {
      sessionStorage.removeItem(`${VERIFY_DONE_PREFIX}${token}`)
      sessionStorage.removeItem(`${VERIFY_DEST_PREFIX}${token}`)
      router.refresh()
    }
  }

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

        {state === "network-error" && (
          <>
            <WifiOff className="mx-auto mb-4 h-12 w-12 text-destructive" />
            <h1 className="text-xl font-semibold text-foreground">Connection Error</h1>
            <p className="mt-2 text-sm text-muted-foreground">{message}</p>
            {!isOnline && (
              <p className="mt-2 text-sm text-muted-foreground font-medium">
                You're currently offline. Please check your internet connection.
              </p>
            )}
            <div className="flex flex-col gap-2 mt-6">
              <button
                onClick={handleRetry}
                disabled={!isOnline}
                className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isOnline ? "Retry" : "Waiting for connection..."}
              </button>
              <button
                onClick={() => router.push(AUTH_ROUTES.HOME)}
                className="w-full rounded-lg border border-border px-4 py-2.5 text-sm font-medium text-foreground hover:bg-accent transition-all"
              >
                Back to home
              </button>
            </div>
          </>
        )}

        {state === "error" && (
          <>
            <XCircle className="mx-auto mb-4 h-12 w-12 text-destructive" />
            <h1 className="text-xl font-semibold text-foreground">Link invalid</h1>
            <p className="mt-2 text-sm text-muted-foreground">{message}</p>
            <button
              onClick={() => router.push(AUTH_ROUTES.HOME)}
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

export default function VerifyPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    }>
      <VerifyContent />
    </Suspense>
  )
}
