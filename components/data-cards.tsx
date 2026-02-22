"use client"

import {
  Moon,
  Heart,
  Activity,
  Thermometer,
  Wind,
  Sun,
} from "lucide-react"

const metrics = [
  {
    label: "Sleep Score",
    value: "87",
    unit: "/100",
    change: "+4",
    icon: Moon,
    color: "text-chart-2",
    bgColor: "bg-chart-2/10",
    borderColor: "border-chart-2/20",
  },
  {
    label: "HRV",
    value: "62",
    unit: "ms",
    change: "+8",
    icon: Activity,
    color: "text-primary",
    bgColor: "bg-primary/10",
    borderColor: "border-primary/20",
  },
  {
    label: "Resting HR",
    value: "58",
    unit: "bpm",
    change: "-2",
    icon: Heart,
    color: "text-chart-5",
    bgColor: "bg-chart-5/10",
    borderColor: "border-chart-5/20",
  },
  {
    label: "Temperature",
    value: "72",
    unit: "\u00b0F",
    change: "",
    icon: Thermometer,
    color: "text-chart-4",
    bgColor: "bg-chart-4/10",
    borderColor: "border-chart-4/20",
  },
  {
    label: "Air Quality",
    value: "42",
    unit: "AQI",
    change: "Good",
    icon: Wind,
    color: "text-primary",
    bgColor: "bg-primary/10",
    borderColor: "border-primary/20",
  },
  {
    label: "UV Index",
    value: "6",
    unit: "Moderate",
    change: "",
    icon: Sun,
    color: "text-chart-4",
    bgColor: "bg-chart-4/10",
    borderColor: "border-chart-4/20",
  },
]

export function DataCards() {
  return (
    <section className="px-4 py-12 sm:px-6 sm:py-16">
      <div className="mx-auto max-w-5xl">
        <div className="mb-8 sm:mb-10 text-center">
          <h2 className="text-balance text-2xl sm:text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            All your signals, one briefing
          </h2>
          <p className="mx-auto mt-3 sm:mt-4 max-w-lg text-sm sm:text-base text-pretty leading-relaxed text-muted-foreground">
            We pull data from your smartwatch and cross-reference it with
            real-time environmental factors from your location.
          </p>
        </div>

        <div className="grid grid-cols-2 gap-2.5 sm:gap-3 md:grid-cols-3 md:gap-4">
          {metrics.map((m) => (
            <div
              key={m.label}
              className={`group relative overflow-hidden rounded-xl border ${m.borderColor} ${m.bgColor} p-3 sm:p-4 transition-all hover:scale-[1.02]`}
            >
              <div className="flex items-center gap-1.5 sm:gap-2">
                <m.icon className={`h-3.5 w-3.5 sm:h-4 sm:w-4 ${m.color}`} />
                <span className="font-mono text-[10px] sm:text-xs tracking-wider text-muted-foreground uppercase">
                  {m.label}
                </span>
              </div>
              <div className="mt-2 sm:mt-3 flex items-baseline gap-1">
                <span className={`text-2xl sm:text-3xl font-bold ${m.color}`}>
                  {m.value}
                </span>
                <span className="text-xs sm:text-sm text-muted-foreground">{m.unit}</span>
              </div>
              {m.change && (
                <span className="mt-1.5 sm:mt-2 inline-block font-mono text-[10px] sm:text-xs text-muted-foreground">
                  {m.change}
                </span>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
