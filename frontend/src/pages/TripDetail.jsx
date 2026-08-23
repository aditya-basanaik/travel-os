import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { toast } from "sonner";
import { ArrowLeft, ShareNetwork, Copy, Trash, CalendarBlank, Users, Wallet } from "@phosphor-icons/react";
import api, { fmtErr } from "@/lib/api";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from "@/components/ui/alert-dialog";
import { Skeleton } from "@/components/ui/skeleton";
import ItineraryTab from "@/components/trip/ItineraryTab";
import PlacesTab from "@/components/trip/PlacesTab";
import MapTab from "@/components/trip/MapTab";
import ExpensesTab from "@/components/trip/ExpensesTab";

const fmtDate = (d) => new Date(d + "T00:00:00").toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });

export default function TripDetail() {
  const { id } = useParams();
  const [trip, setTrip] = useState(null);
  const [error, setError] = useState("");
  const navigate = useNavigate();

  const load = () => {
    api.get(`/trips/${id}`).then(({ data }) => setTrip(data)).catch((e) => setError(fmtErr(e)));
  };
  useEffect(load, [id]);

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

  const share = async () => {
    try {
      const { data } = await api.post(`/trips/${id}/share`);
      await copyShareLink(`${window.location.origin}/shared/${data.share_token}`);
      toast.success("Share link copied to clipboard");
    } catch (e) { toast.error(fmtErr(e)); }
  };

  const duplicate = async () => {
    try {
      const { data } = await api.post(`/trips/${id}/duplicate`);
      toast.success("Trip duplicated");
      navigate(`/trips/${data.id}`);
    } catch (e) { toast.error(fmtErr(e)); }
  };

  const remove = async () => {
    try {
      await api.delete(`/trips/${id}`);
      toast.success("Trip deleted (restorable for 30 days)");
      navigate("/");
    } catch (e) { toast.error(fmtErr(e)); }
  };

  if (error) {
    return (
      <div className="text-center py-20" data-testid="trip-error">
        <p className="text-destructive font-medium mb-4">{error}</p>
        <button onClick={() => navigate("/")} className="text-primary font-bold underline">Back to trips</button>
      </div>
    );
  }

  if (!trip) {
    return <div className="space-y-6" data-testid="trip-loading"><Skeleton className="h-64 rounded-3xl" /><Skeleton className="h-96 rounded-3xl" /></div>;
  }

  return (
    <div data-testid="trip-detail-page">
      <button onClick={() => navigate("/")} data-testid="trip-back-button" className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground mb-4 tap-scale">
        <ArrowLeft size={16} /> All trips
      </button>

      <div className="relative rounded-3xl overflow-hidden mb-8">
        <img src={trip.cover_image} alt={`${trip.destination} cover`} className="w-full h-56 md:h-72 object-cover" />
        <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/25 to-transparent" />
        <div className="absolute bottom-0 left-0 right-0 p-5 md:p-8 flex flex-wrap items-end justify-between gap-4">
          <div className="text-white">
            <h1 className="font-heading font-extrabold text-3xl md:text-4xl tracking-tight" style={{ textShadow: "0 2px 12px rgba(0,0,0,0.5)" }} data-testid="trip-title">{trip.title}</h1>
            <div className="flex flex-wrap gap-x-4 gap-y-1 mt-2 text-sm text-white/85">
              <span className="flex items-center gap-1.5"><CalendarBlank size={15} /> {fmtDate(trip.start_date)} – {fmtDate(trip.end_date)}</span>
              <span className="flex items-center gap-1.5"><Users size={15} /> {trip.people_count} travellers</span>
              <span className="flex items-center gap-1.5"><Wallet size={15} /> {trip.currency}{trip.budget.toLocaleString()} budget</span>
            </div>
          </div>
          <div className="flex gap-2">
            <button onClick={share} data-testid="trip-share-btn" className="tap-scale glass rounded-full px-4 py-2 text-sm font-bold flex items-center gap-1.5"><ShareNetwork size={16} /> Share</button>
            <button onClick={duplicate} data-testid="trip-duplicate-btn" className="tap-scale glass rounded-full px-4 py-2 text-sm font-bold flex items-center gap-1.5"><Copy size={16} /> Duplicate</button>
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <button data-testid="trip-delete-btn" className="tap-scale glass rounded-full px-4 py-2 text-sm font-bold flex items-center gap-1.5 text-destructive"><Trash size={16} /> Delete</button>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Delete this trip?</AlertDialogTitle>
                  <AlertDialogDescription>It will be soft-deleted and permanently removed after 30 days.</AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel data-testid="trip-delete-cancel">Cancel</AlertDialogCancel>
                  <AlertDialogAction data-testid="trip-delete-confirm" onClick={remove} className="bg-destructive text-destructive-foreground">Delete</AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </div>
        </div>
      </div>

      <Tabs defaultValue="itinerary" data-testid="trip-tabs">
        <TabsList className="bg-secondary rounded-full p-1 h-auto flex-wrap mb-6">
          <TabsTrigger value="itinerary" data-testid="tab-itinerary" className="rounded-full data-[state=active]:bg-primary data-[state=active]:text-white px-5 py-2.5">Itinerary</TabsTrigger>
          <TabsTrigger value="hotels" data-testid="tab-hotels" className="rounded-full data-[state=active]:bg-primary data-[state=active]:text-white px-5 py-2.5">Hotels</TabsTrigger>
          <TabsTrigger value="restaurants" data-testid="tab-restaurants" className="rounded-full data-[state=active]:bg-primary data-[state=active]:text-white px-5 py-2.5">Restaurants</TabsTrigger>
          <TabsTrigger value="map" data-testid="tab-map" className="rounded-full data-[state=active]:bg-primary data-[state=active]:text-white px-5 py-2.5">Map</TabsTrigger>
          <TabsTrigger value="expenses" data-testid="tab-expenses" className="rounded-full data-[state=active]:bg-primary data-[state=active]:text-white px-5 py-2.5">Expenses</TabsTrigger>
        </TabsList>
        <TabsContent value="itinerary"><ItineraryTab trip={trip} onUpdate={setTrip} /></TabsContent>
        <TabsContent value="hotels"><PlacesTab trip={trip} type="hotel" /></TabsContent>
        <TabsContent value="restaurants"><PlacesTab trip={trip} type="restaurant" /></TabsContent>
        <TabsContent value="map"><MapTab trip={trip} /></TabsContent>
        <TabsContent value="expenses"><ExpensesTab trip={trip} /></TabsContent>
      </Tabs>
    </div>
  );
}
