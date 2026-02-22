import type { Metadata, Viewport } from 'next'
import { Inter, Space_Mono } from 'next/font/google'
import { ThemeProvider } from '@/components/theme-provider'
import { ReactQueryProvider } from '@/components/react-query-provider'
import { Toaster } from '@/components/ui/toaster'
import './globals.css'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
})

const spaceMono = Space_Mono({
  subsets: ['latin'],
  weight: ['400', '700'],
  variable: '--font-space-mono',
})

export const metadata: Metadata = {
  title: {
    default: 'BodyPress — Your Body, Briefed Daily',
    template: '%s | BodyPress',
  },
  description:
    'AI-powered daily briefing that turns your wearable data into actionable health insights. Sleep, HRV, heart rate, weather, air quality — all in one newsletter.',
  keywords: [
    'health briefing',
    'wearable data',
    'AI health insights',
    'sleep tracking',
    'HRV monitoring',
    'heart rate tracking',
    'health analytics',
    'daily health report',
    'fitness tracking',
    'wellness newsletter',
  ],
  authors: [{ name: 'BodyPress' }],
  creator: 'BodyPress',
  publisher: 'BodyPress',
  metadataBase: new URL('https://bodypress.app'),
  alternates: {
    canonical: '/',
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://bodypress.app',
    title: 'BodyPress — Your Body, Briefed Daily',
    description:
      'AI-powered daily briefing that turns your wearable data into actionable health insights. Sleep, HRV, heart rate, weather, air quality — all in one newsletter.',
    siteName: 'BodyPress',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'BodyPress - AI-Powered Health Briefings',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'BodyPress — Your Body, Briefed Daily',
    description:
      'AI-powered daily briefing that turns your wearable data into actionable health insights.',
    images: ['/og-image.png'],
    creator: '@bodypress',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  icons: {
    icon: [
      {
        url: '/icon-light-32x32.png',
        media: '(prefers-color-scheme: light)',
      },
      {
        url: '/icon-dark-32x32.png',
        media: '(prefers-color-scheme: dark)',
      },
      {
        url: '/icon.svg',
        type: 'image/svg+xml',
      },
    ],
    apple: '/apple-icon.png',
  },
  manifest: '/manifest.json',
}

export const viewport: Viewport = {
  themeColor: '#141520',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${inter.variable} ${spaceMono.variable} font-sans antialiased`}
      >
        <ReactQueryProvider>
          <ThemeProvider
            attribute="class"
            defaultTheme="system"
            enableSystem
            disableTransitionOnChange
          >
            {children}
            <Toaster />
          </ThemeProvider>
        </ReactQueryProvider>
      </body>
    </html>
  )
}
