import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import { toast } from "sonner";
import { Plus, CalendarBlank, Users, DotsThreeVertical, ShareNetwork, Copy, Trash } from "@phosphor-icons/react";
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
  const [error, setError] = useState("");
  const navigate = useNavigate();

  const load = () => {
    api.get("/trips")
      .then(({ data }) => setTrips(Array.isArray(data?.items) ? data.items : []))
      .catch((e) => setError(fmtErr(e)));
  };
  useEffect(load, []);

  const share = async (id) => {
    try {
      const { data } = await api.post(`/trips/${id}/share`);
      await navigator.clipboard.writeText(`${window.location.origin}/shared/${data.share_token}`);
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
            <motion.div key={t.id} initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.06 }}
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
    </div>
  );
}
