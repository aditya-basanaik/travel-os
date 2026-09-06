import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Bed, Binoculars, ForkKnife, HeartStraight, MapPin } from "@phosphor-icons/react";
import api, { fmtErr } from "@/lib/api";
import { Skeleton } from "@/components/ui/skeleton";

const FILTERS = ["all", "hotel", "restaurant", "attraction"];
const LABELS = { hotel: "Hotels", restaurant: "Restaurants", attraction: "Attractions" };
const ICONS = { hotel: Bed, restaurant: ForkKnife, attraction: Binoculars };

export default function Favorites() {
  const [favorites, setFavorites] = useState(null);
  const [filter, setFilter] = useState("all");
  const [error, setError] = useState("");

  useEffect(() => {
    api.get("/favorites")
      .then(({ data }) => setFavorites(data))
      .catch((err) => setError(fmtErr(err)));
  }, []);

  const visibleFavorites = useMemo(
    () => (favorites || []).filter((favorite) => filter === "all" || favorite.type === filter),
    [favorites, filter],
  );

  if (favorites === null && !error) {
    return (
      <div className="space-y-5" data-testid="favorites-loading">
        <Skeleton className="h-10 w-64" />
        <Skeleton className="h-12 w-full max-w-xl rounded-full" />
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {[1, 2, 3].map((item) => <Skeleton key={item} className="h-48 rounded-3xl" />)}
        </div>
      </div>
    );
  }

  if (error) {
    return <p className="text-sm text-destructive font-medium" data-testid="favorites-error">{error}</p>;
  }

  return (
    <div className="space-y-8" data-testid="favorites-page">
      <div>
        <p className="label-overline mb-2">Saved places</p>
        <h1 className="font-heading font-extrabold text-4xl tracking-tight">Your favorites</h1>
        <p className="text-muted-foreground mt-2">Every place you have saved across your trips.</p>
      </div>

      <div className="flex flex-wrap gap-2" role="group" aria-label="Filter favorites">
        {FILTERS.map((value) => (
          <button
            key={value}
            type="button"
            onClick={() => setFilter(value)}
            className={`rounded-full px-5 py-2.5 text-sm font-bold capitalize transition-colors ${filter === value ? "bg-primary text-white" : "bg-secondary text-foreground hover:bg-secondary/70"}`}
            data-testid={`favorites-filter-${value}`}
          >
            {value === "all" ? "All" : LABELS[value]}
          </button>
        ))}
      </div>

      {visibleFavorites.length === 0 ? (
        <div className="bg-secondary/60 rounded-3xl p-12 text-center" data-testid="favorites-empty">
          <HeartStraight size={42} weight="duotone" className="mx-auto mb-4 text-primary" />
          <p className="font-heading font-bold text-lg">No favorites yet - start planning a trip to save some!</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6" data-testid="favorites-list">
          {visibleFavorites.map((favorite) => {
            const Icon = ICONS[favorite.type] || HeartStraight;
            const image = favorite.meta?.image || favorite.meta?.image_url;
            return (
              <article key={favorite.id} className="bg-white rounded-3xl shadow-soft p-6" data-testid={`favorite-card-${favorite.id}`}>
                <div className="flex gap-4 items-start">
                  {image ? (
                    <img src={image} alt="" className="w-16 h-16 rounded-2xl object-cover shrink-0" />
                  ) : (
                    <div className="w-16 h-16 rounded-2xl bg-primary/10 text-primary flex items-center justify-center shrink-0">
                      <Icon size={28} weight="duotone" />
                    </div>
                  )}
                  <div className="min-w-0 flex-1">
                    <div className="flex items-start justify-between gap-3">
                      <h2 className="font-heading font-bold text-lg leading-tight">{favorite.name}</h2>
                      <span className="text-xs font-bold capitalize bg-secondary rounded-full px-3 py-1 shrink-0">{favorite.type}</span>
                    </div>
                    <p className="text-sm text-muted-foreground mt-2 flex items-center gap-1">
                      <MapPin size={14} /> {favorite.trip_destination || "Saved trip"}
                    </p>
                    <Link to={`/trips/${favorite.trip_id}`} className="inline-flex mt-4 text-sm font-bold text-primary hover:underline" data-testid={`favorite-trip-link-${favorite.id}`}>
                      Open {favorite.trip_title || "originating trip"}
                    </Link>
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
