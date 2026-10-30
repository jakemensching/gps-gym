import Link from "next/link";

const steps = [
  { icon: "🎯", title: "Tell us your goal", body: "Goal, experience, schedule, equipment. Sixty seconds." },
  { icon: "📋", title: "Get your plan", body: "A real program — split, sets, reps, rest, and progression rules." },
  { icon: "🔒", title: "Apps lock on training days", body: "On iPhone, TikTok and Instagram stay locked until you train." },
  { icon: "📍", title: "Train & verify", body: "Time + logged sets + a private gym check-in unlock your apps." },
];

export default function Landing() {
  return (
    <main className="container" style={{ maxWidth: 880 }}>
      <section className="hero">
        <span className="eyebrow">GPS-GYM</span>
        <h1>
          Want to scroll?<br />
          <span>Earn it.</span>
        </h1>
        <p className="muted" style={{ fontSize: 20, maxWidth: 560 }}>
          A training plan built for your goal, and your most distracting apps locked until you work out.
        </p>
        <div className="row" style={{ maxWidth: 420, flexWrap: "wrap" }}>
          <Link href="/app" className="btn btn-primary" style={{ flex: 1 }}>
            Build my plan — free
          </Link>
        </div>
        <p className="small muted">
          The web app runs your plan, workout logging and progress. App blocking needs the iPhone app (beta coming soon) —
          browsers can&apos;t lock other apps.
        </p>
      </section>

      <section className="feature-grid">
        {steps.map((s) => (
          <div className="card" key={s.title}>
            <div style={{ fontSize: 28 }}>{s.icon}</div>
            <h3>{s.title}</h3>
            <p className="muted small">{s.body}</p>
          </div>
        ))}
      </section>

      <section className="card" style={{ marginTop: 24 }}>
        <h3>Privacy first</h3>
        <p className="muted small">
          We only check location during a workout, and we store your distance from your gym — never your location history.
          Your plan and workouts live on your device.
        </p>
      </section>
    </main>
  );
}
