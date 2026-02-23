"use client"

import { create } from "zustand"
import { createJSONStorage, persist } from "zustand/middleware"

type SessionState = {
  pendingEmail: string | null
  hasHydrated: boolean
  setPendingEmail: (email: string) => void
  clearPendingEmail: () => void
  setHasHydrated: (hydrated: boolean) => void
}

export const useSessionStore = create<SessionState>()(
  persist(
    (set) => ({
      pendingEmail: null,
      hasHydrated: false,
      setPendingEmail: (email) => set({ pendingEmail: email }),
      clearPendingEmail: () => set({ pendingEmail: null }),
      setHasHydrated: (hydrated) => set({ hasHydrated: hydrated }),
    }),
    {
      name: "bp_session",
      storage: createJSONStorage(() => localStorage),
      onRehydrateStorage: () => (state) => {
        state?.setHasHydrated(true)
      },
    },
  ),
)
