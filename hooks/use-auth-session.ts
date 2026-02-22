"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { getMe, getConnections, Connection, ApiError, getUserFriendlyErrorMessage, isNetworkError } from "@/lib/api"
import { useAuthStore } from "@/lib/auth-store"
import { useSessionStore } from "@/lib/session-store"
import { useNetworkStatus } from "@/hooks/use-network-status"
import { toast } from "@/hooks/use-toast"

export function useAuthSession() {
  const router = useRouter()
  const { isOnline, wasOffline } = useNetworkStatus()
  const hasHydrated = useSessionStore((state) => state.hasHydrated)
  const isAuthed = useAuthStore((state) => state.isAuthed)
  const initializedAuth = useAuthStore((state) => state.initialized)
  const initializeAuth = useAuthStore((state) => state.initializeAuth)
  const signOut = useAuthStore((state) => state.signOut)
  const setAuthError = useAuthStore((state) => state.setError)
  const clearAuthError = useAuthStore((state) => state.clearError)
  
  const [loading, setLoading] = useState(true)
  const [connections, setConnections] = useState<Connection[]>([])
  const [userEmail, setUserEmail] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    initializeAuth()
  }, [initializeAuth])

  // Show toast when network comes back online
  useEffect(() => {
    if (isOnline && wasOffline) {
      toast({
        title: "Back online",
        description: "Connection restored. Retrying...",
        duration: 3000,
      })
      // Trigger a retry
      setRetryCount(prev => prev + 1)
    }
  }, [isOnline, wasOffline])

  // Show toast when offline
  useEffect(() => {
    if (!isOnline) {
      toast({
        title: "You're offline",
        description: "Please check your internet connection.",
        variant: "destructive",
        duration: 5000,
      })
    }
  }, [isOnline])

  useEffect(() => {
    if (!hasHydrated || !initializedAuth) return

    const verifySession = async () => {
      if (!isAuthed) {
        setConnections([])
        setUserEmail(null)
        setError(null)
        setLoading(false)
        clearAuthError()
        return
      }

      try {
        setError(null)
        clearAuthError()
        
        const [me, connectionResponse] = await Promise.all([getMe(), getConnections()])
        setConnections(connectionResponse.connections)
        setUserEmail(me.email)
        
        console.log('[useAuthSession] Session verified:', {
          email: me.email,
          connectionCount: connectionResponse.connections.length,
          connections: connectionResponse.connections
        })
      } catch (err) {
        console.error("[useAuthSession] Failed to verify session:", err)
        
        const errorMessage = getUserFriendlyErrorMessage(err)
        const isNetworkErr = isNetworkError(err)
        
        setError(errorMessage)
        setAuthError(errorMessage, isNetworkErr)
        
        // Show toast for network errors
        if (isNetworkErr) {
          toast({
            title: "Connection Error",
            description: errorMessage,
            variant: "destructive",
            duration: 5000,
          })
        }
        
        // Only sign out on 401 errors (invalid/expired token)
        if (err instanceof ApiError && err.status === 401) {
          toast({
            title: "Session Expired",
            description: "Please sign in again.",
            variant: "destructive",
          })
          signOut()
        }
        
        setConnections([])
        setUserEmail(null)
      } finally {
        setLoading(false)
      }
    }

    verifySession()
  }, [hasHydrated, initializedAuth, isAuthed, signOut, setAuthError, clearAuthError, retryCount])

  const hasConnectedDevice = connections.some((conn) => conn.status === "connected" || conn.status === "active")

  return {
    isAuthed,
    initializedAuth,
    loading,
    connections,
    userEmail,
    hasConnectedDevice,
    signOut,
    error,
    isOnline,
  }
}
