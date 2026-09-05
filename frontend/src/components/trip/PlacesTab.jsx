import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { toast } from "sonner";
import { Star, Heart, MapPin, ArrowSquareOut, Bed, ForkKnife, Binoculars } from "@phosphor-icons/react";
import api, { fmtErr } from "@/lib/api";
import { mapsUrl } from "@/components/trip/ItineraryTab";

const bookingUrl = (name, dest) => `https://www.booking.com/searchresults.html?ss=${encodeURIComponent(`${name} ${dest}`)}`;

export default function PlacesTab({ trip, type }) {
  const listKey = type === "hotel" ? "hotels" : type === "restaurant" ? "restaurants" : "attractions";
  const items = trip.itinerary?.[listKey] || [];
  const [favs, setFavs] = useState([]);

  useEffect(() => {
    api.get(`/trips/${trip.id}/favorites`).then(({ data }) => setFavs(data)).catch(() => {});
  }, [trip.id, type]);

  const isFav = (name) => favs.some((f) => f.type === type && f.name === name);

  const toggleFav = async (item) => {
    try {
      if (isFav(item.name)) {
        const fav = favs.find((f) => f.type === type && f.name === item.name);
        await api.delete(`/favorites/${fav.id}`);
        setFavs(favs.filter((f) => f.id !== fav.id));
        toast.success("Removed from favorites");
      } else {
        const { data } = await api.post(`/trips/${trip.id}/favorites`, { type, name: item.name, meta: item });
        setFavs([...favs, data]);
        toast.success("Saved to favorites");
      }
    } catch (e) { toast.error(fmtErr(e)); }
  };

  if (items.length === 0) {
    return (
      <div className="bg-secondary/60 rounded-3xl p-10 text-center" data-testid={`${type}s-empty`}>
        <p className="text-muted-foreground">No {type === "hotel" ? "hotel" : type === "restaurant" ? "restaurant" : "attraction"} recommendations on this trip yet.</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6" data-testid={`${type}s-list`}>
      {items.map((item, i) => {
        const Icon = type === "hotel" ? Bed : type === "restaurant" ? ForkKnife : Binoculars;
        return (
          <motion.div key={i} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}
            className="card-lift bg-white rounded-3xl shadow-soft p-6" data-testid={`${type}-card-${i}`}>
            <div className="flex items-start justify-between gap-3 mb-3">
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-2xl bg-primary/10 text-primary flex items-center justify-center shrink-0">
                  <Icon size={22} weight="duotone" />
                </div>
                <div>
                  <h3 className="font-heading font-bold leading-tight">{item.name}</h3>
                  <p className="text-xs text-muted-foreground">{type === "hotel" ? item.area : type === "restaurant" ? item.cuisine : item.category}</p>
                </div>
              </div>
              <button onClick={() => toggleFav(item)} data-testid={`${type}-fav-${i}`} aria-label="Toggle favorite"
                className={`tap-scale w-10 h-10 rounded-full flex items-center justify-center ${isFav(item.name) ? "bg-accent/15 text-accent" : "bg-secondary text-muted-foreground"}`}>
                <Heart size={18} weight={isFav(item.name) ? "fill" : "regular"} />
              </button>
            </div>

            <div className="flex flex-wrap gap-2 mb-3">
              {item.rating && (
                <span className="flex items-center gap-1 bg-secondary rounded-full px-3 py-1 text-xs font-bold">
                  <Star size={12} weight="fill" className="text-amber-500" /> {item.rating}
                </span>
              )}
              {type === "hotel" && item.price_per_night != null && (
                <span className="bg-secondary rounded-full px-3 py-1 text-xs font-bold">{trip.currency}{Number(item.price_per_night).toLocaleString()}/night</span>
              )}
              {type === "restaurant" && item.price_level != null && (
                <span className="bg-secondary rounded-full px-3 py-1 text-xs font-bold">{"₹".repeat(Math.max(1, item.price_level))}</span>
              )}
              {type === "restaurant" && item.veg_friendly && (
                <span className="bg-primary/10 text-primary rounded-full px-3 py-1 text-xs font-bold">Veg friendly</span>
              )}
              {type === "attraction" && item.recommended_duration && (
                <span className="bg-secondary rounded-full px-3 py-1 text-xs font-bold">{item.recommended_duration}</span>
              )}
              {(item.amenities || []).slice(0, 3).map((a) => (
                <span key={a} className="bg-secondary rounded-full px-3 py-1 text-xs">{a}</span>
              ))}
            </div>

            {item.description && <p className="text-sm text-muted-foreground mb-4">{item.description}</p>}

            <div className="flex gap-2">
              <a href={mapsUrl(`${item.name} ${item.area || item.destination || ""} ${trip.destination}`)} target="_blank" rel="noopener noreferrer"
                data-testid={`${type}-maps-link-${i}`}
                className="tap-scale flex-1 flex items-center justify-center gap-1.5 bg-secondary rounded-full py-2.5 text-sm font-bold hover:bg-secondary/70 transition-colors">
                <MapPin size={15} /> View on Maps
              </a>
              {type === "hotel" && (
                <a href={bookingUrl(item.name, trip.destination)} target="_blank" rel="noopener noreferrer"
                  data-testid={`hotel-booking-link-${i}`}
                  className="tap-scale flex-1 flex items-center justify-center gap-1.5 bg-primary text-white rounded-full py-2.5 text-sm font-bold hover:bg-primary/90 transition-colors">
                  <ArrowSquareOut size={15} /> Book
                </a>
              )}
            </div>
          </motion.div>
        );
      })}
    </div>
  );
}
