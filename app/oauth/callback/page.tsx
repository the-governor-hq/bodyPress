"use client"

import { Suspense, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Loader2 } from "lucide-react"
import { AUTH_ROUTES } from "@/lib/auth-navigation"
import { toast } from "@/hooks/use-toast"

function OAuthCallbackContent() {
  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    const connected = searchParams.get("connected")
    const error = searchParams.get("error")
    const provider = searchParams.get("provider")

    if (error) {
      // Handle OAuth error
      console.error("[OAuth] Connection error:", error)
      const providerName = provider ? provider.charAt(0).toUpperCase() + provider.slice(1) : "device"
      
      toast({
        title: "Connection Failed",
        description: `Failed to connect ${providerName}. ${error}`,
        variant: "destructive",
        duration: 5000,
      })
      
      router.push(AUTH_ROUTES.DASHBOARD)
      return
    }

    if (connected) {
      // Successful connection - always redirect to dashboard with refresh flag
      console.log("[OAuth] Device connected:", connected)
      sessionStorage.removeItem("onboarding_flow")
      
      toast({
        title: "Device Connected",
        description: "Your device has been successfully connected!",
        duration: 3000,
      })
      
      // Force refresh to get latest connection status
      router.push(`${AUTH_ROUTES.DASHBOARD}?refresh=1`)
    } else {
      // No params, just redirect to dashboard
      router.push(AUTH_ROUTES.DASHBOARD)
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

export default function OAuthCallbackPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="mx-auto mb-4 h-12 w-12 animate-spin text-primary" />
          <h1 className="text-xl font-semibold">Processing connection...</h1>
          <p className="mt-2 text-sm text-muted-foreground">Please wait a moment</p>
        </div>
      </div>
    }>
      <OAuthCallbackContent />
    </Suspense>
  )
}
