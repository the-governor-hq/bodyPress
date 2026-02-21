"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { ArrowRight, Activity, Loader2, LogOut, Unplug } from "lucide-react"
import {
  clearPendingEmail,
  clearToken,
  getPendingEmail,
  isAuthenticated,
  setPendingEmail,
} from "@/lib/auth"
import { useSessionStore } from "@/lib/session-store"
import { ApiError, Connection, disconnectDevice, getConnections, getMe } from "@/lib/api"

export function Hero() {
  const router = useRouter()
  const hasHydrated = useSessionStore((state) => state.hasHydrated)
  const sessionPendingEmail = useSessionStore((state) => state.pendingEmail)
  const setSessionPendingEmail = useSessionStore((state) => state.setPendingEmail)
  const clearSessionPendingEmail = useSessionStore((state) => state.clearPendingEmail)
  const [email, setEmail] = useState("")
  const [submitted, setSubmitted] = useState(false)
  const [loadingStatus, setLoadingStatus] = useState(true)
  const [isAuthed, setIsAuthed] = useState(false)
  const [connections, setConnections] = useState<Connection[]>([])
  const [disconnecting, setDisconnecting] = useState<"garmin" | "fitbit" | null>(null)

  useEffect(() => {
    if (!hasHydrated) return

    const hydrateSession = async () => {
      const persistedEmail = sessionPendingEmail ?? getPendingEmail()
      if (persistedEmail) {
        setEmail(persistedEmail)
      }

      if (!isAuthenticated()) {
        setIsAuthed(false)
        setConnections([])
        setLoadingStatus(false)
        return
      }

      try {
        const [me, connectionResponse] = await Promise.all([getMe(), getConnections()])
        setIsAuthed(true)
        setConnections(connectionResponse.connections)

        if (me.email) {
          setEmail(me.email)
          setPendingEmail(me.email)
          setSessionPendingEmail(me.email)
        }
      } catch (err) {
        if (err instanceof ApiError && err.status === 401) {
          clearToken()
        }
        setIsAuthed(false)
        setConnections([])
      } finally {
        setLoadingStatus(false)
      }
    }

    void hydrateSession()
  }, [hasHydrated, sessionPendingEmail, setSessionPendingEmail])

  const handleSignOut = () => {
    clearToken()
    clearPendingEmail()
    clearSessionPendingEmail()
    setIsAuthed(false)
    setConnections([])
    setSubmitted(false)
  }

  const handleDisconnect = async (provider: "garmin" | "fitbit") => {
    try {
      setDisconnecting(provider)
      await disconnectDevice(provider)
      const refreshed = await getConnections()
      setConnections(refreshed.connections)
    } catch (err) {
      console.error("[Hero] Failed to disconnect provider", provider, err)
    } finally {
      setDisconnecting(null)
    }
  }

  const connectedProviders = connections.filter(
    (conn) =>
      conn.status === "connected" &&
      (conn.provider.toLowerCase() === "garmin" || conn.provider.toLowerCase() === "fitbit"),
  )

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (email) {
      // Store email for onboarding subscribe/verification flow
      setPendingEmail(email)
      setSessionPendingEmail(email)
      // Reset per-session subscribe guard for a fresh onboarding attempt
      sessionStorage.removeItem("onboarding_subscribe_sent")
      sessionStorage.removeItem("onboarding_subscribe_state")
      // Redirect to onboarding
      router.push("/onboarding")
    }
  }

  return (
    <section className="relative flex min-h-[90vh] flex-col items-center justify-center px-4 pt-24 pb-20 text-center sm:px-6">
      {/* Ambient glow */}
      <div
        className="pointer-events-none absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2"
        aria-hidden="true"
      >
        <div className="h-[300px] w-[400px] sm:h-[500px] sm:w-[700px] rounded-full bg-primary/8 blur-[120px]" />
      </div>

      <div className="relative z-10 mx-auto max-w-3xl">
        {/* Pill badge */}
        <div className="mb-6 sm:mb-8 inline-flex items-center gap-2 rounded-full border border-border bg-secondary px-3 py-1.5 sm:px-4">
          <Activity className="h-3 w-3 sm:h-3.5 sm:w-3.5 text-primary" />
          <span className="font-mono text-[10px] sm:text-xs tracking-wider text-muted-foreground uppercase">
            AI-Powered Health Briefings
          </span>
        </div>

        <h1 className="text-balance text-4xl leading-[1.1] font-bold tracking-tight text-foreground sm:text-5xl md:text-7xl">
          Your Body,{" "}
          <span className="text-primary">Briefed</span> Daily
        </h1>

        <p className="mx-auto mt-4 sm:mt-6 max-w-xl text-pretty text-base leading-relaxed text-muted-foreground sm:text-lg md:text-xl">
          We turn your wearable data into a personalized morning briefing.
          Sleep score, HRV, heart rate — contextualized with weather, air
          quality, and UV index using AI agents.
        </p>

        {loadingStatus ? (
          <div className="mx-auto mt-6 flex max-w-md items-center justify-center gap-2 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" />
            Checking session…
          </div>
        ) : isAuthed ? (
          <div className="mx-auto mt-6 max-w-md rounded-lg border border-primary/30 bg-primary/10 p-4 text-left">
            <p className="text-sm font-semibold text-primary">Already signed in on this browser</p>
            <p className="mt-1 text-xs text-muted-foreground">{email || "Authenticated user"}</p>

            <div className="mt-3 space-y-2">
              {connectedProviders.length > 0 ? (
                connectedProviders.map((connection) => {
                  const provider = connection.provider.toLowerCase() as "garmin" | "fitbit"
                  return (
                    <div
                      key={connection.provider}
                      className="flex items-center justify-between rounded-md border border-border bg-background px-3 py-2"
                    >
                      <span className="text-sm text-foreground capitalize">{provider} connected</span>
                      <button
                        onClick={() => handleDisconnect(provider)}
                        disabled={disconnecting === provider}
                        className="inline-flex items-center gap-1 text-xs text-destructive hover:underline disabled:opacity-60"
                      >
                        {disconnecting === provider ? (
                          <Loader2 className="h-3.5 w-3.5 animate-spin" />
                        ) : (
                          <Unplug className="h-3.5 w-3.5" />
                        )}
                        Disconnect
                      </button>
                    </div>
                  )
                })
              ) : (
                <p className="text-xs text-muted-foreground">No wearable connected yet.</p>
              )}
            </div>

            <div className="mt-3 flex items-center justify-between">
              <button
                onClick={() => router.push("/dashboard")}
                className="text-xs font-medium text-primary hover:underline"
              >
                Open dashboard
              </button>
              <button
                onClick={handleSignOut}
                className="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
              >
                <LogOut className="h-3.5 w-3.5" />
                Sign out
              </button>
            </div>
          </div>
        ) : null}

        {/* Email form */}
        {!submitted && !isAuthed ? (
          <form
            onSubmit={handleSubmit}
            className="mx-auto mt-8 sm:mt-10 flex max-w-md flex-col gap-3 sm:flex-row"
          >
            <label htmlFor="hero-email" className="sr-only">
              Email address
            </label>
            <input
              id="hero-email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@email.com"
              className="flex-1 rounded-lg border border-border bg-secondary px-4 py-3 text-sm text-foreground placeholder:text-muted-foreground focus:border-primary focus:ring-1 focus:ring-primary focus:outline-none"
            />
            <button
              type="submit"
              className="group inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground transition-all hover:brightness-110"
            >
              Get the Briefing
              <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
            </button>
          </form>
        ) : !isAuthed ? (
          <div className="mx-auto mt-8 sm:mt-10 max-w-md rounded-lg border border-primary/30 bg-primary/10 px-6 py-4">
            <p className="text-sm font-medium text-primary">
              You{"'"}re in. Check your inbox for your first briefing.
            </p>
          </div>
        ) : null}

        <p className="mt-3 sm:mt-4 text-xs text-muted-foreground">
          Free forever. One email per day. Unsubscribe anytime.
        </p>
      </div>
    </section>
  )
}
