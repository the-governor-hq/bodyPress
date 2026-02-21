"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { Activity, Heart, TrendingUp, Plus, Unplug, RefreshCw, Loader2, LogOut } from "lucide-react"
import { 
  getConnections, 
  getOAuthConnectUrl, 
  disconnectDevice,
  triggerSync,
  Connection,
  ApiError 
} from "@/lib/api"
import { SiteHeader } from "@/components/site-header"
import { SiteFooter } from "@/components/site-footer"
import { useAuthStore } from "@/lib/auth-store"

const DEVICES = [
  {
    id: "garmin",
    name: "Garmin",
    color: "from-blue-500 to-cyan-500",
  },
  {
    id: "fitbit",
    name: "Fitbit",
    color: "from-teal-500 to-green-500",
  },
] as const

export default function DashboardPage() {
  const router = useRouter()
  const isAuthed = useAuthStore((state) => state.isAuthed)
  const initializedAuth = useAuthStore((state) => state.initialized)
  const initializeAuth = useAuthStore((state) => state.initializeAuth)
  const signOut = useAuthStore((state) => state.signOut)
  const [connections, setConnections] = useState<Connection[]>([])
  const [loading, setLoading] = useState(true)
  const [syncing, setSyncing] = useState<string | null>(null)
  const [disconnecting, setDisconnecting] = useState<string | null>(null)
  const [signingOut, setSigningOut] = useState(false)

  useEffect(() => {
    initializeAuth()
  }, [initializeAuth])

  useEffect(() => {
    if (!initializedAuth) return

    if (!isAuthed) {
      router.push("/")
      return
    }

    loadConnections()
  }, [router, isAuthed, initializedAuth])

  const loadConnections = async () => {
    try {
      setLoading(true)
      const response = await getConnections()
      setConnections(response.connections)
    } catch (err) {
      console.error("Failed to load connections:", err)
      if (err instanceof ApiError && err.status === 401) {
        router.push("/")
      }
    } finally {
      setLoading(false)
    }
  }

  const handleConnect = (provider: "garmin" | "fitbit") => {
    window.location.href = getOAuthConnectUrl(provider)
  }

  const handleDisconnect = async (provider: "garmin" | "fitbit") => {
    if (!confirm(`Are you sure you want to disconnect your ${provider} device?`)) {
      return
    }

    try {
      setDisconnecting(provider)
      await disconnectDevice(provider)
      await loadConnections()
    } catch (err) {
      console.error("Failed to disconnect:", err)
      alert("Failed to disconnect device. Please try again.")
    } finally {
      setDisconnecting(null)
    }
  }

  const handleSync = async (provider: "garmin" | "fitbit") => {
    try {
      setSyncing(provider)
      await triggerSync(provider)
      await loadConnections()
      alert(`${provider} sync triggered successfully!`)
    } catch (err) {
      console.error("Failed to sync:", err)
      alert("Failed to sync device. Please try again.")
    } finally {
      setSyncing(null)
    }
  }

  const getConnectionStatus = (provider: string) => {
    return connections.find(conn => conn.provider.toLowerCase() === provider.toLowerCase())
  }

  const handleSignOut = async () => {
    if (!confirm("Sign out from this browser session?")) {
      return
    }

    try {
      setSigningOut(true)
    } finally {
      signOut()
      router.replace("/")
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background">
      <SiteHeader />
      
      <main className="container mx-auto px-4 py-16 max-w-4xl">
        <div className="mb-8">
          <h1 className="text-3xl md:text-4xl font-bold tracking-tight mb-2">
            Dashboard
          </h1>
          <div className="flex items-center justify-between gap-4">
            <p className="text-muted-foreground">
              Manage your connected devices and view your health data
            </p>
            <button
              onClick={handleSignOut}
              disabled={signingOut}
              className="inline-flex items-center gap-2 rounded-lg border border-border px-3 py-2 text-sm text-muted-foreground hover:text-foreground hover:border-destructive hover:bg-destructive/10 disabled:opacity-60"
            >
              {signingOut ? <Loader2 className="h-4 w-4 animate-spin" /> : <LogOut className="h-4 w-4" />}
              Sign out
            </button>
          </div>
        </div>

        {/* Connected Devices */}
        <section className="mb-12">
          <h2 className="text-2xl font-semibold mb-6">Connected Devices</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {DEVICES.map((device) => {
              const connection = getConnectionStatus(device.id)
              const isConnected = connection?.status === "connected"
              const isSyncing = syncing === device.id
              const isDisconnecting = disconnecting === device.id

              return (
                <div
                  key={device.id}
                  className={`p-6 rounded-xl border-2 transition-all ${
                    isConnected
                      ? "border-primary bg-primary/5"
                      : "border-border bg-card"
                  }`}
                >
                  <div className="flex items-start justify-between mb-4">
                    <div className="flex items-center gap-3">
                      <div
                        className={`flex items-center justify-center w-12 h-12 rounded-xl bg-linear-to-br ${device.color}`}
                      >
                        <Activity className="w-6 h-6 text-white" />
                      </div>
                      <div>
                        <h3 className="font-semibold text-lg">{device.name}</h3>
                        {isConnected && connection.connectedAt && (
                          <p className="text-xs text-muted-foreground">
                            Connected {new Date(connection.connectedAt).toLocaleDateString()}
                          </p>
                        )}
                      </div>
                    </div>
                    <div
                      className={`px-2 py-1 rounded-full text-xs font-medium ${
                        isConnected
                          ? "bg-green-500/10 text-green-600 dark:text-green-400"
                          : "bg-muted text-muted-foreground"
                      }`}
                    >
                      {isConnected ? "Connected" : "Not Connected"}
                    </div>
                  </div>

                  {isConnected && connection.lastSync && (
                    <div className="mb-4 text-sm text-muted-foreground">
                      Last sync: {new Date(connection.lastSync).toLocaleString()}
                    </div>
                  )}

                  {connection?.health && (
                    <div className="mb-4 p-3 rounded-lg bg-secondary/50 text-sm">
                      <div className="flex items-center gap-2">
                        <Heart className="w-4 h-4 text-primary" />
                        <span className="font-medium">Health Status:</span>
                        <span className={connection.health.status === "healthy" ? "text-green-600 dark:text-green-400" : "text-yellow-600 dark:text-yellow-400"}>
                          {connection.health.status}
                        </span>
                      </div>
                      {connection.health.details && (
                        <p className="mt-1 text-xs text-muted-foreground">
                          {connection.health.details}
                        </p>
                      )}
                    </div>
                  )}

                  <div className="flex flex-col gap-2">
                    {isConnected ? (
                      <>
                        <button
                          onClick={() => handleSync(device.id as "garmin" | "fitbit")}
                          disabled={isSyncing}
                          className="flex items-center justify-center gap-2 w-full px-4 py-2 rounded-lg bg-primary text-primary-foreground hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {isSyncing ? (
                            <>
                              <Loader2 className="w-4 h-4 animate-spin" />
                              Syncing...
                            </>
                          ) : (
                            <>
                              <RefreshCw className="w-4 h-4" />
                              Sync Now
                            </>
                          )}
                        </button>
                        <button
                          onClick={() => handleDisconnect(device.id as "garmin" | "fitbit")}
                          disabled={isDisconnecting}
                          className="flex items-center justify-center gap-2 w-full px-4 py-2 rounded-lg border border-border hover:bg-destructive hover:text-destructive-foreground hover:border-destructive transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {isDisconnecting ? (
                            <>
                              <Loader2 className="w-4 h-4 animate-spin" />
                              Disconnecting...
                            </>
                          ) : (
                            <>
                              <Unplug className="w-4 h-4" />
                              Disconnect
                            </>
                          )}
                        </button>
                      </>
                    ) : (
                      <button
                        onClick={() => handleConnect(device.id as "garmin" | "fitbit")}
                        className="flex items-center justify-center gap-2 w-full px-4 py-2 rounded-lg bg-primary text-primary-foreground hover:brightness-110 transition-all"
                      >
                        <Plus className="w-4 h-4" />
                        Connect {device.name}
                      </button>
                    )}
                  </div>
                </div>
              )
            })}
          </div>
        </section>

        {/* Quick Stats */}
        <section>
          <h2 className="text-2xl font-semibold mb-6">Quick Stats</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {[
              { icon: Activity, label: "Activities", value: "Coming Soon" },
              { icon: Heart, label: "Avg Heart Rate", value: "Coming Soon" },
              { icon: TrendingUp, label: "Weekly Progress", value: "Coming Soon" },
            ].map((stat) => (
              <div
                key={stat.label}
                className="p-6 rounded-xl border border-border bg-card"
              >
                <div className="flex items-center gap-3 mb-2">
                  <stat.icon className="w-5 h-5 text-primary" />
                  <h3 className="font-medium text-sm text-muted-foreground">
                    {stat.label}
                  </h3>
                </div>
                <p className="text-2xl font-bold">{stat.value}</p>
              </div>
            ))}
          </div>
        </section>
      </main>

      <SiteFooter />
    </div>
  )
}
