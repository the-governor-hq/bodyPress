"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { getMe, getConnections, Connection, ApiError } from "@/lib/api"
import { useAuthStore } from "@/lib/auth-store"
import { useSessionStore } from "@/lib/session-store"

export function useAuthSession() {
  const router = useRouter()
  const hasHydrated = useSessionStore((state) => state.hasHydrated)
  const isAuthed = useAuthStore((state) => state.isAuthed)
  const initializedAuth = useAuthStore((state) => state.initialized)
  const initializeAuth = useAuthStore((state) => state.initializeAuth)
  const signOut = useAuthStore((state) => state.signOut)
  
  const [loading, setLoading] = useState(true)
  const [connections, setConnections] = useState<Connection[]>([])
  const [userEmail, setUserEmail] = useState<string | null>(null)

  useEffect(() => {
    initializeAuth()
  }, [initializeAuth])

  useEffect(() => {
    if (!hasHydrated || !initializedAuth) return

    const verifySession = async () => {
      if (!isAuthed) {
        setConnections([])
        setLoading(false)
        return
      }

      try {
        const [me, connectionResponse] = await Promise.all([getMe(), getConnections()])
        setConnections(connectionResponse.connections)
        setUserEmail(me.email)
      } catch (err) {
        console.error("[useAuthSession] Failed to verify session:", err)
        if (err instanceof ApiError && err.status === 401) {
          signOut()
        }
        setConnections([])
        setUserEmail(null)
      } finally {
        setLoading(false)
      }
    }

    verifySession()
  }, [hasHydrated, initializedAuth, isAuthed, signOut])

  const hasConnectedDevice = connections.some((conn) => conn.status === "connected")

  return {
    isAuthed,
    initializedAuth,
    loading,
    connections,
    userEmail,
    hasConnectedDevice,
    signOut,
  }
}
