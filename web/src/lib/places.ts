// Gym search without an API key. Results come from OpenStreetMap's free geocoder
// (Nominatim); everything the user *sees* is Google / Apple Maps.
// Swap searchPlaces() for Google Places once we have a key + billing set up.

export interface Place {
  name: string;
  address: string;
  lat: number;
  lng: number;
}

interface NominatimResult {
  name?: string;
  display_name: string;
  lat: string;
  lon: string;
}

export async function searchPlaces(query: string, signal?: AbortSignal): Promise<Place[]> {
  const q = query.trim();
  if (!q) return [];
  const url = `https://nominatim.openstreetmap.org/search?format=jsonv2&limit=6&addressdetails=0&q=${encodeURIComponent(q)}`;
  const res = await fetch(url, { signal, headers: { "Accept-Language": "en" } });
  if (!res.ok) throw new Error(`Search failed (${res.status})`);
  const results = (await res.json()) as NominatimResult[];
  return results.map((r) => ({
    name: r.name || r.display_name.split(",")[0],
    address: r.display_name,
    lat: Number(r.lat),
    lng: Number(r.lon),
  }));
}

export const googleMapsUrl = (lat: number, lng: number) =>
  `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;

export const appleMapsUrl = (lat: number, lng: number, name: string) =>
  `https://maps.apple.com/?ll=${lat},${lng}&q=${encodeURIComponent(name)}`;

/** Keyless Google Maps embed for a pin preview. */
export const googleMapsEmbedUrl = (lat: number, lng: number) =>
  `https://maps.google.com/maps?q=${lat},${lng}&z=16&output=embed`;
