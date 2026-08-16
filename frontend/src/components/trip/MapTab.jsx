import { motion } from "framer-motion";
import { MapPin, Warning } from "@phosphor-icons/react";
import { MAP_TOPO } from "@/lib/images";
import { TYPE_ICONS, TYPE_COLORS, mapsUrl } from "./ItineraryTab";

export default function MapTab({ trip }) {
  const itinerary = trip.itinerary || {};
  const days = itinerary.days || [];

  return (
    <div className="space-y-8" data-testid="map-tab">
      {/* Topographic Map Mockup Header */}
      <div className="relative rounded-3xl overflow-hidden h-72 shadow-soft border border-border">
        <img
          src={MAP_TOPO}
          alt="Topographic map texture"
          className="w-full h-full object-cover"
        />
        <div className="absolute inset-0 bg-black/10 backdrop-blur-[1px]" />
        
        {/* Glassmorphic overlay card */}
        <div className="absolute inset-0 flex items-center justify-center p-6">
          <div className="glass max-w-md w-full rounded-2xl p-6 text-center shadow-lg bg-white/80 border border-white/60">
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-4 text-primary">
              <MapPin size={24} weight="duotone" />
            </div>
            <h4 className="font-heading font-bold text-lg mb-2 text-foreground">
              Interactive Map Route
            </h4>
            <p className="text-xs text-muted-foreground leading-relaxed flex items-center justify-center gap-1.5">
              <Warning size={14} className="text-accent shrink-0" />
              Google Maps Platform API Key is required for native rendering.
            </p>
          </div>
        </div>
      </div>

      {/* Chronological Route Stops */}
      <div>
        <h3 className="font-heading font-bold text-xl mb-6">Route Stops & Directions</h3>
        {days.length === 0 ? (
          <div className="bg-secondary/60 rounded-3xl p-10 text-center">
            <p className="text-muted-foreground text-sm">No stops generated for this trip.</p>
          </div>
        ) : (
          <div className="space-y-8">
            {days.map((day, di) => {
              const activities = day.activities || [];
              if (activities.length === 0) return null;

              return (
                <motion.div
                  key={di}
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: di * 0.05 }}
                  className="space-y-4"
                >
                  <h4 className="font-heading font-bold text-base text-primary/90 flex items-center gap-2">
                    <span className="bg-primary text-white text-[10px] uppercase font-bold tracking-wider px-2.5 py-1 rounded-full">
                      Day {day.day_number || di + 1}
                    </span>
                    <span className="text-muted-foreground font-medium text-sm">
                      {day.title}
                    </span>
                  </h4>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {activities.map((act, ai) => {
                      const Icon = TYPE_ICONS[act.type] || MapPin;
                      const colorClass = TYPE_COLORS[act.type] || "bg-primary";

                      return (
                        <div
                          key={ai}
                          className="bg-white rounded-2xl shadow-soft p-5 border border-border/50 flex gap-4 items-start hover:-translate-y-0.5 hover:shadow-md transition-all duration-200"
                          data-testid={`map-stop-${di}-${ai}`}
                        >
                          <div className={`w-10 h-10 rounded-full flex items-center justify-center shrink-0 text-white ${colorClass}`}>
                            <Icon size={18} weight="bold" />
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex justify-between items-start gap-2">
                              <p className="text-xs font-bold text-muted-foreground">{act.time}</p>
                              <span className="text-xs font-bold capitalize text-primary/70">{act.type}</span>
                            </div>
                            <p className="font-heading font-bold text-sm text-foreground mt-1 truncate">
                              {act.title}
                            </p>
                            {act.location && (
                              <div className="mt-3">
                                <a
                                  href={mapsUrl(act.location)}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  data-testid={`map-stop-link-${di}-${ai}`}
                                  className="inline-flex items-center gap-1.5 text-xs text-primary font-bold hover:underline"
                                >
                                  <MapPin size={14} weight="duotone" />
                                  <span>View {act.location} on Maps</span>
                                </a>
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </motion.div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
