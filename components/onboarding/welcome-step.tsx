"use client"

import { useState, useEffect } from "react"
import { Sparkles } from "lucide-react"

interface WelcomeStepProps {
  formData: { name: string }
  updateFormData: (data: { name: string }) => void
  onNext?: () => void
  onBack?: () => void
  isLastStep?: boolean
}

export function WelcomeStep({ formData, updateFormData }: WelcomeStepProps) {
  const [name, setName] = useState(formData.name)

  useEffect(() => {
    updateFormData({ name })
  }, [name])

  return (
    <div className="bg-card border border-border rounded-2xl p-6 md:p-10">
      <div className="text-center mb-6">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary/10 text-primary mb-4">
          <Sparkles className="w-8 h-8" />
        </div>
        <h1 className="text-3xl md:text-4xl font-bold tracking-tight mb-2">
          Welcome to BodyPress
        </h1>
        <p className="text-muted-foreground text-lg max-w-md mx-auto">
          Let's personalize your experience in just a few quick steps
        </p>
      </div>

      <div className="max-w-md mx-auto space-y-4">
        <div>
          <label
            htmlFor="name"
            className="block text-sm font-medium text-foreground mb-2"
          >
            What should we call you?
          </label>
          <input
            id="name"
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Enter your name"
            className="w-full rounded-lg border border-border bg-background px-4 py-3 text-foreground placeholder:text-muted-foreground focus:border-primary focus:ring-2 focus:ring-primary/20 focus:outline-none transition-all"
            autoFocus
          />
        </div>

        <p className="text-xs text-muted-foreground text-center pt-2">
          This helps us create a more personal experience for you
        </p>
      </div>
    </div>
  )
}
