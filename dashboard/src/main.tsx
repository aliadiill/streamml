import React, {useEffect, useState} from "react";
import {createRoot} from "react-dom/client";
import {completeLogin, demoOnly, login, logout, token} from "./auth";
import "./style.css";

type Transaction = {id: string; at: string; amount: number; anomaly: boolean};
type Metrics = {window_minutes: number; generated_at: string; event_count: number; amount_cents: number; anomalies: number; detector: string; events: Transaction[]};
const sample: Metrics = {window_minutes: 60, generated_at: "2026-01-01T01:00:00Z", event_count: 1800,
  amount_cents: 17893024, anomalies: 42, detector: "bootstrap business rules", events: Array.from({length: 8}, (_, i) => ({
    id: "sample-" + (9200 + i), at: "2026-01-01T00:" + String(59 - i).padStart(2, "0") + ":00Z",
    amount: [3204.81, 86.2, 42.93, 1298.4, 210.12, 78, 44.5, 114.79][i], anomaly: i === 0 || i === 3}))};
const money = (n: number) => new Intl.NumberFormat("en-US", {style: "currency", currency: "USD", maximumFractionDigits: 0}).format(n);
function App() {
  const [data, setData] = useState<Metrics | null>(null);
  const [preview, setPreview] = useState(demoOnly);
  const [signedIn, setSignedIn] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  useEffect(() => {if (demoOnly) {setLoading(false); return;} completeLogin().then(() => setSignedIn(Boolean(token()))).catch((e: Error) => setError(e.message)).finally(() => setLoading(false));}, []);
  useEffect(() => {
    if (demoOnly || !signedIn || preview) return;
    let cancelled = false;
    const refresh = async () => {
      const access = token();
      if (!access) {setSignedIn(false); setError("Your session expired. Sign in again."); return;}
      try {
        const response = await fetch((import.meta.env.VITE_API_URL || "") + "/api/metrics", {headers: {Authorization: "Bearer " + access}});
        if (!response.ok) throw new Error(response.status === 401 ? "Session expired. Sign in again." : "Metrics unavailable. Retrying in 10 seconds.");
        const value: Metrics = await response.json();
        if (!cancelled) {setData(value); setError("");}
      } catch (e) {if (!cancelled) setError((e as Error).message);}
    };
    void refresh();
    const timer = setInterval(() => void refresh(), 10000);
    return () => {cancelled = true; clearInterval(timer);};
  }, [signedIn, preview]);
  const shown = preview ? sample : data;
  return <div className="shell">
    <aside><a className="brand" href={import.meta.env.BASE_URL}>S<span>∿</span><strong>StreamML</strong></a><p className="overline">INTELLIGENCE WORKSPACE</p>
      <a className="nav active" href="#overview">◉ <span>Live overview</span></a><a className="nav" href="#transactions">⇄ <span>Transactions</span></a><a className="nav" href="#governance">◇ <span>Model governance</span></a>
      <div className="rail-bottom"><span className="dot"/> Transaction anomaly lab<br/><small>us-east-1 · development</small></div>
    </aside>
    <main><header><span>OPERATIONS / OVERVIEW</span><div className="header-actions">{preview && <span className="sample-tag">SAMPLE DATA</span>}
      {demoOnly ? <span className="muted">Portfolio preview</span> : signedIn ? <button onClick={logout}>Sign out</button> : <button onClick={() => login().catch((e: Error) => setError(e.message))}>Sign in with Cognito ↗</button>}</div></header>
      <section id="overview" className="heading"><div><p className="overline">STREAMING ANALYTICS</p><h1>Every transaction.<br/><span>A clearer signal.</span></h1><p className="muted">A bounded transaction stream with accountable model decisions.</p></div><div className="status"><span className="dot"/>{preview ? "Sample preview" : signedIn ? "Authenticated workspace" : "AWS connection required"}<small>{shown ? "Window: last 60 minutes" : "No live cloud results yet"}</small></div></section>
      {error && <div role="alert" className="alert">{error}</div>}
      {!signedIn && !preview && <section className="welcome"><div><h2>Explore the workspace</h2><p>Sign in to read deployed metrics, or open an explicitly labelled interface preview. The preview contains illustrative values and makes no AWS calls.</p></div><button className="primary" disabled={loading} onClick={() => setPreview(true)}>Open sample preview →</button></section>}
      {shown && <><section className="metrics">
        {[["Transactions", shown.event_count.toLocaleString(), "Accepted, unique events"], ["Transaction value", money(shown.amount_cents / 100), "Synthetic USD volume"], ["Flagged by rules", shown.anomalies.toLocaleString(), "Investigation signals, not verdicts"], ["Event rate", (shown.event_count / 3600).toFixed(2) + "/s", "Average over the last hour"]].map(([label,value,caption]) => <article key={label}><span>{label}</span><strong>{value}</strong><small>{caption}</small></article>)}
      </section><div className="grid"><section id="transactions" className="panel"><div className="panel-title"><div><p className="overline">TRANSACTION FEED</p><h2>Signals worth a closer look</h2></div><span className="pill">{shown.events.length} recent</span></div>
        <div className="table-scroll"><table><thead><tr><th>Transaction</th><th>Time (UTC)</th><th>Amount</th><th>Signal</th></tr></thead><tbody>{shown.events.map(e => <tr key={e.id}><td className="mono">{e.id.slice(0,12)}</td><td>{e.at.slice(11,19)}</td><td>{money(e.amount)}</td><td><span className={e.anomaly ? "flag" : "normal"}>{e.anomaly ? "Review" : "Normal"}</span></td></tr>)}</tbody></table></div>
        <p className="footnote">Detector: {shown.detector}. Event feed is eventually consistent.</p></section>
        <section id="governance" className="panel governance"><p className="overline">MODEL GOVERNANCE</p><h2>Quality before promotion.</h2><p className="muted">The ML workflow scores batches after quality and human approval. Live counters above use explicit bootstrap rules.</p><ol>{["Validate & chronological split", "Train logistic baseline", "Evaluate unseen holdout", "F1 ≥ 0.80 · recall ≥ 0.70", "Register: pending human approval", "Approved bounded batch inference"].map((s,i)=><li key={s}><span>{String(i+1).padStart(2,"0")}</span>{s}</li>)}</ol><div className="note">Workflow design shown here. Live pipeline execution is not connected to this panel.</div></section></div></>}
      <footer><span>StreamML / Portfolio engineering lab</span><span>{preview ? "Illustrative values · not a cloud test" : "Synthetic data only · no cardholder information"}</span></footer>
    </main>
  </div>;
}
createRoot(document.getElementById("root")!).render(<React.StrictMode><App/></React.StrictMode>);
