"use client";

import { useState, type FormEvent } from "react";
import { appleMapsUrl, googleMapsEmbedUrl, googleMapsUrl, searchPlaces, type Place } from "@/lib/places";
import type { GymLocation } from "@/lib/store";
import { currentPosition } from "./ui";

/** Search for a gym by name/address, or pin your current location. */
export function GymPicker({ value, onChange }: { value: GymLocation | null; onChange: (g: GymLocation | null) => void }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<Place[]>([]);
  const [searching, setSearching] = useState(false);
  const [locating, setLocating] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function search(e: FormEvent) {
    e.preventDefault();
    if (!query.trim()) return;
    setSearching(true);
    setMessage(null);
    try {
      const found = await searchPlaces(query);
      setResults(found);
      if (found.length === 0) setMessage("No matches. Try adding the city, e.g. “ARC Champaign”.");
    } catch {
      setMessage("Search isn't working right now. Use “I'm at my gym right now” instead.");
    } finally {
      setSearching(false);
    }
  }

  async function useHere() {
    setLocating(true);
    setMessage(null);
    const pos = await currentPosition();
    setLocating(false);
    if (!pos) {
      setMessage("Couldn't get your location. Allow location access in your browser, or search instead.");
      return;
    }
    onChange({ name: value?.name ?? (query.trim() || "My gym"), lat: pos.coords.latitude, lng: pos.coords.longitude });
    setResults([]);
  }

  return (
    <div className="stack">
      <form className="row" onSubmit={search} role="search">
        <input
          className="text"
          placeholder="Search your gym (e.g. ARC Champaign)"
          aria-label="Search for your gym"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <button type="submit" className="btn btn-secondary" style={{ width: "auto", minWidth: 88 }} disabled={searching}>
          {searching ? "…" : "Search"}
        </button>
      </form>

      {results.length > 0 && (
        <div className="stack" style={{ gap: 8 }}>
          {results.map((p) => (
            <button
              key={`${p.lat},${p.lng}`}
              type="button"
              className="option"
              aria-pressed={false}
              onClick={() => {
                onChange({ name: p.name, lat: p.lat, lng: p.lng });
                setResults([]);
              }}
            >
              <span className="stack" style={{ gap: 2, minWidth: 0 }}>
                <strong>{p.name}</strong>
                <span className="small muted" style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                  {p.address}
                </span>
              </span>
            </button>
          ))}
          <span className="small muted">Search results © OpenStreetMap contributors</span>
        </div>
      )}

      <button type="button" className="btn btn-secondary" onClick={useHere} disabled={locating}>
        {locating ? "Locating…" : "📍 I'm at my gym right now"}
      </button>

      {value && (
        <div className="card" style={{ padding: 0, overflow: "hidden", gap: 0 }}>
          <iframe
            title={`Map of ${value.name}`}
            src={googleMapsEmbedUrl(value.lat, value.lng)}
            style={{ border: 0, width: "100%", height: 200, display: "block" }}
            loading="lazy"
            referrerPolicy="no-referrer-when-downgrade"
          />
          <div className="stack" style={{ padding: 14, gap: 8 }}>
            <label className="field">
              <span className="small muted">Gym name</span>
              <input className="text" value={value.name} onChange={(e) => onChange({ ...value, name: e.target.value || "My gym" })} />
            </label>
            <div className="row small">
              <a href={googleMapsUrl(value.lat, value.lng)} target="_blank" rel="noreferrer" style={{ color: "var(--accent)" }}>
                Open in Google Maps
              </a>
              <a href={appleMapsUrl(value.lat, value.lng, value.name)} target="_blank" rel="noreferrer" style={{ color: "var(--accent)" }}>
                Open in Apple Maps
              </a>
            </div>
          </div>
        </div>
      )}

      {message && <p className="small muted">{message}</p>}
    </div>
  );
}
