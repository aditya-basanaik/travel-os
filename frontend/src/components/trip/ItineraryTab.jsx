import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { toast } from "sonner";
import { ForkKnife, Bed, Car, Compass, Mountains, Martini, Bank, Island, Parachute, MapPin, PencilSimple, Check, Plus, X } from "@phosphor-icons/react";
import api, { fmtErr } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { COVER_BEACH } from "@/lib/images";

export const TYPE_ICONS = {
  food: ForkKnife, stay: Bed, transport: Car, activity: Compass,
  nature: Mountains, nightlife: Martini, culture: Bank, relaxation: Island, adventure: Parachute,
};

export const TYPE_COLORS = {
  food: "bg-rose-500",
  stay: "bg-indigo-500",
  transport: "bg-amber-500",
  activity: "bg-emerald-500",
  nature: "bg-green-600",
  nightlife: "bg-violet-600",
  culture: "bg-sky-500",
  relaxation: "bg-rose-200",
  adventure: "bg-fuchsia-600",
};

export const mapsUrl = (q) => `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(q)}`;

const fmtDate = (d) => {
  try { return new Date(d + "T00:00:00").toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" }); }
  catch { return d; }
};

export default function ItineraryTab({ trip, onUpdate }) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(null);
  const [saving, setSaving] = useState(false);
  const [weather, setWeather] = useState({});
  const it = editing ? draft : (trip.itinerary || {});
  const days = it.days || [];
  const cb = it.cost_breakdown || {};

  const startEdit = () => { setDraft(JSON.parse(JSON.stringify(trip.itinerary))); setEditing(true); };

  // Fetch weather for trip days (best-effort; silent on failure)
  useEffect(() => {
    let mounted = true;
    if (!trip?.id) return;
    api.get(`/trips/${trip.id}/weather`).then((r) => {
      if (!mounted) return;
      setWeather(r.data || {});
    }).catch(() => { /* ignore */ });
    return () => { mounted = false; };
  }, [trip && trip.id]);

  const save = async () => {
    setSaving(true);
    try {
      const { data } = await api.put(`/trips/${trip.id}/itinerary`, { itinerary: draft });
      onUpdate(data);
      setEditing(false);
      toast.success("Itinerary updated");
    } catch (e) { toast.error(fmtErr(e)); }
    finally { setSaving(false); }
  };

  const setAct = (di, ai, key, val) => {
    const next = { ...draft, days: draft.days.map((d, i) => i !== di ? d : { ...d, activities: d.activities.map((a, j) => j !== ai ? a : { ...a, [key]: val }) }) };
    setDraft(next);
  };

  const removeAct = (di, ai) => {
    setDraft({ ...draft, days: draft.days.map((d, i) => i !== di ? d : { ...d, activities: d.activities.filter((_, j) => j !== ai) }) });
  };

  const addAct = (di) => {
    const act = { time: "12:00", title: "New activity", description: "", type: "activity", estimated_cost: 0, location: trip.destination };
    setDraft({ ...draft, days: draft.days.map((d, i) => i !== di ? d : { ...d, activities: [...d.activities, act] }) });
  };

  return (
    <div data-testid="itinerary-tab">
      {it.summary && <p className="text-muted-foreground mb-6 max-w-2xl">{it.summary}</p>}

      {Object.keys(cb).length > 0 && (
        <div className="bg-secondary/60 rounded-3xl p-5 mb-8 flex flex-wrap gap-x-8 gap-y-3" data-testid="cost-breakdown">
          <span className="label-overline w-full">Estimated cost split</span>
          {Object.entries(cb).map(([k, v]) => (
            <div key={k}>
              <p className="text-xs text-muted-foreground capitalize">{k}</p>
              <p className="font-heading font-bold text-lg">{trip.currency}{Number(v).toLocaleString()}</p>
            </div>
          ))}
        </div>
      )}

      <div className="flex justify-end mb-4">
        {editing ? (
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => setEditing(false)} data-testid="itinerary-cancel-edit" className="rounded-full tap-scale">Cancel</Button>
            <Button onClick={save} disabled={saving} data-testid="itinerary-save-btn" className="rounded-full bg-primary text-white tap-scale">
              <Check size={16} weight="bold" className="mr-1" /> {saving ? "Saving…" : "Save changes"}
            </Button>
          </div>
        ) : (
          <Button variant="outline" onClick={startEdit} data-testid="itinerary-edit-btn" className="rounded-full tap-scale">
            <PencilSimple size={16} className="mr-1" /> Edit itinerary
          </Button>
        )}
      </div>

      <div className="space-y-10">
        {days.map((day, di) => (
          <motion.div key={di} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: di * 0.05 }}>
            <div className="flex items-baseline justify-between flex-wrap gap-2 mb-4">
              <h3 className="font-heading font-bold text-xl" data-testid={`day-title-${di}`}>
                Day {day.day_number || di + 1} <span className="text-muted-foreground font-medium text-base">· {fmtDate(day.date)} · {day.title} {weather?.[day.date] && (<span className="ml-3 text-sm">{weather[day.date].emoji} {weather[day.date].temp}°C</span>)}</span>
              </h3>
              <span className="text-sm font-bold text-primary" data-testid={`day-cost-${di}`}>{trip.currency}{Number(day.estimated_cost || 0).toLocaleString()}</span>
            </div>
            <div className="border-l-2 border-dashed border-primary/30 ml-3 pl-6 space-y-4">
              {(day.activities || []).map((act, ai) => {
                const Icon = TYPE_ICONS[act.type] || Compass;
                return (
                  <div key={ai} className="relative bg-white rounded-3xl shadow-soft p-5" data-testid={`activity-${di}-${ai}`}>
                    <span className={`absolute -left-[42px] top-4 w-10 h-10 rounded-full flex items-center justify-center ${TYPE_COLORS[act.type] || "bg-primary"}`}>
                      <Icon size={14} className="text-white" weight="bold" />
                    </span>
                    {editing ? (
                      <div className="space-y-3">
                        <div className="flex gap-2">
                          <input value={act.time} onChange={(e) => setAct(di, ai, "time", e.target.value)} data-testid={`activity-time-input-${di}-${ai}`}
                            className="w-20 h-10 rounded-full border border-input px-3 text-sm" aria-label="Time" />
                          <input value={act.title} onChange={(e) => setAct(di, ai, "title", e.target.value)} data-testid={`activity-title-input-${di}-${ai}`}
                            className="flex-1 h-10 rounded-full border border-input px-4 text-sm font-medium" aria-label="Activity title" />
                          <input type="number" min="0" value={act.estimated_cost} onChange={(e) => setAct(di, ai, "estimated_cost", Number(e.target.value))} data-testid={`activity-cost-input-${di}-${ai}`}
                            className="w-24 h-10 rounded-full border border-input px-3 text-sm" aria-label="Estimated cost" />
                          <button onClick={() => removeAct(di, ai)} data-testid={`activity-remove-${di}-${ai}`} aria-label="Remove activity"
                            className="tap-scale w-10 h-10 rounded-full bg-destructive/10 text-destructive flex items-center justify-center"><X size={16} weight="bold" /></button>
                        </div>
                        <input value={act.description || ""} onChange={(e) => setAct(di, ai, "description", e.target.value)} data-testid={`activity-desc-input-${di}-${ai}`}
                          className="w-full h-10 rounded-full border border-input px-4 text-sm" aria-label="Description" placeholder="Description" />
                      </div>
                    ) : (
                      <div className="flex gap-4">
                        <span className="text-xs font-bold text-muted-foreground w-12 shrink-0 pt-0.5">{act.time}</span>
                        <img src={act.image_url || COVER_BEACH} alt={act.title} className="w-20 h-20 rounded-lg object-cover shrink-0" />
                        <div className="flex-1 min-w-0">
                          <p className="font-heading font-bold">{act.title}</p>
                          {act.description && <p className="text-sm text-muted-foreground mt-1" style={{display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden'}}>{act.description}</p>}
                          <div className="flex flex-wrap items-center gap-3 mt-2 text-xs">
                            {act.location && (
                              <a href={mapsUrl(act.location)} target="_blank" rel="noopener noreferrer" data-testid={`activity-map-link-${di}-${ai}`} className="flex items-center gap-1 text-primary font-bold hover:underline">
                                <MapPin size={13} /> {act.location}
                              </a>
                            )}
                            <span className="font-bold">{trip.currency}{Number(act.estimated_cost || 0).toLocaleString()}</span>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
              {editing && (
                <button onClick={() => addAct(di)} data-testid={`activity-add-${di}`}
                  className="tap-scale flex items-center gap-2 text-sm font-bold text-primary px-4 py-2 rounded-full bg-primary/10">
                  <Plus size={14} weight="bold" /> Add activity
                </button>
              )}
            </div>
          </motion.div>
        ))}
      </div>

      {(it.tips || []).length > 0 && !editing && (
        <div className="mt-10 bg-accent/10 rounded-3xl p-6" data-testid="itinerary-tips">
          <p className="label-overline mb-3 !text-accent">Good to know</p>
          <ul className="space-y-2 text-sm">
            {it.tips.map((tip, i) => <li key={i} className="flex gap-2"><span className="text-accent font-bold">•</span>{tip}</li>)}
          </ul>
        </div>
      )}
    </div>
  );
}
