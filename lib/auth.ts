const JWT_KEY = "bp_token"
const EMAIL_KEY = "bp_email"
const LEGACY_EMAIL_KEY = "userEmail"
const ONBOARDING_KEY = "bp_onboarding"
const KNOWN_EMAILS_KEY = "bp_known_emails"
const AUTH_EVENT = "bp-auth-changed"

export type OnboardingData = {
  name: string
  goals: string[]
  timezone: string
  device: string
}

// ── JWT ──────────────────────────────────────────────────────────────────────

export function getToken(): string | null {
  if (typeof window === "undefined") return null
  return localStorage.getItem(JWT_KEY)
}

export function setToken(token: string): void {
  localStorage.setItem(JWT_KEY, token)
  if (typeof window !== "undefined") {
    window.dispatchEvent(new Event(AUTH_EVENT))
  }
}

export function clearToken(): void {
  localStorage.removeItem(JWT_KEY)
  if (typeof window !== "undefined") {
    window.dispatchEvent(new Event(AUTH_EVENT))
  }
}

export function isAuthenticated(): boolean {
  const token = getToken()
  if (!token) return false
  try {
    const payload = JSON.parse(atob(token.split(".")[1]))
    return payload.exp * 1000 > Date.now()
  } catch {
    return false
  }
}

// ── Email persistence ─────────────────────────────────────────────────────────

export function getPendingEmail(): string | null {
  if (typeof window === "undefined") return null
  return localStorage.getItem(EMAIL_KEY) ?? localStorage.getItem(LEGACY_EMAIL_KEY)
}

export function setPendingEmail(email: string): void {
  localStorage.setItem(EMAIL_KEY, email)
}

export function clearPendingEmail(): void {
  localStorage.removeItem(EMAIL_KEY)
  localStorage.removeItem(LEGACY_EMAIL_KEY)
}

// ── Onboarding state ──────────────────────────────────────────────────────────

export function getOnboardingData(): Partial<OnboardingData> {
  if (typeof window === "undefined") return {}
  try {
    const raw = localStorage.getItem(ONBOARDING_KEY)
    return raw ? JSON.parse(raw) : {}
  } catch {
    return {}
  }
}

export function setOnboardingData(data: Partial<OnboardingData>): void {
  const current = getOnboardingData()
  localStorage.setItem(ONBOARDING_KEY, JSON.stringify({ ...current, ...data }))
}

export function clearOnboardingData(): void {
  localStorage.removeItem(ONBOARDING_KEY)
}

// ── Known emails (signin hint) ──────────────────────────────────────────────

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase()
}

export function getKnownEmails(): string[] {
  if (typeof window === "undefined") return []
  try {
    const raw = localStorage.getItem(KNOWN_EMAILS_KEY)
    const parsed = raw ? JSON.parse(raw) : []
    return Array.isArray(parsed) ? parsed.filter((item): item is string => typeof item === "string") : []
  } catch {
    return []
  }
}

export function isKnownEmail(email: string): boolean {
  const target = normalizeEmail(email)
  return getKnownEmails().includes(target)
}

export function markKnownEmail(email: string): void {
  if (typeof window === "undefined") return
  const target = normalizeEmail(email)
  if (!target) return

  const emails = getKnownEmails()
  if (!emails.includes(target)) {
    localStorage.setItem(KNOWN_EMAILS_KEY, JSON.stringify([...emails, target]))
  }
}
