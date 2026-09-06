import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { motion, AnimatePresence } from "framer-motion";
import { toast } from "sonner";
import { Mountains, Parachute, ForkKnife, Bank, Martini, Island, Sparkle, Minus, Plus } from "@phosphor-icons/react";
import api, { fmtErr } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const INTERESTS = [
  { key: "nature", label: "Nature", icon: Mountains },
  { key: "adventure", label: "Adventure", icon: Parachute },
  { key: "food", label: "Food", icon: ForkKnife },
  { key: "culture", label: "Culture", icon: Bank },
  { key: "nightlife", label: "Nightlife", icon: Martini },
  { key: "relaxation", label: "Relaxation", icon: Island },
];

const LOAD_MSGS = ["Reading your preferences…", "Mapping out the days…", "Finding hotels & restaurants…", "Balancing your budget…"];

export default function Planner() {
  const today = new Date().toISOString().slice(0, 10);
  const [form, setForm] = useState({ destination: "", start_date: today, end_date: today, budget: "", currency: "₹", people_count: 2, interests: [] });
  const [naturalRequest, setNaturalRequest] = useState("");
  const [generating, setGenerating] = useState(false);
  const [msgIdx, setMsgIdx] = useState(0);
  const [error, setError] = useState("");
  const navigate = useNavigate();

  const toggleInterest = (key) => {
    setForm((f) => ({ ...f, interests: f.interests.includes(key) ? f.interests.filter((i) => i !== key) : [...f.interests, key] }));
  };

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    if (form.end_date < form.start_date) { setError("End date must be after start date"); return; }
    setGenerating(true);
    setMsgIdx(0);
    const timer = setInterval(() => setMsgIdx((i) => (i + 1) % LOAD_MSGS.length), 3500);
    try {
      const { data } = await api.post("/trips/plan", { ...form, budget: Number(form.budget) });
      toast.success("Your itinerary is ready!");
      navigate(`/trips/${data.id}`);
    } catch (err) {
      setError(fmtErr(err));
      toast.error("Couldn't generate the trip");
    } finally {
      clearInterval(timer);
      setGenerating(false);
    }
  };

  const submitNatural = async () => {
    if (naturalRequest.trim().length < 10) {
      setError("Describe your trip in a little more detail.");
      return;
    }
    setError("");
    setGenerating(true);
    setMsgIdx(0);
    const timer = setInterval(() => setMsgIdx((i) => (i + 1) % LOAD_MSGS.length), 3500);
    try {
      const { data } = await api.post("/trips/plan/natural", { request: naturalRequest.trim() }, {
        timeout: 180000,
      });
      toast.success("Your itinerary is ready!");
      navigate(`/trips/${data.id}`);
    } catch (err) {
      setError(fmtErr(err));
      toast.error("Couldn't understand that trip request");
    } finally {
      clearInterval(timer);
      setGenerating(false);
    }
  };

  return (
    <div className="max-w-2xl" data-testid="planner-page">
      <p className="label-overline mb-2">AI Trip Planner</p>
      <h1 className="font-heading font-extrabold text-4xl sm:text-5xl tracking-tight mb-3">Describe the trip.<br />We'll draft the rest.</h1>
      <p className="text-muted-foreground mb-8">The AI builds a day-by-day itinerary with hotels, restaurants and a cost breakdown matched to your budget.</p>

      <AnimatePresence mode="wait">
        {generating ? (
          <motion.div key="loading" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="bg-white rounded-3xl shadow-soft p-10 flex flex-col items-center text-center" data-testid="planner-loading">
            <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mb-6">
              <Sparkle size={32} weight="duotone" className="text-primary animate-pulse" />
            </div>
            <h2 className="font-heading font-bold text-xl mb-2">Building your itinerary</h2>
            <AnimatePresence mode="wait">
              <motion.p key={msgIdx} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }}
                className="text-muted-foreground" data-testid="planner-loading-message">{LOAD_MSGS[msgIdx]}</motion.p>
            </AnimatePresence>
            <p className="text-xs text-muted-foreground mt-6">This usually takes 15–45 seconds. Hang tight.</p>
          </motion.div>
        ) : (
          <motion.form key="form" initial={{ opacity: 0 }} animate={{ opacity: 1 }} onSubmit={submit}
            className="bg-white rounded-3xl shadow-soft p-6 md:p-8 space-y-7" data-testid="planner-form">
            <div className="bg-secondary/70 rounded-2xl p-4 space-y-3">
              <div>
                <p className="font-heading font-bold">Plan from a description</p>
                <p className="text-sm text-muted-foreground">Try: “A peaceful 3-day trip near Bangalore under ₹12,000 for two.”</p>
              </div>
              <textarea
                value={naturalRequest}
                onChange={(e) => setNaturalRequest(e.target.value)}
                placeholder="Tell us about the trip you want..."
                rows={3}
                data-testid="natural-planner-input"
                className="w-full resize-none rounded-2xl border border-input bg-white px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-primary/30"
              />
              <Button type="button" variant="secondary" onClick={submitNatural} data-testid="natural-planner-submit" className="rounded-full font-bold">
                Plan from description
              </Button>
            </div>

            <div className="border-t border-border/70 pt-6">
              <p className="text-sm font-bold">Or build it with structured details</p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="destination">Destination</Label>
              <Input id="destination" required minLength={2} data-testid="planner-destination-input" value={form.destination}
                onChange={(e) => setForm({ ...form, destination: e.target.value })} placeholder="Goa, Jaipur, Bali…"
                className="rounded-full h-12 px-5" />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="start">Start date</Label>
                <Input id="start" type="date" required data-testid="planner-start-date" value={form.start_date}
                  onChange={(e) => setForm({ ...form, start_date: e.target.value })} className="rounded-full h-12 px-5" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="end">End date</Label>
                <Input id="end" type="date" required data-testid="planner-end-date" value={form.end_date}
                  onChange={(e) => setForm({ ...form, end_date: e.target.value })} className="rounded-full h-12 px-5" />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="budget">Total budget</Label>
                <div className="flex gap-2">
                  <select value={form.currency} data-testid="planner-currency-select" aria-label="Currency"
                    onChange={(e) => setForm({ ...form, currency: e.target.value })}
                    className="h-12 rounded-full border border-input bg-white px-3 font-bold">
                    <option>₹</option><option>$</option><option>€</option><option>£</option>
                  </select>
                  <Input id="budget" type="number" min="1" required data-testid="planner-budget-input" value={form.budget}
                    onChange={(e) => setForm({ ...form, budget: e.target.value })} placeholder="50000" className="rounded-full h-12 px-5" />
                </div>
              </div>
              <div className="space-y-2">
                <Label>Travellers</Label>
                <div className="flex items-center gap-3 h-12">
                  <button type="button" data-testid="planner-people-minus" aria-label="Fewer travellers"
                    onClick={() => setForm({ ...form, people_count: Math.max(1, form.people_count - 1) })}
                    className="tap-scale w-10 h-10 rounded-full bg-secondary flex items-center justify-center"><Minus size={16} weight="bold" /></button>
                  <span className="font-heading font-bold text-xl w-8 text-center" data-testid="planner-people-count">{form.people_count}</span>
                  <button type="button" data-testid="planner-people-plus" aria-label="More travellers"
                    onClick={() => setForm({ ...form, people_count: Math.min(30, form.people_count + 1) })}
                    className="tap-scale w-10 h-10 rounded-full bg-secondary flex items-center justify-center"><Plus size={16} weight="bold" /></button>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <Label>Interests</Label>
              <div className="flex flex-wrap gap-3" data-testid="planner-interests">
                {INTERESTS.map(({ key, label, icon: Icon }) => {
                  const active = form.interests.includes(key);
                  return (
                    <button key={key} type="button" onClick={() => toggleInterest(key)} data-testid={`interest-chip-${key}`}
                      className={`tap-scale flex items-center gap-2 px-5 py-3 rounded-full font-medium transition-colors ${
                        active ? "bg-primary text-white" : "bg-secondary text-foreground hover:bg-secondary/70"}`}>
                      <Icon size={18} weight="duotone" /> {label}
                    </button>
                  );
                })}
              </div>
            </div>

            {error && <p className="text-sm text-destructive font-medium" data-testid="planner-error">{error}</p>}

            <Button type="submit" data-testid="ai-planner-submit"
              className="w-full h-14 rounded-full bg-primary hover:bg-primary/90 text-white font-heading font-bold text-lg tap-scale">
              <Sparkle size={20} weight="fill" className="mr-2" /> Generate my itinerary
            </Button>
          </motion.form>
        )}
      </AnimatePresence>
    </div>
  );
}
