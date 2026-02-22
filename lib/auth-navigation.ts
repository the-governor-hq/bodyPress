/**
 * Centralized authentication navigation utilities
 * Provides consistent redirect behavior across the app
 */

export const AUTH_ROUTES = {
  HOME: "/",
  DASHBOARD: "/dashboard",
  ONBOARDING: "/onboarding",
  VERIFY_EMAIL: "/auth/verify-email",
  OAUTH_CALLBACK: "/oauth/callback",
} as const

export type AuthRoute = (typeof AUTH_ROUTES)[keyof typeof AUTH_ROUTES]

/**
 * Determines where to redirect an authenticated user based on their state
 */
export function getAuthenticatedRedirect(hasConnectedDevice: boolean): string {
  return hasConnectedDevice ? AUTH_ROUTES.DASHBOARD : AUTH_ROUTES.ONBOARDING
}

/**
 * Determines where to redirect an unauthenticated user
 */
export function getUnauthenticatedRedirect(): string {
  return AUTH_ROUTES.HOME
}

/**
 * Check if a route requires authentication
 */
export function requiresAuth(pathname: string): boolean {
  const protectedRoutes = [
    AUTH_ROUTES.DASHBOARD,
    AUTH_ROUTES.ONBOARDING,
  ]
  
  return protectedRoutes.some(route => pathname.startsWith(route))
}

/**
 * Check if a route is an auth-related page
 */
export function isAuthRoute(pathname: string): boolean {
  return pathname.startsWith("/auth/") || pathname.startsWith("/oauth/")
}
