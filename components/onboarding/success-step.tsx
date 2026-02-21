"use client"

import { useEffect } from "react"
import { useRouter } from "next/navigation"
import { CheckCircle2, Sparkles } from "lucide-react"
import { motion } from "framer-motion"
import confetti from "canvas-confetti"

interface SuccessStepProps {
  formData: { name: string; device: string }
  updateFormData?: (data: any) => void
  onNext?: () => void
  onBack?: () => void
  isLastStep?: boolean
}

export function SuccessStep({ formData }: SuccessStepProps) {
  const router = useRouter()

  useEffect(() => {
    // Trigger confetti
    confetti({
      particleCount: 100,
      spread: 70,
      origin: { y: 0.6 },
    })

    // Redirect to dashboard after 3 seconds
    const timeout = setTimeout(() => {
      router.push("/dashboard")
    }, 3000)

    return () => clearTimeout(timeout)
  }, [router])

  return (
    <div className="bg-card border border-border rounded-2xl p-8 md:p-12">
      <motion.div
        initial={{ scale: 0 }}
        animate={{ scale: 1 }}
        transition={{ type: "spring", duration: 0.6 }}
        className="text-center"
      >
        <div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-primary/10 text-primary mb-6">
          <CheckCircle2 className="w-12 h-12" />
        </div>

        <h1 className="text-3xl md:text-4xl font-bold tracking-tight mb-3">
          You're all set{formData.name ? `, ${formData.name}` : ""}!
        </h1>

        <p className="text-muted-foreground text-lg mb-8 max-w-md mx-auto">
          Your first daily briefing will arrive tomorrow morning with
          personalized insights from your{" "}
          {formData.device === "garmin"
            ? "Garmin"
            : formData.device === "fitbit"
            ? "Fitbit"
            : "device"}
          .
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 max-w-2xl mx-auto mb-8">
          {[
            {
              icon: "📊",
              title: "Data Syncing",
              desc: "We're pulling your latest metrics",
            },
            {
              icon: "🤖",
              title: "AI Learning",
              desc: "Understanding your baseline",
            },
            {
              icon: "✉️",
              title: "Briefing Ready",
              desc: "Tomorrow at 7 AM",
            },
          ].map((item, index) => (
            <motion.div
              key={item.title}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 + index * 0.1 }}
              className="p-4 rounded-lg bg-secondary/50 border border-border"
            >
              <div className="text-2xl mb-2">{item.icon}</div>
              <h3 className="font-semibold text-sm mb-1">{item.title}</h3>
              <p className="text-xs text-muted-foreground">{item.desc}</p>
            </motion.div>
          ))}
        </div>

        <div className="inline-flex items-center gap-2 text-sm text-muted-foreground">
          <Sparkles className="w-4 h-4" />
          Redirecting you to the dashboard...
        </div>
      </motion.div>
    </div>
  )
}
