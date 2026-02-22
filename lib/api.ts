import axios, { AxiosError, AxiosRequestConfig } from "axios"
import axiosRetry from "axios-retry"
import { getToken } from "./auth"

function resolveBaseUrl(): string {
  const raw = process.env.NEXT_PUBLIC_API_URL
  const trimmed = raw?.trim()
  if (!trimmed) return "http://localhost:4000"
  return trimmed.replace(/\/$/, "")
}

const BASE_URL = resolveBaseUrl()

if (process.env.NODE_ENV === "development") {
  console.log("[API] Base URL:", BASE_URL)
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public body?: unknown,
    public isNetworkError: boolean = false,
  ) {
    super(message)
    this.name = "ApiError"
  }
}

export function isNetworkError(error: unknown): boolean {
  if (error instanceof ApiError) {
    return error.isNetworkError
  }
  if (axios.isAxiosError(error)) {
    return !error.response && Boolean(error.request)
  }
  return false
}

export function getUserFriendlyErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.isNetworkError) {
      return "Unable to connect to the server. Please check your internet connection and try again."
    }
    if (error.status === 401) {
      return "Your session has expired. Please sign in again."
    }
    if (error.status === 403) {
      return "You don't have permission to perform this action."
    }
    if (error.status === 404) {
      return "The requested resource was not found."
    }
    if (error.status >= 500) {
      return "A server error occurred. Please try again later."
    }
    return error.message
  }
  return "An unexpected error occurred. Please try again."
}

// Create axios instance with default config
const apiClient = axios.create({
  baseURL: BASE_URL,
  timeout: 15000, // 15 second timeout
  headers: {
    "Content-Type": "application/json",
  },
})

// Configure retry logic
axiosRetry(apiClient, {
  retries: 3,
  retryDelay: axiosRetry.exponentialDelay,
  retryCondition: (error) => {
    // Retry on network errors and 5xx server errors
    return axiosRetry.isNetworkOrIdempotentRequestError(error) || 
           (error.response?.status ? error.response.status >= 500 : false)
  },
  onRetry: (retryCount, error, requestConfig) => {
    console.log(`[API] Retry attempt ${retryCount} for ${requestConfig.method?.toUpperCase()} ${requestConfig.url}`)
  },
})

function buildDebugUrl(config: AxiosRequestConfig): string {
  const base = (config.baseURL ?? BASE_URL).replace(/\/$/, "")
  const path = String(config.url ?? "")
  const joined = /^https?:\/\//i.test(path) ? path : `${base}${path.startsWith("/") ? "" : "/"}${path}`
  const params = config.params
  if (!params || typeof params !== "object") return joined

  const query = new URLSearchParams()
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null) return
    query.set(key, String(value))
  })
  const queryString = query.toString()
  return queryString ? `${joined}?${queryString}` : joined
}

function debugBody(value: unknown): unknown {
  if (value == null) return value
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
    return value
  }
  try {
    return JSON.parse(JSON.stringify(value))
  } catch {
    return String(value)
  }
}

// Request interceptor to add auth token
apiClient.interceptors.request.use(
  (config) => {
    const token = getToken()
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`
    }
    // Log API calls in development
    if (process.env.NODE_ENV === "development") {
      const debugUrl = buildDebugUrl(config)
      console.log(`[API ->] ${config.method?.toUpperCase()} ${debugUrl}`, {
        data: config.data || null,
        hasAuth: Boolean(token),
      })
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
      const debugUrl = buildDebugUrl(response.config)
      console.log(
        `[API <-] ${response.status} ${response.config.method?.toUpperCase()} ${debugUrl}`,
        response.data,
      )
    }
    return response
  },
  (error: AxiosError) => {
    // Check if it's a network error (no response received)
    const isNetworkErr = !error.response && Boolean(error.request)
    
    if (process.env.NODE_ENV === "development") {
      const debugUrl = buildDebugUrl(error.config ?? {})
      console.error(
        `[API !!] ${error.response?.status ?? "NETWORK_ERROR"} ${error.config?.method?.toUpperCase()} ${debugUrl}`,
        isNetworkErr ? "Network error - no response received" : error.message,
        {
          statusText: error.response?.statusText,
          data: debugBody(error.response?.data),
          isNetworkError: isNetworkErr,
        },
      )
    }
    
    const status = error.response?.status || (isNetworkErr ? 0 : 500)
    const body = error.response?.data
    
    let message: string
    if (isNetworkErr) {
      message = "Network error: Unable to reach the server"
    } else if (typeof body === "object" && body !== null && "error" in body) {
      message = String((body as { error: unknown }).error)
    } else {
      message = error.message || `HTTP ${status}`
    }
    
    throw new ApiError(status, message, body, isNetworkErr)
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
      const isNetworkErr = !error.response && Boolean(error.request)
      const status = error.response?.status || (isNetworkErr ? 0 : 500)
      const body = error.response?.data
      
      let message: string
      if (isNetworkErr) {
        message = "Network error: Unable to reach the server"
      } else if (typeof body === "object" && body !== null && "error" in body) {
        message = String((body as { error: unknown }).error)
      } else {
        message = error.message || `HTTP ${status}`
      }
      
      throw new ApiError(status, message, body, isNetworkErr)
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

export interface SubscribePayload {
  email: string
  name?: string
  timezone?: string
  goals?: string[]
}

export function subscribe(payload: SubscribePayload | string): Promise<SubscribeResponse> {
  const body: SubscribePayload =
    typeof payload === "string" ? { email: payload } : payload

  return request<SubscribeResponse>("/v1/subscribers", {
    method: "POST",
    data: body,
  })
}

export function unsubscribe(email: string): Promise<void> {
  return request<void>("/v1/subscribers", {
    method: "DELETE",
    params: { email },
  })
}

// ── Auth ──────────────────────────────────────────────────────────────────────

export interface MagicLinkResponse {
  message: string
}

export interface RequestMagicLinkPayload {
  email: string
  name?: string
}

export function requestMagicLink(payload: RequestMagicLinkPayload | string): Promise<MagicLinkResponse> {
  const body: RequestMagicLinkPayload =
    typeof payload === "string" ? { email: payload } : payload

  return request<MagicLinkResponse>("/v1/auth/request-link", {
    method: "POST",
    data: body,
  })
}

export interface VerifyTokenResponse {
  token: string
  user: { id?: string; email: string; name?: string; onboardingDone?: boolean }
}

function isVerifyTokenResponse(value: unknown): value is VerifyTokenResponse {
  if (!value || typeof value !== "object") return false

  const maybe = value as {
    token?: unknown
    user?: {
      id?: unknown
      email?: unknown
      onboardingDone?: unknown
    }
    userId?: unknown
    email?: unknown
  }

  const hasNestedUser =
    maybe.user &&
    typeof maybe.user === "object" &&
    typeof maybe.user.email === "string"

  const hasFlatUser = typeof maybe.email === "string"

  return typeof maybe.token === "string" && Boolean(hasNestedUser || hasFlatUser)
}

function normalizeVerifyTokenResponse(value: unknown): VerifyTokenResponse {
  const parsed = value as {
    token: string
    user?: {
      id?: string
      email: string
      name?: string
      onboardingDone?: boolean
    }
    userId?: string
    email?: string
  }

  if (parsed.user && typeof parsed.user.email === "string") {
    return {
      token: parsed.token,
      user: {
        id: parsed.user.id,
        email: parsed.user.email,
        name: parsed.user.name,
        onboardingDone: parsed.user.onboardingDone,
      },
    }
  }

  return {
    token: parsed.token,
    user: {
      id: parsed.userId,
      email: String(parsed.email),
    },
  }
}

export async function verifyMagicLink(token: string): Promise<VerifyTokenResponse> {
  const response = await request<VerifyTokenResponse | { data?: unknown }>(
    `/v1/auth/verify?token=${encodeURIComponent(token)}`,
  )

  if (isVerifyTokenResponse(response)) return normalizeVerifyTokenResponse(response)

  const wrapped =
    response && typeof response === "object" && "data" in response
      ? (response as { data?: unknown }).data
      : undefined

  if (isVerifyTokenResponse(wrapped)) return normalizeVerifyTokenResponse(wrapped)

  throw new ApiError(500, "Unexpected verification response format", response)
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
  newsletterOptIn?: boolean
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

export function getConnections(forceRefresh = false): Promise<ConnectionsResponse> {
  const config: AxiosRequestConfig = forceRefresh
    ? {
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
        params: { _t: Date.now() }, // Cache-busting query param
      }
    : {}
  
  if (process.env.NODE_ENV === 'development') {
    console.log('[API] getConnections called with forceRefresh:', forceRefresh)
  }
  
  return request<ConnectionsResponse>("/v1/wearables/connections", config, true)
}

export interface SyncResponse {
  message: string
  provider: string
}

export interface TriggerSyncPayload {
  startDate?: string
  endDate?: string
}

export function triggerSync(
  provider: "garmin" | "fitbit",
  payload?: TriggerSyncPayload,
): Promise<SyncResponse> {
  return request<SyncResponse>(
    `/v1/wearables/${provider}/sync`,
    { method: "POST", data: payload },
    true,
  )
}

export interface TriggerBackfillPayload {
  daysBack?: number
}

export function triggerBackfill(
  provider: "garmin" | "fitbit",
  payload?: TriggerBackfillPayload,
): Promise<SyncResponse> {
  return request<SyncResponse>(
    `/v1/wearables/${provider}/backfill`,
    { method: "POST", data: payload },
    true,
  )
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
  startDate?: string
  endDate?: string
  from?: string
  to?: string
  limit?: number
}): Promise<ActivitiesResponse> {
  const searchParams = new URLSearchParams()
  if (params?.provider) searchParams.set("provider", params.provider)
  if (params?.startDate ?? params?.from) searchParams.set("startDate", params?.startDate ?? params?.from ?? "")
  if (params?.endDate ?? params?.to) searchParams.set("endDate", params?.endDate ?? params?.to ?? "")
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
  startDate?: string
  endDate?: string
  from?: string
  to?: string
  limit?: number
}): Promise<SleepResponse> {
  const searchParams = new URLSearchParams()
  if (params?.provider) searchParams.set("provider", params.provider)
  if (params?.startDate ?? params?.from) searchParams.set("startDate", params?.startDate ?? params?.from ?? "")
  if (params?.endDate ?? params?.to) searchParams.set("endDate", params?.endDate ?? params?.to ?? "")
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
  startDate?: string
  endDate?: string
  from?: string
  to?: string
  limit?: number
}): Promise<DailiesResponse> {
  const searchParams = new URLSearchParams()
  if (params?.provider) searchParams.set("provider", params.provider)
  if (params?.startDate ?? params?.from) searchParams.set("startDate", params?.startDate ?? params?.from ?? "")
  if (params?.endDate ?? params?.to) searchParams.set("endDate", params?.endDate ?? params?.to ?? "")
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
