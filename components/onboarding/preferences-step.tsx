"use client"

import { useState, useEffect } from "react"
import { Target, Heart, Zap, Brain, Moon, Activity, Check } from "lucide-react"

interface PreferencesStepProps {
  formData: { goals: string[], timezone: string }
  updateFormData: (data: { goals: string[], timezone: string }) => void
  onNext?: () => void
  onBack?: () => void
  isLastStep?: boolean
}

const GOALS = [
  { id: "performance", label: "Athletic Performance", icon: Zap },
  { id: "recovery", label: "Better Recovery", icon: Heart },
  { id: "sleep", label: "Improve Sleep", icon: Moon },
  { id: "stress", label: "Manage Stress", icon: Brain },
  { id: "fitness", label: "General Fitness", icon: Activity },
  { id: "health", label: "Track Health", icon: Target },
]

const TIMEZONES = [
  { value: "America/New_York", label: "Eastern Time (ET)" },
  { value: "America/Chicago", label: "Central Time (CT)" },
  { value: "America/Denver", label: "Mountain Time (MT)" },
  { value: "America/Los_Angeles", label: "Pacific Time (PT)" },
  { value: "Europe/London", label: "London (GMT)" },
  { value: "Europe/Paris", label: "Paris (CET)" },
  { value: "Asia/Tokyo", label: "Tokyo (JST)" },
  { value: "Australia/Sydney", label: "Sydney (AEDT)" },
]

export function PreferencesStep({ formData, updateFormData }: PreferencesStepProps) {
  const [selectedGoals, setSelectedGoals] = useState<string[]>(formData.goals)
  const [timezone, setTimezone] = useState(formData.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone)

  useEffect(() => {
    updateFormData({ goals: selectedGoals, timezone })
  }, [selectedGoals, timezone])

  const toggleGoal = (goalId: string) => {
    setSelectedGoals((prev) =>
      prev.includes(goalId)
        ? prev.filter((id) => id !== goalId)
        : [...prev, goalId]
    )
  }

  return (
    <div className="bg-card border border-border rounded-2xl p-6 md:p-10">
      <div className="mb-6">
        <h2 className="text-2xl md:text-3xl font-bold tracking-tight mb-2">
          What are your goals?
        </h2>
        <p className="text-muted-foreground">
          Select all that apply. We'll tailor your insights accordingly.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-6">
        {GOALS.map((goal) => {
          const Icon = goal.icon
          const isSelected = selectedGoals.includes(goal.id)
          
          return (
            <button
              key={goal.id}
              onClick={() => toggleGoal(goal.id)}
              className={`relative flex items-center gap-3 p-4 rounded-lg border-2 transition-all text-left ${
                isSelected
                  ? "border-primary bg-primary/5"
                  : "border-border hover:border-primary/50 bg-background"
              }`}
            >
              <div
                className={`flex items-center justify-center w-10 h-10 rounded-lg transition-colors ${
                  isSelected
                    ? "bg-primary text-primary-foreground"
                    : "bg-secondary text-muted-foreground"
                }`}
              >
                <Icon className="w-5 h-5" />
              </div>
              <span className="font-medium text-sm">{goal.label}</span>
              {isSelected && (
                <Check className="absolute top-3 right-3 w-5 h-5 text-primary" />
              )}
            </button>
          )
        })}
      </div>

      <div>
        <label
          htmlFor="timezone"
          className="block text-sm font-medium text-foreground mb-2"
        >
          When should we send your daily briefing?
        </label>
        <select
          id="timezone"
          value={timezone}
          onChange={(e) => setTimezone(e.target.value)}
          className="w-full rounded-lg border border-border bg-background px-4 py-3 text-foreground focus:border-primary focus:ring-2 focus:ring-primary/20 focus:outline-none transition-all"
        >
          {TIMEZONES.map((tz) => (
            <option key={tz.value} value={tz.value}>
              {tz.label}
            </option>
          ))}
        </select>
        <p className="text-xs text-muted-foreground mt-2">
          We'll send your personalized briefing every morning at 7 AM
        </p>
      </div>
    </div>
  )
}
