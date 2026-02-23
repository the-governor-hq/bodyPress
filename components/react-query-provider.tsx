"use client"

import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { useState } from "react"

export function ReactQueryProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            // Retry failed requests
            retry: (failureCount, error: any) => {
              // Don't retry on 4xx errors (except 408 Request Timeout and 429 Too Many Requests)
              if (error?.status >= 400 && error?.status < 500 && 
                  error?.status !== 408 && error?.status !== 429) {
                return false
              }
              // Retry up to 3 times for network errors or 5xx errors
              return failureCount < 3
            },
            retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
            // Stale time: 5 minutes
            staleTime: 5 * 60 * 1000,
            // Cache time: 10 minutes
            gcTime: 10 * 60 * 1000,
            // Refetch on window focus for important data
            refetchOnWindowFocus: true,
            // Refetch on reconnect
            refetchOnReconnect: true,
          },
          mutations: {
            // Retry mutations on network errors
            retry: (failureCount, error: any) => {
              if (error?.isNetworkError && failureCount < 2) {
                return true
              }
              return false
            },
          },
        },
      })
  )

  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
}
