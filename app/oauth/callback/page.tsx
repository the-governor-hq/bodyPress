"use client"

import { useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Loader2 } from "lucide-react"

export default function OAuthCallbackPage() {
  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    const connected = searchParams.get("connected")
    const error = searchParams.get("error")

    if (error) {
      // Handle OAuth error
      console.error("[OAuth] Connection error:", error)
      alert(`Failed to connect device: ${error}`)
      router.push("/dashboard")
      return
    }

    if (connected) {
      // Successful connection - always redirect to dashboard
      console.log("[OAuth] Device connected:", connected)
      sessionStorage.removeItem("onboarding_flow")
      router.push("/dashboard")
    } else {
      // No params, just redirect to dashboard
      router.push("/dashboard")
    }
  }, [router, searchParams])

  return (
    <div className="min-h-screen bg-background flex items-center justify-center">
      <div className="text-center">
        <Loader2 className="mx-auto mb-4 h-12 w-12 animate-spin text-primary" />
        <h1 className="text-xl font-semibold">Processing connection...</h1>
        <p className="mt-2 text-sm text-muted-foreground">Please wait a moment</p>
      </div>
    </div>
  )
}
