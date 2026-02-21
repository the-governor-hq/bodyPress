import axios, { AxiosError, AxiosRequestConfig } from "axios"
import { getToken } from "./auth"

const BASE_URL = (process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4000").replace(/\/$/, "")

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public body?: unknown,
  ) {
    super(message)
    this.name = "ApiError"
  }
}

// Create axios instance with default config
const apiClient = axios.create({
  baseURL: BASE_URL,
  timeout: 15000, // 15 second timeout
  headers: {
    "Content-Type": "application/json",
  },
})

// Request interceptor to add auth token
apiClient.interceptors.request.use(
  (config) => {
    const token = getToken()
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`
    }
    // Log API calls in development
    if (process.env.NODE_ENV === "development") {
      console.log(`[API] ${config.method?.toUpperCase()} ${config.url}`, config.data || "")
    }
    return config
  },
  (error) => {
    console.error("[API] Request error:", error)
    return Promise.reject(error)
  }
)

// Response interceptor for error handling
apiClient.interceptors.response.use(
  (response) => {
    // Log successful responses in development
    if (process.env.NODE_ENV === "development") {
      console.log(`[API] ✓ ${response.config.method?.toUpperCase()} ${response.config.url}`, response.data)
    }
    return response
  },
  (error: AxiosError) => {
    if (process.env.NODE_ENV === "development") {
      console.error("[API] ✗ Error:", error.message, error.response?.data)
    }
    
    const status = error.response?.status || 500
    const body = error.response?.data
    const message =
      typeof body === "object" && body !== null && "error" in body
        ? String((body as { error: unknown }).error)
        : error.message || `HTTP ${status}`
    
    throw new ApiError(status, message, body)
  }
)

async function request<T>(
  path: string,
  options: AxiosRequestConfig = {},
  authenticated = false,
): Promise<T> {
  try {
    const response = await apiClient.request<T>({
      url: path,
      ...options,
    })
    return response.data
  } catch (error) {
    if (error instanceof ApiError) throw error
    if (axios.isAxiosError(error)) {
      const status = error.response?.status || 500
      const body = error.response?.data
      const message =
        typeof body === "object" && body !== null && "error" in body
          ? String((body as { error: unknown }).error)
          : error.message || `HTTP ${status}`
      throw new ApiError(status, message, body)
    }
    throw error
  }
}

// ── Subscribers ───────────────────────────────────────────────────────────────

export interface SubscribeResponse {
  message: string
  userId: string
  isNew: boolean
}

export function subscribe(email: string): Promise<SubscribeResponse> {
  return request<SubscribeResponse>("/v1/subscribers", {
    method: "POST",
    data: { email },
  })
}

export function unsubscribe(email: string): Promise<void> {
  return request<void>("/v1/subscribers", {
    method: "DELETE",
    data: { email },
  })
}

// ── Auth ──────────────────────────────────────────────────────────────────────

export interface MagicLinkResponse {
  message: string
}

export function requestMagicLink(email: string): Promise<MagicLinkResponse> {
  return request<MagicLinkResponse>("/v1/auth/request-link", {
    method: "POST",
    data: { email },
  })
}

export interface VerifyTokenResponse {
  token: string
  user: { id: string; email: string; name?: string; onboardingDone: boolean }
}

export function verifyMagicLink(token: string): Promise<VerifyTokenResponse> {
  return request<VerifyTokenResponse>(`/v1/auth/verify?token=${encodeURIComponent(token)}`)
}

export interface MeResponse {
  id: string
  email: string
  name?: string
  timezone?: string
  goals: string[]
  newsletterOptIn: boolean
  onboardingDone: boolean
  connections: { provider: string; status: string; connectedAt: string }[]
}

export function getMe(): Promise<MeResponse> {
  return request<MeResponse>("/v1/auth/me", {}, true)
}

// ── Profile ───────────────────────────────────────────────────────────────────

export interface UpdateProfilePayload {
  name?: string
  timezone?: string
  goals?: string[]
  notifyAt?: string
  onboardingDone?: boolean
}

export function updateProfile(payload: UpdateProfilePayload): Promise<MeResponse> {
  return request<MeResponse>("/v1/profile", { method: "PATCH", data: payload }, true)
}

// ── OAuth ─────────────────────────────────────────────────────────────────────

/**
 * Returns the URL to redirect the browser to for OAuth device connection.
 * The backend accepts `?auth_token=` so no popup/CORS issue.
 */
export function getOAuthConnectUrl(provider: "garmin" | "fitbit"): string {
  const token = getToken()
  const params = new URLSearchParams()
  if (token) params.set("auth_token", token)
  return `${BASE_URL}/oauth/${provider}/connect?${params.toString()}`
}

export interface DisconnectResponse {
  message: string
}

export function disconnectDevice(provider: "garmin" | "fitbit"): Promise<DisconnectResponse> {
  return request<DisconnectResponse>(`/oauth/${provider}/disconnect`, { method: "POST" }, true)
}

// ── Wearables ─────────────────────────────────────────────────────────────────

export interface Connection {
  provider: string
  status: "connected" | "disconnected" | "error"
  connectedAt?: string
  lastSync?: string
  health?: {
    status: string
    details?: string
  }
}

export interface ConnectionsResponse {
  connections: Connection[]
}

export function getConnections(): Promise<ConnectionsResponse> {
  return request<ConnectionsResponse>("/v1/wearables/connections", {}, true)
}

export interface SyncResponse {
  message: string
  provider: string
}

export function triggerSync(provider: "garmin" | "fitbit"): Promise<SyncResponse> {
  return request<SyncResponse>(`/v1/wearables/${provider}/sync`, { method: "POST" }, true)
}

export function triggerBackfill(provider: "garmin" | "fitbit"): Promise<SyncResponse> {
  return request<SyncResponse>(`/v1/wearables/${provider}/backfill`, { method: "POST" }, true)
}

export interface Activity {
  id: string
  provider: string
  startTime: string
  duration: number
  type: string
  calories?: number
  distance?: number
  avgHeartRate?: number
  maxHeartRate?: number
}

export interface ActivitiesResponse {
  activities: Activity[]
  total: number
}

export function getActivities(params?: {
  provider?: string
  from?: string
  to?: string
  limit?: number
}): Promise<ActivitiesResponse> {
  const searchParams = new URLSearchParams()
  if (params?.provider) searchParams.set("provider", params.provider)
  if (params?.from) searchParams.set("from", params.from)
  if (params?.to) searchParams.set("to", params.to)
  if (params?.limit) searchParams.set("limit", params.limit.toString())

  const url = `/v1/wearables/activities${searchParams.toString() ? `?${searchParams.toString()}` : ""}`
  return request<ActivitiesResponse>(url, {}, true)
}

export interface Sleep {
  id: string
  provider: string
  date: string
  duration: number
  quality?: number
  deepSleep?: number
  lightSleep?: number
  remSleep?: number
  awake?: number
}

export interface SleepResponse {
  sleep: Sleep[]
  total: number
}

export function getSleep(params?: {
  provider?: string
  from?: string
  to?: string
  limit?: number
}): Promise<SleepResponse> {
  const searchParams = new URLSearchParams()
  if (params?.provider) searchParams.set("provider", params.provider)
  if (params?.from) searchParams.set("from", params.from)
  if (params?.to) searchParams.set("to", params.to)
  if (params?.limit) searchParams.set("limit", params.limit.toString())

  const url = `/v1/wearables/sleep${searchParams.toString() ? `?${searchParams.toString()}` : ""}`
  return request<SleepResponse>(url, {}, true)
}

export interface Daily {
  id: string
  provider: string
  date: string
  steps?: number
  calories?: number
  distance?: number
  activeMinutes?: number
  restingHeartRate?: number
}

export interface DailiesResponse {
  dailies: Daily[]
  total: number
}

export function getDailies(params?: {
  provider?: string
  from?: string
  to?: string
  limit?: number
}): Promise<DailiesResponse> {
  const searchParams = new URLSearchParams()
  if (params?.provider) searchParams.set("provider", params.provider)
  if (params?.from) searchParams.set("from", params.from)
  if (params?.to) searchParams.set("to", params.to)
  if (params?.limit) searchParams.set("limit", params.limit.toString())

  const url = `/v1/wearables/dailies${searchParams.toString() ? `?${searchParams.toString()}` : ""}`
  return request<DailiesResponse>(url, {}, true)
}

export interface Summary {
  period: string
  providers: string[]
  activities: {
    count: number
    totalDuration: number
    totalCalories: number
    totalDistance: number
  }
  sleep: {
    count: number
    avgDuration: number
    avgQuality?: number
  }
  dailies: {
    avgSteps: number
    avgCalories: number
    avgActiveMinutes: number
  }
}

export function getSummary(params?: {
  provider?: string
  days?: number
}): Promise<Summary> {
  const searchParams = new URLSearchParams()
  if (params?.provider) searchParams.set("provider", params.provider)
  if (params?.days) searchParams.set("days", params.days.toString())

  const url = `/v1/wearables/summary${searchParams.toString() ? `?${searchParams.toString()}` : ""}`
  return request<Summary>(url, {}, true)
}
