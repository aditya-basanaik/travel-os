import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import { toast } from "sonner";
import { Plus, CalendarBlank, Users, DotsThreeVertical, ShareNetwork, Copy, Trash, ArrowCounterClockwise, MagnifyingGlass, X, Sparkle, Question, MapPin } from "@phosphor-icons/react";
import api, { fmtErr } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { MAP_TOPO } from "@/lib/images";

const fmtDate = (d) => new Date(d + "T00:00:00").toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });

export default function Dashboard() {
  const { user } = useAuth();
  const [trips, setTrips] = useState(null);
  const [deletedTrips, setDeletedTrips] = useState([]);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [activeSearch, setActiveSearch] = useState("");
  const [profile, setProfile] = useState(null);
  const navigate = useNavigate();

  const load = (searchTerm = activeSearch) => {
    api.get("/trips", { params: searchTerm ? { search: searchTerm } : undefined })
      .then(({ data }) => setTrips(Array.isArray(data?.items) ? data.items : []))
      .catch((e) => setError(fmtErr(e)));
    api.get("/trips/deleted")
      .then(({ data }) => setDeletedTrips(Array.isArray(data?.items) ? data.items : []))
      .catch(() => {});
    api.get("/profile")
      .then(({ data }) => setProfile(data))
      .catch(() => {});
  };
  useEffect(load, []);

  const submitSearch = (event) => {
    event.preventDefault();
    const nextSearch = search.trim();
    setActiveSearch(nextSearch);
    load(nextSearch);
  };

  const copyShareLink = async (shareUrl) => {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(shareUrl);
      return;
    }
    const input = document.createElement("textarea");
    input.value = shareUrl;
    input.style.position = "fixed";
    input.style.opacity = "0";
    document.body.appendChild(input);
    input.select();
    document.execCommand("copy");
    input.remove();
  };

  const share = async (id) => {
    try {
      const { data } = await api.post(`/trips/${id}/share`);
      await copyShareLink(`${window.location.origin}/shared/${data.share_token}`);
      toast.success("Share link copied to clipboard");
    } catch (e) { toast.error(fmtErr(e)); }
  };

  const duplicate = async (id) => {
    try {
      await api.post(`/trips/${id}/duplicate`);
      toast.success("Trip duplicated");
      load();
    } catch (e) { toast.error(fmtErr(e)); }
  };

  const remove = async (id) => {
    try {
      await api.delete(`/trips/${id}`);
      toast.success("Trip deleted (restorable for 30 days)");
      load();
    } catch (e) { toast.error(fmtErr(e)); }
  };

  const restore = async (id) => {
    try {
      await api.post(`/trips/${id}/restore`);
      toast.success("Trip restored");
      load();
    } catch (e) { toast.error(fmtErr(e)); }
  };

  return (
    <div data-testid="dashboard-page">
      <div className="flex items-end justify-between mb-8 gap-4">
        <div>
          <p className="label-overline mb-2">My Trips</p>
          <h1 className="font-heading font-extrabold text-4xl sm:text-5xl tracking-tight">
            Hey {user?.name?.split(" ")[0]},<br />where to next?
          </h1>
        </div>
        <Button asChild data-testid="create-trip-btn" className="rounded-full bg-primary text-white font-bold h-12 px-6 tap-scale shrink-0">
          <Link to="/plan"><Plus size={18} weight="bold" className="mr-1" /> Plan a trip</Link>
        </Button>
      </div>

      {error && <p className="text-destructive font-medium mb-6" data-testid="trips-error">{error}</p>}

      <form onSubmit={submitSearch} className="mb-8 flex gap-2 max-w-xl" data-testid="trip-search-form">
        <label className="relative flex-1">
          <MagnifyingGlass size={18} className="absolute left-3 top-3 text-muted-foreground" />
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search trips or destinations"
            aria-label="Search trips or destinations"
            className="w-full rounded-2xl border border-border bg-white py-2.5 pl-10 pr-10 text-sm outline-none focus:ring-2 focus:ring-primary/30"
          />
          {search && <button type="button" onClick={() => { setSearch(""); setActiveSearch(""); load(""); }} className="absolute right-3 top-2.5 text-muted-foreground hover:text-foreground" aria-label="Clear trip search"><X size={18} /></button>}
        </label>
        <Button type="submit" className="rounded-2xl bg-primary text-white font-bold" data-testid="trip-search-btn"><MagnifyingGlass size={17} className="mr-1" /> Search</Button>
      </form>

      {activeSearch && trips?.length === 0 && <p className="text-sm text-muted-foreground mb-6">No trips match “{activeSearch}”.</p>}

      <section className="mb-10" aria-label="Quick actions" data-testid="quick-actions">
        <div className="flex items-center justify-between mb-4">
          <div>
            <p className="label-overline mb-1">Your workspace</p>
            <h2 className="font-heading font-bold text-xl">Pick up where you left off</h2>
          </div>
        </div>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
          {[
            { to: "/plan", label: "Plan a trip", hint: "Build an itinerary", icon: Plus },
            { to: "/plan", label: "AI planner", hint: "Start with your ideas", icon: Sparkle },
            { to: "/trips", label: "Saved trips", hint: "Browse your plans", icon: CalendarBlank },
            { to: "/help", label: "Travel OS help", hint: "Find an answer", icon: Question },
          ].map(({ to, label, hint, icon: Icon }) => (
            <Link key={label} to={to} className="group rounded-2xl border border-border bg-white p-4 shadow-soft transition-transform hover:-translate-y-0.5" data-testid={`quick-action-${label.toLowerCase().replaceAll(" ", "-")}`}>
              <Icon size={20} weight="duotone" className="text-primary mb-3" />
              <p className="font-heading font-bold text-sm">{label}</p>
              <p className="text-xs text-muted-foreground mt-1">{hint}</p>
            </Link>
          ))}
        </div>
      </section>

      {profile?.favourite_destinations?.length > 0 && (
        <section className="mb-10" data-testid="recommended-destinations">
          <p className="label-overline mb-1">From your profile</p>
          <h2 className="font-heading font-bold text-xl mb-4">Destinations you saved</h2>
          <div className="flex gap-3 overflow-x-auto pb-2">
            {profile.favourite_destinations.map((destination) => (
              <Link key={destination} to="/plan" className="min-w-48 rounded-2xl border border-border bg-white p-4 shadow-soft hover:-translate-y-0.5 transition-transform">
                <MapPin size={20} weight="duotone" className="text-primary mb-4" />
                <p className="font-heading font-bold truncate">{destination}</p>
                <p className="text-xs text-muted-foreground mt-1">Plan a trip here</p>
              </Link>
            ))}
          </div>
        </section>
      )}

      {trips === null ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6" data-testid="trips-loading">
          {[1, 2, 3].map((i) => <Skeleton key={i} className="h-72 rounded-3xl" />)}
        </div>
      ) : trips.length === 0 ? (
        <div className="relative rounded-3xl overflow-hidden" data-testid="trips-empty-state">
          <img src={MAP_TOPO} alt="Topographic map texture" className="w-full h-80 object-cover" />
          <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex flex-col items-center justify-center text-center p-8">
            <h2 className="font-heading font-bold text-2xl mb-2">No trips yet</h2>
            <p className="text-muted-foreground mb-6 max-w-sm">Tell the AI planner your destination, dates and budget — it'll build the whole itinerary for you.</p>
            <Button asChild className="rounded-full bg-primary text-white font-bold tap-scale">
              <Link to="/plan" data-testid="empty-state-plan-btn"><Plus size={18} weight="bold" className="mr-1" /> Plan your first trip</Link>
            </Button>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6" data-testid="trips-grid">
          {trips.map((t, i) => (
            <motion.div key={t.id} layout initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.04, duration: 0.35, ease: "easeOut" }}
              className="card-lift relative rounded-3xl overflow-hidden bg-white shadow-soft cursor-pointer"
              data-testid={`trip-card-${t.id}`} onClick={() => navigate(`/trips/${t.id}`)}>
              <div className="relative h-44">
                <img src={t.cover_image} alt={`${t.destination} cover`} loading="lazy" className="w-full h-full object-cover" />
                <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-black/20 to-transparent" />
                <span className="absolute top-3 left-3 glass rounded-full px-3 py-1 text-xs font-bold capitalize" data-testid={`trip-status-${t.id}`}>{t.status}</span>
                <div className="absolute bottom-3 left-4 right-4 text-white">
                  <h3 className="font-heading font-bold text-lg leading-tight" style={{ textShadow: "0 1px 8px rgba(0,0,0,0.5)" }}>{t.title}</h3>
                </div>
              </div>
              <div className="p-4 flex items-center justify-between gap-2">
                <div className="text-sm text-muted-foreground space-y-1">
                  <p className="flex items-center gap-1.5"><CalendarBlank size={15} /> {fmtDate(t.start_date)} – {fmtDate(t.end_date)}</p>
                  <p className="flex items-center gap-1.5"><Users size={15} /> {t.people_count} {t.people_count === 1 ? "traveller" : "travellers"} · {t.currency}{t.budget.toLocaleString()}</p>
                </div>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild onClick={(e) => e.stopPropagation()}>
                    <button className="tap-scale p-2 rounded-full hover:bg-secondary" data-testid={`trip-menu-${t.id}`} aria-label="Trip actions">
                      <DotsThreeVertical size={20} weight="bold" />
                    </button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end" onClick={(e) => e.stopPropagation()}>
                    <DropdownMenuItem data-testid={`trip-share-${t.id}`} onClick={() => share(t.id)}><ShareNetwork size={16} className="mr-2" /> Share</DropdownMenuItem>
                    <DropdownMenuItem data-testid={`trip-duplicate-${t.id}`} onClick={() => duplicate(t.id)}><Copy size={16} className="mr-2" /> Duplicate</DropdownMenuItem>
                    <DropdownMenuItem data-testid={`trip-delete-${t.id}`} className="text-destructive" onClick={() => remove(t.id)}><Trash size={16} className="mr-2" /> Delete</DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </motion.div>
          ))}
        </div>
      )}

      {deletedTrips.length > 0 && (
        <section className="mt-10" data-testid="deleted-trips-section">
          <div className="flex items-center justify-between mb-4">
            <div>
              <p className="label-overline mb-1">Recently deleted</p>
              <h2 className="font-heading font-bold text-xl">Restore within 30 days</h2>
            </div>
          </div>
          <div className="space-y-3">
            {deletedTrips.map((trip) => (
              <motion.div layout initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3, ease: "easeOut" }} key={trip.id} className="bg-white rounded-3xl shadow-soft px-5 py-4 flex flex-wrap items-center gap-3" data-testid={`deleted-trip-${trip.id}`}>
                <div className="flex-1 min-w-0">
                  <p className="font-heading font-bold truncate">{trip.title}</p>
                  <p className="text-sm text-muted-foreground">{trip.destination} · deleted {fmtDate(trip.deleted_at)}</p>
                </div>
                <Button onClick={() => restore(trip.id)} data-testid={`restore-trip-${trip.id}`} className="rounded-full bg-primary text-white font-bold tap-scale">
                  <ArrowCounterClockwise size={16} className="mr-1" /> Restore
                </Button>
              </motion.div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
