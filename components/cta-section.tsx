"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { ArrowRight } from "lucide-react"
import { subscribe, requestMagicLink, ApiError } from "@/lib/api"
import { isKnownEmail, setPendingEmail } from "@/lib/auth"
import { useSessionStore } from "@/lib/session-store"

export function CtaSection() {
  const router = useRouter()
  const setSessionPendingEmail = useSessionStore((state) => state.setPendingEmail)
  const [email, setEmail] = useState("")
  const [submitted, setSubmitted] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email || loading) return
    const normalizedEmail = email.trim().toLowerCase()
    setLoading(true)
    setError(null)
    try {
      setPendingEmail(normalizedEmail)
      setSessionPendingEmail(normalizedEmail)
      sessionStorage.removeItem("onboarding_subscribe_sent")
      sessionStorage.removeItem("onboarding_subscribe_state")

      if (isKnownEmail(normalizedEmail)) {
        await requestMagicLink({ email: normalizedEmail })
        setSubmitted(true)
        setTimeout(() => router.push(`/auth/verify-email?email=${encodeURIComponent(normalizedEmail)}&mode=signin`), 1200)
        return
      }

      const response = await subscribe({ email: normalizedEmail })
      setSubmitted(true)

      setTimeout(() => {
        router.push(
          response.isNew
            ? "/onboarding"
            : `/auth/verify-email?email=${encodeURIComponent(normalizedEmail)}&mode=verify`,
        )
      }, 1200)
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : "Something went wrong. Try again."
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <section className="px-4 py-16 sm:px-6 sm:py-20">
      <div className="mx-auto max-w-2xl rounded-xl sm:rounded-2xl border border-border bg-card p-6 sm:p-10 text-center md:p-14">
        <h2 className="text-balance text-2xl sm:text-3xl font-bold tracking-tight text-foreground md:text-4xl">
          Start reading your body
        </h2>
        <p className="mx-auto mt-3 sm:mt-4 max-w-md text-sm sm:text-base text-pretty leading-relaxed text-muted-foreground">
          Join thousands of health-conscious people who start their morning
          with BodyPress.
        </p>

        {!submitted ? (
          <>
            <form
              onSubmit={handleSubmit}
              className="mx-auto mt-6 sm:mt-8 flex max-w-sm flex-col gap-3 sm:flex-row"
            >
              <label htmlFor="cta-email" className="sr-only">
                Email address
              </label>
              <input
                id="cta-email"
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@email.com"
                disabled={loading}
                className="flex-1 rounded-lg border border-border bg-secondary px-4 py-3 text-sm text-foreground placeholder:text-muted-foreground focus:border-primary focus:ring-1 focus:ring-primary focus:outline-none disabled:opacity-50"
              />
              <button
                type="submit"
                disabled={loading}
                className="group inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground transition-all hover:brightness-110 disabled:opacity-60"
              >
                {loading ? "Subscribing…" : "Subscribe"}
                {!loading && <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />}
              </button>
            </form>
            {error && (
              <p className="mt-2 text-xs text-destructive">{error}</p>
            )}
          </>
        ) : (
          <div className="mx-auto mt-6 sm:mt-8 max-w-sm rounded-lg border border-primary/30 bg-primary/10 px-6 py-4">
            <p className="text-sm font-medium text-primary">
              Welcome aboard. Your first briefing is on its way.
            </p>
          </div>
        )}

        <p className="mt-3 sm:mt-4 text-xs text-muted-foreground">
          Unsubscribe anytime.
        </p>
      </div>
    </section>
  )
}
