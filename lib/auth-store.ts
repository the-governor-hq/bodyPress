"use client"

import { create } from "zustand"
import { clearPendingEmail, clearToken, clearOnboardingData, isAuthenticated } from "@/lib/auth"
import { useSessionStore } from "@/lib/session-store"

const AUTH_EVENT = "bp-auth-changed"
const JWT_KEY = "bp_token"

let listenersBound = false

export type AuthError = {
  message: string
  isNetworkError: boolean
  timestamp: number
}

type AuthStore = {
  isAuthed: boolean
  initialized: boolean
  lastError: AuthError | null
  initializeAuth: () => void
  refreshAuth: () => void
  signOut: () => void
  clearError: () => void
  setError: (message: string, isNetworkError?: boolean) => void
}

export const useAuthStore = create<AuthStore>((set, get) => ({
  isAuthed: false,
  initialized: false,
  lastError: null,

  refreshAuth: () => {
    set({ isAuthed: isAuthenticated() })
  },

  setError: (message: string, isNetworkError = false) => {
    set({ 
      lastError: {
        message,
        isNetworkError,
        timestamp: Date.now(),
      }
    })
  },

  clearError: () => {
    set({ lastError: null })
  },

  initializeAuth: () => {
    if (typeof window !== "undefined") {
      set({ isAuthed: isAuthenticated(), initialized: true })

      if (!listenersBound) {
        const onAuthChanged = () => {
          const newAuthState = isAuthenticated()
          set({ isAuthed: newAuthState })
          
          // Clear error when auth state changes successfully
          if (newAuthState) {
            get().clearError()
          }
        }
        
        const onStorage = (event: StorageEvent) => {
          if (event.key === JWT_KEY) onAuthChanged()
        }

        window.addEventListener(AUTH_EVENT, onAuthChanged)
        window.addEventListener("storage", onStorage)
        listenersBound = true
      }
      return
    }

    set({ initialized: true })
  },

  signOut: () => {
    clearToken()
    clearPendingEmail()
    clearOnboardingData()
    useSessionStore.getState().clearPendingEmail()
    
    if (typeof window !== "undefined") {
      sessionStorage.removeItem("onboarding_subscribe_sent")
      sessionStorage.removeItem("onboarding_subscribe_state")
      window.dispatchEvent(new Event(AUTH_EVENT))
    }
    
    set({ isAuthed: false, lastError: null })
  },
}))
