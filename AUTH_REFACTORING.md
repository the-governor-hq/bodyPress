# Authentication Refactoring - Documentation

## Overview

The authentication system has been refactored to be more robust, consistent, and user-friendly. This document outlines the changes and new features.

## Key Improvements

### 1. **Network Error Handling**
- Network errors are now properly detected and reported to users
- Automatic retry logic with exponential backoff for failed requests
- Visual indicators when the user is offline
- Toast notifications for connection issues
- Retry buttons when network errors occur

### 2. **Unified State Management**
- Centralized auth store with error tracking
- Session store for persistent data
- Consistent auth state across the app
- React Query integration for better data fetching and caching

### 3. **Consistent Redirects**
- Centralized redirect utilities in `lib/auth-navigation.ts`
- Consistent navigation throughout auth flows
- Proper route protection

### 4. **Enhanced API Client**
- Automatic retry with `axios-retry`
- Configurable retry conditions
- Better error classification (network vs. API errors)
- User-friendly error messages
- Detailed logging in development mode

### 5. **Improved User Experience**
- Real-time network status detection
- Toast notifications for errors and success states
- Loading states during async operations
- Clear error messages instead of console logs
- Offline indicators

## New Files

### `hooks/use-network-status.ts`
Detects online/offline status and provides real-time updates.

**Usage:**
```tsx
const { isOnline, wasOffline } = useNetworkStatus()
```

### `lib/auth-navigation.ts`
Centralized authentication navigation utilities.

**Usage:**
```tsx
import { AUTH_ROUTES, getAuthenticatedRedirect } from '@/lib/auth-navigation'

router.push(AUTH_ROUTES.DASHBOARD)
const redirect = getAuthenticatedRedirect(hasConnectedDevice)
```

### `components/react-query-provider.tsx`
TanStack Query provider for better data fetching and caching.

**Features:**
- Automatic retries for failed requests
- Smart retry logic (don't retry 4xx errors except 408/429)
- Configurable stale time and cache time
- Refetch on window focus and reconnect

## Updated Files

### `lib/api.ts`
**Changes:**
- Added `axios-retry` for automatic retries
- Added `isNetworkError()` helper function
- Added `getUserFriendlyErrorMessage()` for user-facing error messages
- Enhanced `ApiError` class with `isNetworkError` flag
- Better error interceptor with network error detection

**New Functions:**
```tsx
// Check if an error is a network error
isNetworkError(error): boolean

// Get user-friendly error message
getUserFriendlyErrorMessage(error): string
```

### `lib/auth-store.ts`
**Changes:**
- Added error state tracking
- Added `lastError` with timestamp and network error flag
- Added `setError()` and `clearError()` methods
- Improved signOut to clear all auth data including onboarding

**New Properties:**
```tsx
type AuthError = {
  message: string
  isNetworkError: boolean
  timestamp: number
}

// Store properties
lastError: AuthError | null
setError(message, isNetworkError?)
clearError()
```

### `hooks/use-auth-session.ts`
**Changes:**
- Integrated network status detection
- Added error state and tracking
- Toast notifications for errors
- Automatic retry when connection is restored
- Better error handling with user-friendly messages

**New Returns:**
```tsx
{
  // ... existing properties
  error: string | null,
  isOnline: boolean,
}
```

### Authentication Pages

#### `app/auth/verify/page.tsx`
- Network error detection and handling
- Retry functionality when offline
- Visual offline indicator
- User-friendly error states
- Uses centralized redirect utilities

#### `app/auth/verify-email/page.tsx`
- Uses centralized redirect utilities

#### `app/oauth/callback/page.tsx`
- Better error handling with toast notifications
- Uses centralized redirect utilities
- Success toast on connection

#### `app/onboarding/page.tsx`
- Network status indicator
- Better error handling for profile updates
- Toast notifications for errors
- Uses centralized redirect utilities
- Offline warning banner

### `app/layout.tsx`
- Added `ReactQueryProvider` wrapper for TanStack Query

## Error Handling Flow

### 1. Network Errors
```
User Action → API Call → Network Error
  ↓
ApiError (isNetworkError: true)
  ↓
Toast Notification + Error State
  ↓
User sees: "Unable to connect to the server. Please check your internet connection."
  ↓
If online again → Auto-retry
```

### 2. API Errors (4xx/5xx)
```
User Action → API Call → API Error
  ↓
ApiError (status code)
  ↓
User-friendly message based on status
  ↓
- 401: "Your session has expired. Please sign in again."
- 403: "You don't have permission to perform this action."
- 404: "The requested resource was not found."
- 5xx: "A server error occurred. Please try again later."
```

### 3. Auth Errors (401)
```
API returns 401 → signOut() → Clear all auth data → Redirect to home
```

## Retry Logic

### API Requests
- **Retries:** 3 attempts
- **Delay:** Exponential backoff (1s, 2s, 4s)
- **Conditions:** Network errors and 5xx server errors

### React Query
- **Queries:** Up to 3 retries for network/5xx errors
- **No retry on:** 4xx errors (except 408, 429)
- **Stale time:** 5 minutes
- **Cache time:** 10 minutes

## Best Practices

### 1. Always Use Centralized Redirects
```tsx
// ❌ Don't
router.push('/dashboard')

// ✅ Do
import { AUTH_ROUTES } from '@/lib/auth-navigation'
router.push(AUTH_ROUTES.DASHBOARD)
```

### 2. Handle Errors Properly
```tsx
try {
  await someApiCall()
} catch (err) {
  const message = getUserFriendlyErrorMessage(err)
  const isNetworkErr = isNetworkError(err)
  
  toast({
    title: isNetworkErr ? "Connection Error" : "Error",
    description: message,
    variant: "destructive",
  })
}
```

### 3. Use Network Status Hook
```tsx
const { isOnline, wasOffline } = useNetworkStatus()

if (!isOnline) {
  // Show offline UI
}

if (wasOffline && isOnline) {
  // Connection restored - retry
}
```

### 4. Use Auth Session Hook
```tsx
const { isAuthed, loading, error, isOnline } = useAuthSession()

if (error) {
  // Error state is already handled with toasts
  // Just show appropriate UI
}
```

## Migration Guide

### For Existing Components

If you have components using the old auth system:

**Before:**
```tsx
const { isAuthed } = useAuthSession()
// Manual error handling with console.log
```

**After:**
```tsx
const { isAuthed, error, isOnline } = useAuthSession()
// Errors automatically shown via toast
// Can check error/isOnline for UI adjustments
```

### For API Calls

**Before:**
```tsx
try {
  await updateProfile(data)
} catch (err) {
  console.error(err)
  // No user feedback
}
```

**After:**
```tsx
import { getUserFriendlyErrorMessage, isNetworkError } from '@/lib/api'

try {
  await updateProfile(data)
  toast({ title: "Success", description: "Profile updated" })
} catch (err) {
  const message = getUserFriendlyErrorMessage(err)
  const isNetworkErr = isNetworkError(err)
  
  toast({
    title: isNetworkErr ? "Connection Error" : "Error",
    description: message,
    variant: "destructive",
  })
}
```

## Testing Offline Scenarios

To test offline functionality:

1. **Chrome DevTools:**
   - Open DevTools (F12)
   - Go to Network tab
   - Check "Offline" checkbox

2. **Test Cases:**
   - Sign in while offline
   - Navigate pages while offline
   - Go offline during API call
   - Come back online (should auto-retry)

## Dependencies Added

- `@tanstack/react-query` - Better data fetching and caching
- `axios-retry` - Automatic retry logic for API calls

## Future Enhancements

- [ ] Add request deduplication
- [ ] Implement optimistic updates with React Query
- [ ] Add request/response caching layers
- [ ] Implement token refresh before expiration
- [ ] Add rate limiting detection and handling
- [ ] Implement exponential backoff for auth attempts
