"use client"

import { useState, useEffect, Fragment } from "react"
import { useSearchParams } from "next/navigation"
import { motion, AnimatePresence } from "framer-motion"
import { ArrowRight, ArrowLeft, Check } from "lucide-react"
import { WelcomeStep } from "@/components/onboarding/welcome-step"
import { PreferencesStep } from "@/components/onboarding/preferences-step"
import { ConnectDeviceStep } from "@/components/onboarding/connect-device-step"
import { SuccessStep } from "@/components/onboarding/success-step"
import {
  getPendingEmail,
  getOnboardingData,
  setOnboardingData,
  isAuthenticated,
} from "@/lib/auth"
import { updateProfile, requestMagicLink, ApiError } from "@/lib/api"

const STEPS = [
  { id: "welcome", title: "Welcome", component: WelcomeStep },
  { id: "preferences", title: "Preferences", component: PreferencesStep },
  { id: "connect", title: "Connect Device", component: ConnectDeviceStep },
  { id: "success", title: "All Set", component: SuccessStep },
]

export default function OnboardingPage() {
  const searchParams = useSearchParams()
  const [currentStep, setCurrentStep] = useState(0)
  const [submitting, setSubmitting] = useState(false)
  const [formData, setFormData] = useState({
    name: "",
    goals: [] as string[],
    timezone: "",
    device: "",
  })

  // Hydrate from localStorage; handle OAuth return redirect
  useEffect(() => {
    const saved = getOnboardingData()
    if (saved.name || saved.goals || saved.timezone) {
      setFormData((prev) => ({ ...prev, ...saved }))
    }
    const connected = searchParams.get("connected")
    if (connected) {
      setFormData((prev) => ({ ...prev, device: connected }))
      setOnboardingData({ device: connected })
      setCurrentStep(3) // jump to Success
      // Clear onboarding flow flag
      sessionStorage.removeItem("onboarding_flow")
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const handleNext = async () => {
    const isPreferencesStep = currentStep === 1 // 0=welcome, 1=preferences, 2=connect, 3=success
    const isConnectStep = currentStep === 2

    console.log("[Onboarding] Current step:", currentStep, STEPS[currentStep].title)
    console.log("[Onboarding] Form data:", formData)

    // Persist formData to localStorage on every advance
    setOnboardingData(formData)

    if (isPreferencesStep) {
      // After preferences, send magic link if not yet authenticated
      const email = getPendingEmail()
      const authenticated = isAuthenticated()
      console.log("[Onboarding] Preferences step - Email:", email, "Authenticated:", authenticated)
      
      if (email && !authenticated) {
        try {
          console.log("[Onboarding] Requesting magic link for:", email)
          await requestMagicLink(email)
          console.log("[Onboarding] Magic link sent successfully")
        } catch (err) {
          console.error("[Onboarding] Magic link error:", err)
          // Non-blocking — user may already have a valid link
        }
      } else {
        console.log("[Onboarding] Skipping magic link - Email:", !!email, "Not Authenticated:", !authenticated)
      }
    }

    if (isConnectStep && isAuthenticated()) {
      // Save profile before moving to success
      setSubmitting(true)
      console.log("[Onboarding] Connect step - Saving profile...")
      try {
        await updateProfile({
          name: formData.name || undefined,
          goals: formData.goals,
          timezone: formData.timezone || undefined,
          onboardingDone: true,
        })
        console.log("[Onboarding] Profile saved successfully")
      } catch (err) {
        console.error("[Onboarding] Profile update error:", err)
        if (err instanceof ApiError && err.status !== 401) {
          // Still advance on non-auth errors; profile can be updated later
        }
      } finally {
        setSubmitting(false)
      }
    }

    if (currentStep < STEPS.length - 1) {
      setCurrentStep(currentStep + 1)
    }
  }

  const handleBack = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1)
    }
  }

  const updateFormData = (data: Partial<typeof formData>) => {
    setFormData((prev) => ({ ...prev, ...data }))
  }

  const CurrentStepComponent = STEPS[currentStep].component
  const isLastStep = currentStep === STEPS.length - 1

  return (
    <div className="min-h-screen bg-gradient-to-b from-background to-secondary/20 flex items-center justify-center p-4">
      <div className="w-full max-w-2xl">
        {/* Progress Bar */}
        {!isLastStep && (
          <div className="mb-8">
            <div className="flex items-center mb-3">
              {STEPS.slice(0, -1).map((step, index) => (
                <Fragment key={step.id}>
                  <div
                    className="flex flex-col items-center"
                    style={{ minWidth: "fit-content" }}
                  >
                    <div
                      className={`flex items-center justify-center w-8 h-8 rounded-full border-2 transition-all ${
                        index < currentStep
                          ? "bg-primary border-primary text-primary-foreground"
                          : index === currentStep
                          ? "border-primary text-primary"
                          : "border-muted-foreground/30 text-muted-foreground"
                      }`}
                    >
                      {index < currentStep ? (
                        <Check className="w-4 h-4" />
                      ) : (
                        <span className="text-sm font-medium">{index + 1}</span>
                      )}
                    </div>
                    <span
                      className={`mt-2 text-xs whitespace-nowrap ${
                        index === currentStep 
                          ? "text-foreground font-medium" 
                          : "text-muted-foreground"
                      }`}
                    >
                      {step.title}
                    </span>
                  </div>
                  {index < STEPS.length - 2 && (
                    <div
                      className={`flex-1 h-0.5 mx-3 transition-all ${
                        index < currentStep
                          ? "bg-primary"
                          : "bg-muted-foreground/30"
                      }`}
                    />
                  )}
                </Fragment>
              ))}
            </div>
          </div>
        )}

        {/* Step Content */}
        <AnimatePresence mode="wait">
          <motion.div
            key={currentStep}
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.3 }}
          >
            <CurrentStepComponent
              formData={formData}
              updateFormData={updateFormData}
              onNext={handleNext}
              onBack={handleBack}
              isLastStep={isLastStep}
            />
          </motion.div>
        </AnimatePresence>

        {/* Navigation Buttons */}
        {!isLastStep && (
          <div className="flex items-center justify-between mt-6">
            <button
              onClick={handleBack}
              disabled={currentStep === 0}
              className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-muted-foreground hover:text-foreground disabled:opacity-0 transition-all"
            >
              <ArrowLeft className="w-4 h-4" />
              Back
            </button>

            <button
              onClick={handleNext}
              disabled={submitting}
              className="group inline-flex items-center gap-2 px-6 py-2.5 rounded-lg bg-primary text-primary-foreground text-sm font-semibold hover:brightness-110 transition-all disabled:opacity-60"
            >
              {submitting ? "Finishing…" : currentStep === STEPS.length - 2 ? "Finish" : "Continue"}
              {!submitting && <ArrowRight className="w-4 h-4 transition-transform group-hover:translate-x-0.5" />}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
