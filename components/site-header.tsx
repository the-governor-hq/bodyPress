"use client"

import { useState, useEffect } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { Activity, Menu, X, LayoutDashboard, LogOut } from "lucide-react"
import { ThemeToggle } from "@/components/theme-toggle"
import { useAuthStore } from "@/lib/auth-store"

export function SiteHeader() {
  const router = useRouter()
  const isAuthed = useAuthStore((state) => state.isAuthed)
  const initializeAuth = useAuthStore((state) => state.initializeAuth)
  const signOut = useAuthStore((state) => state.signOut)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

  useEffect(() => {
    initializeAuth()
  }, [initializeAuth])

  const handleSignOut = () => {
    signOut()
    setMobileMenuOpen(false)
    router.replace("/")
  }

  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-border/50 bg-background/80 backdrop-blur-md">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-4 sm:px-6">
        <Link href="/" className="flex items-center gap-2">
          <Activity className="h-5 w-5 text-primary" />
          <span className="text-lg font-bold tracking-tight text-foreground">
            BodyPress
          </span>
        </Link>
        
        {/* Desktop navigation */}
        <nav className="hidden items-center gap-6 md:flex" aria-label="Main navigation">
          {isAuthed ? (
            <>
              <Link
                href="/dashboard"
                className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
              >
                <LayoutDashboard className="h-4 w-4" />
                Dashboard
              </Link>
              <button
                onClick={handleSignOut}
                className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
              >
                <LogOut className="h-4 w-4" />
                Sign out
              </button>
              <ThemeToggle />
            </>
          ) : (
            <>
              <a
                href="#how-it-works"
                className="text-sm text-muted-foreground transition-colors hover:text-foreground"
              >
                How it works
              </a>
              <a
                href="#sample"
                className="text-sm text-muted-foreground transition-colors hover:text-foreground"
              >
                Sample
              </a>
              <ThemeToggle />
              <a
                href="#subscribe"
                className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground transition-all hover:brightness-110"
              >
                Subscribe
              </a>
            </>
          )}
        </nav>

        {/* Mobile menu button */}
        <button
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          className="md:hidden rounded-lg p-2 text-muted-foreground transition-colors hover:bg-secondary hover:text-foreground"
          aria-label="Toggle menu"
          aria-expanded={mobileMenuOpen}
        >
          {mobileMenuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </div>

      {/* Mobile navigation */}
      {mobileMenuOpen && (
        <nav className="border-t border-border bg-background/95 backdrop-blur-md md:hidden" aria-label="Mobile navigation">
          <div className="mx-auto max-w-5xl px-4 py-4 sm:px-6">
            <div className="flex flex-col gap-4">
              {isAuthed ? (
                <>
                  <Link
                    href="/dashboard"
                    onClick={() => setMobileMenuOpen(false)}
                    className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    <LayoutDashboard className="h-4 w-4" />
                    Dashboard
                  </Link>
                  <button
                    onClick={handleSignOut}
                    className="flex items-center gap-2 text-left text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    <LogOut className="h-4 w-4" />
                    Sign out
                  </button>
                  <div className="pt-1">
                    <ThemeToggle />
                  </div>
                </>
              ) : (
                <>
                  <a
                    href="#how-it-works"
                    onClick={() => setMobileMenuOpen(false)}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    How it works
                  </a>
                  <a
                    href="#sample"
                    onClick={() => setMobileMenuOpen(false)}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    Sample
                  </a>
                  <a
                    href="#subscribe"
                    onClick={() => setMobileMenuOpen(false)}
                    className="rounded-lg bg-primary px-4 py-2 text-center text-sm font-semibold text-primary-foreground transition-all hover:brightness-110"
                  >
                    Subscribe
                  </a>
                  <div className="pt-1">
                    <ThemeToggle />
                  </div>
                </>
              )}
            </div>
          </div>
        </nav>
      )}
    </header>
  )
}
