# BodyPress

> **Your Body, Briefed Daily** — AI-powered health insights from your wearable data

BodyPress transforms your wearable device data into personalized, actionable daily briefings. Get contextual health insights combining sleep metrics, HRV, heart rate, weather conditions, air quality, and UV index — all delivered to your inbox every morning.

## ✨ Features

- 🤖 **AI-Powered Analysis** — Intelligent interpretation of your health metrics
- 📊 **Multi-Source Integration** — Connects with popular wearables and fitness trackers
- 🌤️ **Environmental Context** — Combines health data with weather, air quality, and UV index
- 📧 **Daily Email Briefings** — Personalized insights delivered every morning
- 🎨 **Modern UI** — Clean, responsive design with dark mode support
- ⚡ **Fast Performance** — Built with Next.js 16 for optimal speed
- ♿ **Accessible** — WCAG compliant with semantic HTML and ARIA labels

## 🛠️ Tech Stack

- **Framework:** [Next.js 16](https://nextjs.org/) (App Router)
- **Language:** [TypeScript](https://www.typescriptlang.org/)
- **Styling:** [Tailwind CSS 4](https://tailwindcss.com/)
- **UI Components:** [Radix UI](https://www.radix-ui.com/)
- **Icons:** [Lucide React](https://lucide.dev/)
- **Deployment:** [Vercel](https://vercel.com) (recommended)

## 🚀 Getting Started

### Prerequisites

- Node.js 18.x or higher
- npm, yarn, or pnpm

### Installation

1. Clone the repository:
```bash
git clone https://github.com/the-governor-hq/BodyPress.git
cd bodypress
```

2. Install dependencies:
```bash
npm install
# or
yarn install
# or
pnpm install
```

3. Run the development server:
```bash
npm run dev
# or
yarn dev
# or
pnpm dev
```

4. Open [http://localhost:3000](http://localhost:3000) in your browser

## 📁 Project Structure

```
bodypress/
├── app/                    # Next.js app directory
│   ├── layout.tsx         # Root layout with metadata
│   ├── page.tsx           # Homepage
│   ├── globals.css        # Global styles
│   └── sitemap.ts         # SEO sitemap
├── components/            # React components
│   ├── ui/               # Reusable UI components
│   ├── hero.tsx          # Hero section
│   ├── integrations.tsx  # Integration showcase
│   ├── data-cards.tsx    # Data visualization cards
│   ├── how-it-works.tsx  # Feature explanation
│   ├── sample-briefing.tsx # Sample email preview
│   └── cta-section.tsx   # Call-to-action
├── lib/                   # Utility functions
│   └── utils.ts          # Helper utilities
├── public/               # Static assets
│   ├── robots.txt        # SEO robots file
│   └── manifest.json     # PWA manifest
└── styles/               # Additional styles
```

## 🧑‍💻 Development

### Available Scripts

- `npm run dev` — Start development server
- `npm run build` — Build for production
- `npm run start` — Start production server
- `npm run lint` — Run ESLint

### Code Quality

The project uses:
- **TypeScript** for type safety
- **ESLint** for code linting
- **Prettier** configuration (via editor)

## 🌐 Deployment

### Deploy on Vercel

The easiest way to deploy:

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/the-governor-hq/BodyPress)

Or manually:

1. Push your code to GitHub
2. Import your repository on [Vercel](https://vercel.com)
3. Vercel will automatically detect Next.js and configure the build

### Environment Variables

If you add backend functionality, create a `.env.local` file:

```env
# Add your environment variables here
# NEXT_PUBLIC_API_URL=your_api_url
```

## 🎨 Customization

### Updating Content

- **Hero Section:** Edit `components/hero.tsx`
- **Features:** Modify `components/how-it-works.tsx`
- **Integrations:** Update `components/integrations.tsx`
- **Colors & Theme:** Adjust in `app/globals.css`

### SEO Configuration

Update metadata in `app/layout.tsx`:
- Open Graph tags
- Twitter Card configuration
- Meta descriptions and keywords

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

Initial Built using V0, [Next.js](https://nextjs.org/) and [Tailwind CSS](https://tailwindcss.com/)
