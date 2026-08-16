import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { AirplaneTilt, CalendarBlank, Users, MapPin } from "@phosphor-icons/react";
import api from "@/lib/api";
import { Skeleton } from "@/components/ui/skeleton";
import { TYPE_ICONS, mapsUrl } from "@/components/trip/ItineraryTab";
import { Compass } from "@phosphor-icons/react";

const fmtDate = (d) => new Date(d + "T00:00:00").toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });

export default function SharedTrip() {
  const { token } = useParams();
  const [trip, setTrip] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api.get(`/trips/shared/${token}`).then(({ data }) => setTrip(data)).catch((e) => setError(e?.response?.data?.detail || "Shared trip not found"));
  }, [token]);

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center p-6 bg-background" data-testid="shared-trip-error">
        <div className="text-center">
          <p className="font-heading font-bold text-xl mb-2">{error}</p>
          <Link to="/login" className="text-primary font-bold underline">Go to Travel OS</Link>
        </div>
      </div>
    );
  }

  if (!trip) {
    return <div className="max-w-3xl mx-auto p-6 space-y-6" data-testid="shared-trip-loading"><Skeleton className="h-64 rounded-3xl" /><Skeleton className="h-96 rounded-3xl" /></div>;
  }

  const days = trip.itinerary?.days || [];

  return (
    <div className="min-h-screen bg-background" data-testid="shared-trip-page">
      <header className="glass border-b border-black/5 px-4 py-3 flex items-center justify-between sticky top-0 z-40">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-xl bg-primary flex items-center justify-center">
            <AirplaneTilt size={18} weight="duotone" className="text-white" />
          </div>
          <span className="font-heading font-bold text-lg">Travel OS</span>
        </div>
        <span className="text-xs text-muted-foreground font-medium">Shared by {trip.shared_by}</span>
      </header>

      <div className="max-w-3xl mx-auto p-4 md:p-8">
        <div className="relative rounded-3xl overflow-hidden mb-8">
          <img src={trip.cover_image} alt={`${trip.destination} cover`} className="w-full h-56 md:h-72 object-cover" />
          <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/25 to-transparent" />
          <div className="absolute bottom-0 p-5 md:p-8 text-white">
            <h1 className="font-heading font-extrabold text-3xl md:text-4xl" style={{ textShadow: "0 2px 12px rgba(0,0,0,0.5)" }} data-testid="shared-trip-title">{trip.title}</h1>
            <div className="flex flex-wrap gap-x-4 gap-y-1 mt-2 text-sm text-white/85">
              <span className="flex items-center gap-1.5"><CalendarBlank size={15} /> {fmtDate(trip.start_date)} – {fmtDate(trip.end_date)}</span>
              <span className="flex items-center gap-1.5"><Users size={15} /> {trip.people_count} travellers</span>
            </div>
          </div>
        </div>

        {trip.itinerary?.summary && <p className="text-muted-foreground mb-8">{trip.itinerary.summary}</p>}

        <div className="space-y-10">
          {days.map((day, di) => (
            <div key={di}>
              <h3 className="font-heading font-bold text-xl mb-4">Day {day.day_number || di + 1} <span className="text-muted-foreground font-medium text-base">· {day.title}</span></h3>
              <div className="border-l-2 border-dashed border-primary/30 ml-3 pl-6 space-y-4">
                {(day.activities || []).map((act, ai) => {
                  const Icon = TYPE_ICONS[act.type] || Compass;
                  return (
                    <div key={ai} className="relative bg-white rounded-3xl shadow-soft p-5">
                      <span className="absolute -left-[35px] top-6 w-5 h-5 rounded-full bg-primary flex items-center justify-center">
                        <Icon size={11} className="text-white" weight="bold" />
                      </span>
                      <div className="flex gap-4">
                        <span className="text-xs font-bold text-muted-foreground w-12 shrink-0 pt-0.5">{act.time}</span>
                        <div className="flex-1 min-w-0">
                          <p className="font-heading font-bold">{act.title}</p>
                          {act.description && <p className="text-sm text-muted-foreground mt-1">{act.description}</p>}
                          {act.location && (
                            <a href={mapsUrl(act.location)} target="_blank" rel="noopener noreferrer"
                              className="flex items-center gap-1 text-xs text-primary font-bold mt-2 hover:underline">
                              <MapPin size={13} /> {act.location}
                            </a>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>

        <div className="mt-12 text-center bg-secondary/60 rounded-3xl p-8">
          <p className="font-heading font-bold text-lg mb-2">Want an itinerary like this?</p>
          <Link to="/login" data-testid="shared-cta" className="inline-block bg-primary text-white font-bold rounded-full px-8 py-3 tap-scale">
            Plan your trip on Travel OS
          </Link>
        </div>
      </div>
    </div>
  );
}
