const features = [
  {
    icon: "🔐",
    title: "Authentication",
    desc: "OAuth 2.0, Magic Links, 2FA, TOTP, API keys, and RBAC — all pre-wired.",
  },
  {
    icon: "💳",
    title: "Payments",
    desc: "Stripe subscriptions, webhooks, and billing portal out of the box.",
  },
  {
    icon: "🗄️",
    title: "Database",
    desc: "30+ Prisma models, PostgreSQL, migrations, and seed data ready to go.",
  },
  {
    icon: "👥",
    title: "Multi-Tenancy",
    desc: "Organizations, teams, roles, and invitations built in from day one.",
  },
  {
    icon: "🤖",
    title: "AI Integration",
    desc: "5 providers pre-wired. Audio, vision, and chat — just add your API key.",
  },
  {
    icon: "🛡️",
    title: "GDPR Compliance",
    desc: "Consent management, data export, and right-to-deletion included.",
  },
];

const techStack = [
  "Next.js 16",
  "React 19",
  "TypeScript 5",
  "Tailwind CSS",
  "Prisma 6",
  "tRPC",
  "Stripe",
  "Supabase",
  "Resend",
  "Docker",
];

const freeTools = [
  { name: "TOS Generator", desc: "Generate your Terms of Service" },
  { name: "OG Image Generator", desc: "Social preview images in seconds" },
  { name: "Domain Ideas", desc: "Find your perfect .com" },
  { name: "ENV Builder", desc: "Build your .env file visually" },
  { name: "SaaS Architect", desc: "Plan your SaaS architecture" },
  { name: "Tailwind Config", desc: "Custom Tailwind presets" },
];

export default function Home() {
  return (
    <main className="flex flex-col items-center">
      {/* Nav */}
      <nav className="w-full max-w-6xl mx-auto flex items-center justify-between px-6 py-5">
        <span className="text-xl font-bold tracking-tight">
          <span className="text-white">Boiler</span>
          <span className="text-orange-400">Forge</span>
        </span>
        <div className="flex items-center gap-6 text-sm text-neutral-400">
          <a href="#features" className="hover:text-white transition">
            Features
          </a>
          <a href="#tools" className="hover:text-white transition">
            Free Tools
          </a>
          <a
            href="https://boilerforge.com"
            target="_blank"
            rel="noopener noreferrer"
            className="bg-orange-500 text-black font-semibold px-4 py-2 rounded-lg hover:bg-orange-400 transition"
          >
            Get BoilerForge — $97
          </a>
        </div>
      </nav>

      {/* Hero */}
      <section className="w-full max-w-4xl mx-auto text-center px-6 pt-20 pb-16">
        <div className="inline-block mb-6 px-4 py-1.5 rounded-full bg-orange-500/10 border border-orange-500/20 text-orange-400 text-sm font-medium">
          Save 40+ hours of headaches
        </div>
        <h1 className="text-5xl sm:text-6xl font-bold tracking-tight leading-tight mb-6">
          Stop configuring.
          <br />
          <span className="text-orange-400">Start shipping.</span>
        </h1>
        <p className="text-lg text-neutral-400 max-w-2xl mx-auto mb-10 leading-relaxed">
          The complete Next.js SaaS boilerplate with auth, payments,
          multi-tenancy, AI integration, and GDPR compliance pre-built.
          120+ files. 200+ features. One purchase.
        </p>
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href="https://boilerforge.com"
            target="_blank"
            rel="noopener noreferrer"
            className="bg-orange-500 text-black font-bold px-8 py-3.5 rounded-lg text-lg hover:bg-orange-400 transition shadow-lg shadow-orange-500/20"
          >
            Get the code — $97
          </a>
          <a
            href="#features"
            className="border border-neutral-700 text-neutral-300 font-medium px-8 py-3.5 rounded-lg text-lg hover:border-neutral-500 hover:text-white transition"
          >
            See what&apos;s inside
          </a>
        </div>
      </section>

      {/* Tech Stack Bar */}
      <section className="w-full border-y border-neutral-800 py-8">
        <div className="max-w-6xl mx-auto flex flex-wrap items-center justify-center gap-x-8 gap-y-3 px-6">
          {techStack.map((tech) => (
            <span
              key={tech}
              className="text-sm text-neutral-500 font-mono tracking-wide"
            >
              {tech}
            </span>
          ))}
        </div>
      </section>

      {/* Features Grid */}
      <section id="features" className="w-full max-w-6xl mx-auto px-6 py-20">
        <h2 className="text-3xl font-bold text-center mb-4">
          Everything you need. Nothing you don&apos;t.
        </h2>
        <p className="text-neutral-400 text-center mb-12 max-w-xl mx-auto">
          Production-ready features that would take weeks to build from scratch.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((f) => (
            <div
              key={f.title}
              className="border border-neutral-800 rounded-xl p-6 hover:border-neutral-700 transition bg-neutral-900/50"
            >
              <div className="text-3xl mb-3">{f.icon}</div>
              <h3 className="text-lg font-semibold mb-2">{f.title}</h3>
              <p className="text-neutral-400 text-sm leading-relaxed">
                {f.desc}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* Free Tools */}
      <section
        id="tools"
        className="w-full max-w-6xl mx-auto px-6 py-20 border-t border-neutral-800"
      >
        <h2 className="text-3xl font-bold text-center mb-4">
          Free tools for SaaS builders
        </h2>
        <p className="text-neutral-400 text-center mb-12 max-w-xl mx-auto">
          No account needed. Use them right now.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {freeTools.map((t) => (
            <a
              key={t.name}
              href="https://boilerforge.com"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-4 border border-neutral-800 rounded-lg p-4 hover:border-orange-500/30 hover:bg-orange-500/5 transition"
            >
              <span className="text-orange-400 text-xl">&#9881;</span>
              <div>
                <div className="font-medium text-sm">{t.name}</div>
                <div className="text-xs text-neutral-500">{t.desc}</div>
              </div>
            </a>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="w-full max-w-4xl mx-auto text-center px-6 py-20 border-t border-neutral-800">
        <h2 className="text-3xl font-bold mb-4">
          Ship your SaaS this weekend.
        </h2>
        <p className="text-neutral-400 mb-8 max-w-lg mx-auto">
          Pay once. Own forever. Unlimited projects. 30-day money-back
          guarantee.
        </p>
        <a
          href="https://boilerforge.com"
          target="_blank"
          rel="noopener noreferrer"
          className="inline-block bg-orange-500 text-black font-bold px-10 py-4 rounded-lg text-lg hover:bg-orange-400 transition shadow-lg shadow-orange-500/20"
        >
          Get BoilerForge — $97
        </a>
      </section>

      {/* Footer */}
      <footer className="w-full border-t border-neutral-800 py-8">
        <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between px-6 gap-4">
          <span className="text-sm text-neutral-500">
            Built by{" "}
            <span className="text-neutral-300 font-medium">Josue Barros</span>{" "}
            — deployed to Azure with Terraform
          </span>
          <span className="text-sm text-neutral-600">
            Part of the{" "}
            <span className="text-neutral-400">
              Azure for SaaS Developers
            </span>{" "}
            series on YouTube
          </span>
        </div>
      </footer>
    </main>
  );
}
