import { useEffect, useState } from "react";
import { toast } from "sonner";
import { UserCircle, Check } from "@phosphor-icons/react";
import api, { fmtErr } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const FOOD_PREFS = ["veg", "non-veg", "vegan"];
const BUDGET_PREFS = ["budget", "mid-range", "premium", "luxury"];

export default function Profile() {
  const [profile, setProfile] = useState(null);
  const [form, setForm] = useState({ name: "", photo_url: "", age: "", budget_pref: "mid-range", food_pref: "veg", languages: "", favourite_destinations: "" });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    api.get("/profile").then(({ data }) => {
      setProfile(data);
      setForm({
        name: data.name || "",
        photo_url: data.photo_url || "",
        age: data.age || "",
        budget_pref: data.budget_pref || "mid-range",
        food_pref: data.food_pref || "veg",
        languages: (data.languages || []).join(", "),
        favourite_destinations: (data.favourite_destinations || []).join(", "),
      });
    }).catch((e) => setError(fmtErr(e)));
  }, []);

  const save = async (e) => {
    e.preventDefault();
    setError("");
    setSaving(true);
    try {
      const payload = {
        name: form.name,
        photo_url: form.photo_url || null,
        age: form.age ? Number(form.age) : null,
        budget_pref: form.budget_pref,
        food_pref: form.food_pref,
        languages: form.languages.split(",").map((s) => s.trim()).filter(Boolean),
        favourite_destinations: form.favourite_destinations.split(",").map((s) => s.trim()).filter(Boolean),
      };
      const { data } = await api.put("/profile", payload);
      setProfile(data);
      toast.success("Profile saved");
    } catch (err) {
      setError(fmtErr(err));
    } finally {
      setSaving(false);
    }
  };

  if (!profile) {
    return <p className="text-muted-foreground" data-testid="profile-loading">Loading profile…</p>;
  }

  return (
    <div className="max-w-2xl" data-testid="profile-page">
      <p className="label-overline mb-2">Profile</p>
      <h1 className="font-heading font-extrabold text-4xl tracking-tight mb-8">Your traveller profile</h1>

      <div className="bg-white rounded-3xl shadow-soft p-6 mb-6 flex items-center gap-5">
        {form.photo_url ? (
          <img src={form.photo_url} alt="Profile" className="w-20 h-20 rounded-full object-cover" data-testid="profile-photo" />
        ) : (
          <div className="w-20 h-20 rounded-full bg-primary/10 text-primary flex items-center justify-center">
            <UserCircle size={44} weight="duotone" />
          </div>
        )}
        <div>
          <p className="font-heading font-bold text-xl" data-testid="profile-name-display">{profile.name}</p>
          <p className="text-sm text-muted-foreground">{profile.email}</p>
          <p className="text-xs text-muted-foreground mt-1" data-testid="profile-past-trips">{profile.past_trips} saved {profile.past_trips === 1 ? "trip" : "trips"}</p>
        </div>
      </div>

      <form onSubmit={save} className="bg-white rounded-3xl shadow-soft p-6 md:p-8 space-y-6" data-testid="profile-form">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
          <div className="space-y-2">
            <Label htmlFor="pname">Name</Label>
            <Input id="pname" required data-testid="profile-name-input" value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })} className="rounded-full h-12 px-5" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="page">Age</Label>
            <Input id="page" type="number" min="1" max="120" data-testid="profile-age-input" value={form.age}
              onChange={(e) => setForm({ ...form, age: e.target.value })} className="rounded-full h-12 px-5" placeholder="28" />
          </div>
        </div>

        <div className="space-y-2">
          <Label htmlFor="pphoto">Profile photo URL</Label>
          <Input id="pphoto" type="url" data-testid="profile-photo-input" value={form.photo_url}
            onChange={(e) => setForm({ ...form, photo_url: e.target.value })} className="rounded-full h-12 px-5" placeholder="https://…" />
        </div>

        <div className="space-y-3">
          <Label>Food preference</Label>
          <div className="flex flex-wrap gap-2">
            {FOOD_PREFS.map((f) => (
              <button key={f} type="button" onClick={() => setForm({ ...form, food_pref: f })} data-testid={`food-pref-${f}`}
                className={`tap-scale px-5 py-2.5 rounded-full text-sm font-medium capitalize transition-colors ${form.food_pref === f ? "bg-primary text-white" : "bg-secondary"}`}>
                {f}
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-3">
          <Label>Preferred budget range</Label>
          <div className="flex flex-wrap gap-2">
            {BUDGET_PREFS.map((b) => (
              <button key={b} type="button" onClick={() => setForm({ ...form, budget_pref: b })} data-testid={`budget-pref-${b}`}
                className={`tap-scale px-5 py-2.5 rounded-full text-sm font-medium capitalize transition-colors ${form.budget_pref === b ? "bg-primary text-white" : "bg-secondary"}`}>
                {b}
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-2">
          <Label htmlFor="plang">Preferred languages <span className="text-muted-foreground font-normal">(comma separated)</span></Label>
          <Input id="plang" data-testid="profile-languages-input" value={form.languages}
            onChange={(e) => setForm({ ...form, languages: e.target.value })} className="rounded-full h-12 px-5" placeholder="English, Hindi" />
        </div>

        <div className="space-y-2">
          <Label htmlFor="pdest">Favourite destinations <span className="text-muted-foreground font-normal">(comma separated)</span></Label>
          <Input id="pdest" data-testid="profile-destinations-input" value={form.favourite_destinations}
            onChange={(e) => setForm({ ...form, favourite_destinations: e.target.value })} className="rounded-full h-12 px-5" placeholder="Goa, Manali, Kyoto" />
        </div>

        {error && <p className="text-sm text-destructive font-medium" data-testid="profile-error">{error}</p>}

        <Button type="submit" disabled={saving} data-testid="profile-save-button"
          className="rounded-full h-12 px-8 bg-primary text-white font-bold tap-scale">
          <Check size={16} weight="bold" className="mr-1" /> {saving ? "Saving…" : "Save profile"}
        </Button>
      </form>
    </div>
  );
}
