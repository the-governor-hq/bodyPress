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
