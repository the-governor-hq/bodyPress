"use client"

import { useState } from "react"
import { Watch, Activity, Heart, Clock, TrendingUp, Shield, Mail } from "lucide-react"
import { motion } from "framer-motion"
import { isAuthenticated } from "@/lib/auth"
import { getOAuthConnectUrl } from "@/lib/api"

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
    <div className="bg-card border border-border rounded-2xl p-8 md:p-12">
      <div className="mb-8">
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
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
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
