"use client"

import { useState, useEffect } from "react"
import { Watch, Activity, Heart, Clock, TrendingUp, Shield, Mail } from "lucide-react"
import { motion } from "framer-motion"
import { isAuthenticated, getPendingEmail, getOnboardingData } from "@/lib/auth"
import { ApiError, getOAuthConnectUrl, requestMagicLink, subscribe } from "@/lib/api"
import { useSessionStore } from "@/lib/session-store"

interface ConnectDeviceStepProps {
  formData: { device: string }
  updateFormData: (data: { device: string }) => void
  onNext?: () => void
  onBack?: () => void
  isLastStep?: boolean
}

const DEVICES = [
  {
    id: "garmin",
    name: "Garmin",
    icon: "/devices/garmin.svg",
    available: true,
    color: "from-blue-500 to-cyan-500",
  },
  {
    id: "fitbit",
    name: "Fitbit",
    icon: "/devices/fitbit.svg",
    available: true,
    color: "from-teal-500 to-green-500",
  },
  {
    id: "apple",
    name: "Apple Watch",
    icon: "/devices/apple.svg",
    available: false,
    color: "from-gray-700 to-gray-900",
  },
  {
    id: "whoop",
    name: "WHOOP",
    icon: "/devices/whoop.svg",
    available: false,
    color: "from-red-500 to-pink-500",
  },
  {
    id: "oura",
    name: "Oura Ring",
    icon: "/devices/oura.svg",
    available: false,
    color: "from-purple-500 to-indigo-500",
  },
  {
    id: "polar",
    name: "Polar",
    icon: "/devices/polar.svg",
    available: false,
    color: "from-red-600 to-orange-500",
  },
]

const METRICS = [
  { icon: Heart, label: "Heart Rate" },
  { icon: Activity, label: "Activity" },
  { icon: Clock, label: "Sleep Tracking" },
  { icon: TrendingUp, label: "Performance" },
]

export function ConnectDeviceStep({ formData, updateFormData }: ConnectDeviceStepProps) {
  const [selectedDevice, setSelectedDevice] = useState(formData.device)
  const [isConnecting, setIsConnecting] = useState(false)
  const authed = isAuthenticated()
  const sessionPendingEmail = useSessionStore((state) => state.pendingEmail)
  const hasHydrated = useSessionStore((state) => state.hasHydrated)

  useEffect(() => {
    if (!hasHydrated) return

    const sendVerificationEmail = async () => {
      const sendState = sessionStorage.getItem("onboarding_subscribe_state")
      if (sendState === "pending") {
        console.log("[ConnectDeviceStep] Skipping subscribe: request already in-flight")
        return
      }

      if (sendState === "done") {
        console.log("[ConnectDeviceStep] Skipping subscribe: request already completed")
        sessionStorage.setItem("onboarding_subscribe_sent", "true")
        return
      }

      const alreadySent = sessionStorage.getItem("onboarding_subscribe_sent") === "true"
      if (alreadySent) {
        console.log("[ConnectDeviceStep] Skipping subscribe: already sent in this session")
        sessionStorage.setItem("onboarding_subscribe_state", "done")
        return
      }

      if (authed) {
        console.log("[ConnectDeviceStep] Skipping subscribe: already authenticated")
        return
      }

      const email = sessionPendingEmail ?? getPendingEmail()
      if (!email) {
        console.warn("[ConnectDeviceStep] Cannot subscribe: missing pending email in localStorage (bp_email)")
        return
      }

      const onboardingData = getOnboardingData()
      sessionStorage.setItem("onboarding_subscribe_state", "pending")

      try {
        console.log("[ConnectDeviceStep] Calling POST /v1/subscribers", {
          email,
          name: onboardingData.name,
          timezone: onboardingData.timezone,
          goals: onboardingData.goals,
        })

        await subscribe({
          email,
          name: onboardingData.name || undefined,
          timezone: onboardingData.timezone || undefined,
          goals: onboardingData.goals,
        })

        sessionStorage.setItem("onboarding_subscribe_sent", "true")
        sessionStorage.setItem("onboarding_subscribe_state", "done")
        console.log("[ConnectDeviceStep] POST /v1/subscribers succeeded")
      } catch (error) {
        console.warn("[ConnectDeviceStep] POST /v1/subscribers failed; trying request-link fallback", error)

        try {
          console.log("[ConnectDeviceStep] Calling fallback POST /v1/auth/request-link")
          await requestMagicLink({
            email,
            name: onboardingData.name || undefined,
          })
          sessionStorage.setItem("onboarding_subscribe_sent", "true")
          sessionStorage.setItem("onboarding_subscribe_state", "done")
          console.log("[ConnectDeviceStep] POST /v1/auth/request-link succeeded")
        } catch (fallbackError) {
          sessionStorage.removeItem("onboarding_subscribe_state")

          if (fallbackError instanceof ApiError) {
            console.error("[ConnectDeviceStep] Fallback request-link failed", {
              status: fallbackError.status,
              message: fallbackError.message,
              body: fallbackError.body,
            })
          } else {
            console.error("[ConnectDeviceStep] Fallback request-link failed", fallbackError)
          }
        }
      }
    }

    void sendVerificationEmail()
  }, [authed, hasHydrated, sessionPendingEmail])

  const handleConnect = (deviceId: string) => {
    if (!authed) return
    if (deviceId !== "garmin" && deviceId !== "fitbit") return

    setIsConnecting(true)
    setSelectedDevice(deviceId)
    updateFormData({ device: deviceId })

    // Set onboarding flow flag for OAuth callback
    sessionStorage.setItem("onboarding_flow", "true")

    // Redirect to backend OAuth — backend will redirect back to frontend after auth
    window.location.href = getOAuthConnectUrl(deviceId as "garmin" | "fitbit")
  }

  return (
    <div className="bg-card border border-border rounded-2xl p-6 md:p-10">
      <div className="mb-6">
        <h2 className="text-2xl md:text-3xl font-bold tracking-tight mb-2">
          Connect your device
        </h2>
        <p className="text-muted-foreground">
          Choose your wearable to start tracking your health insights
        </p>
      </div>

      {!authed && (
        <div className="mb-6 flex items-start gap-3 rounded-xl border border-primary/30 bg-primary/5 p-4">
          <Mail className="mt-0.5 h-5 w-5 shrink-0 text-primary" />
          <div>
            <p className="text-sm font-medium text-foreground">Verify your email first</p>
            <p className="mt-0.5 text-xs text-muted-foreground">
              We sent you a magic link. Click it to authenticate, then come back here to connect your device.
            </p>
          </div>
        </div>
      )}

      {/* Device Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
        {DEVICES.map((device) => (
          <motion.div
            key={device.id}
            whileHover={{ scale: device.available ? 1.02 : 1 }}
            whileTap={{ scale: device.available ? 0.98 : 1 }}
          >
            <button
              onClick={() => device.available && handleConnect(device.id)}
              disabled={!device.available || isConnecting || !authed}
              className={`relative w-full p-6 rounded-xl border-2 transition-all text-left ${
                selectedDevice === device.id
                  ? "border-primary bg-primary/5"
                  : device.available && authed
                  ? "border-border hover:border-primary/50 bg-background"
                  : "border-border bg-muted/30 opacity-60 cursor-not-allowed"
              }`}
            >
              <div className="flex items-center gap-4">
                <div
                  className={`flex items-center justify-center w-14 h-14 rounded-xl bg-gradient-to-br ${device.color}`}
                >
                  <Watch className="w-7 h-7 text-white" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <h3 className="font-semibold text-foreground">
                      {device.name}
                    </h3>
                    {!device.available && (
                      <span className="text-xs px-2 py-0.5 rounded-full bg-muted text-muted-foreground font-medium">
                        Coming Soon
                      </span>
                    )}
                  </div>
                  {device.available && (
                    <p className="text-sm text-muted-foreground mt-0.5">
                      {selectedDevice === device.id
                        ? "✓ Connected"
                        : "Tap to connect"}
                    </p>
                  )}
                </div>
              </div>

              {isConnecting && selectedDevice === device.id && (
                <div className="absolute inset-0 flex items-center justify-center bg-background/80 rounded-xl">
                  <div className="flex items-center gap-2 text-sm font-medium text-primary">
                    <div className="w-4 h-4 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                    Connecting...
                  </div>
                </div>
              )}
            </button>
          </motion.div>
        ))}
      </div>

      {/* What We'll Track */}
      <div className="border-t border-border pt-6">
        <h3 className="text-sm font-semibold text-foreground mb-4 flex items-center gap-2">
          <Shield className="w-4 h-4 text-primary" />
          What we'll track
        </h3>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {METRICS.map((metric) => {
            const Icon = metric.icon
            return (
              <div
                key={metric.label}
                className="flex flex-col items-center gap-2 p-3 rounded-lg bg-secondary/50"
              >
                <Icon className="w-5 h-5 text-primary" />
                <span className="text-xs text-muted-foreground text-center">
                  {metric.label}
                </span>
              </div>
            )
          })}
        </div>
        <p className="text-xs text-muted-foreground mt-4 text-center">
          Your data is encrypted and never shared. You can disconnect anytime.
        </p>
      </div>
    </div>
  )
}
