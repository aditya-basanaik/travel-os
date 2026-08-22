import { useCallback, useEffect, useState } from "react";
import { toast } from "sonner";
import { ForkKnife, Bed, Car, Compass, Package, Trash, PencilSimple, CloudArrowUp, WifiSlash } from "@phosphor-icons/react";
import api, { fmtErr } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Progress } from "@/components/ui/progress";

const CATEGORIES = [
  { key: "food", label: "Food", icon: ForkKnife },
  { key: "stay", label: "Stay", icon: Bed },
  { key: "transport", label: "Transport", icon: Car },
  { key: "activities", label: "Activities", icon: Compass },
  { key: "misc", label: "Misc", icon: Package },
];

const clientId = () => window.crypto?.randomUUID?.() || `expense-${Date.now()}-${Math.random().toString(36).slice(2)}`;

export default function ExpensesTab({ trip }) {
  const queueKey = `expense_queue_${trip.id}`;
  const [expenses, setExpenses] = useState(null);
  const [summary, setSummary] = useState(null);
  const [queue, setQueue] = useState(() => JSON.parse(localStorage.getItem(queueKey) || "[]"));
  const [syncing, setSyncing] = useState(false);
  const [form, setForm] = useState({ category: "food", amount: "", note: "" });
  const [adding, setAdding] = useState(false);
  const [editingId, setEditingId] = useState(null);

  const saveQueue = (q) => {
    setQueue(q);
    localStorage.setItem(queueKey, JSON.stringify(q));
  };

  const load = useCallback(() => {
    api.get(`/trips/${trip.id}/expenses`).then(({ data }) => setExpenses(data)).catch((e) => toast.error(fmtErr(e)));
    api.get(`/trips/${trip.id}/expenses/summary`).then(({ data }) => setSummary(data)).catch(() => {});
  }, [trip.id]);

  const syncQueue = useCallback(async () => {
    const q = JSON.parse(localStorage.getItem(queueKey) || "[]");
    if (!q.length || !navigator.onLine) return;
    setSyncing(true);
    const remaining = [];
    for (const item of q) {
      try { await api.post(`/trips/${trip.id}/expenses`, item); }
      catch { remaining.push(item); }
    }
    saveQueue(remaining);
    setSyncing(false);
    if (remaining.length < q.length) {
      toast.success("Offline expenses synced");
      load();
    }
  }, [queueKey, trip.id, load]);

  useEffect(() => {
    load();
    syncQueue();
    window.addEventListener("online", syncQueue);
    return () => window.removeEventListener("online", syncQueue);
  }, [load, syncQueue]);

  const addExpense = async (e) => {
    e.preventDefault();
    setAdding(true);
    const payload = { category: form.category, amount: Number(form.amount), note: form.note || null, client_id: clientId() };
    try {
      if (editingId) {
        await api.put(`/expenses/${editingId}`, payload);
        toast.success("Expense updated");
        setEditingId(null);
      } else {
        await api.post(`/trips/${trip.id}/expenses`, payload);
        toast.success("Expense logged");
      }
      setForm({ ...form, amount: "", note: "" });
      load();
    } catch (err) {
      if (!err.response) {
        saveQueue([...queue, payload]);
        toast.info("You're offline — expense queued and will sync when you're back", { icon: <WifiSlash size={16} /> });
        setForm({ ...form, amount: "", note: "" });
      } else {
        toast.error(fmtErr(err));
      }
    } finally {
      setAdding(false);
    }
  };

  const edit = (expense) => {
    setEditingId(expense.id);
    setForm({ category: expense.category, amount: String(expense.amount), note: expense.note || "" });
    window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" });
  };

  const remove = async (id) => {
    try {
      await api.delete(`/expenses/${id}`);
      toast.success("Expense deleted");
      load();
    } catch (e) { toast.error(fmtErr(e)); }
  };

  const spent = summary?.spent || 0;
  const budget = summary?.budget || trip.budget;
  const pct = budget > 0 ? Math.min(100, (spent / budget) * 100) : 0;
  const over = spent > budget;

  return (
    <div data-testid="expenses-tab">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <div className="bg-white rounded-3xl shadow-soft p-6" data-testid="budget-card">
          <p className="label-overline mb-2">Budget</p>
          <p className="font-heading font-extrabold text-3xl">{trip.currency}{budget.toLocaleString()}</p>
        </div>
        <div className="bg-white rounded-3xl shadow-soft p-6" data-testid="spent-card">
          <p className="label-overline mb-2">Spent</p>
          <p className={`font-heading font-extrabold text-3xl ${over ? "text-accent" : ""}`}>{trip.currency}{spent.toLocaleString()}</p>
        </div>
        <div className="bg-white rounded-3xl shadow-soft p-6" data-testid="remaining-card">
          <p className="label-overline mb-2">{over ? "Over budget" : "Remaining"}</p>
          <p className={`font-heading font-extrabold text-3xl ${over ? "text-accent" : "text-primary"}`}>
            {trip.currency}{Math.abs(budget - spent).toLocaleString()}
          </p>
        </div>
      </div>

      <div className="bg-white rounded-3xl shadow-soft p-6 mb-8" data-testid="budget-progress-card">
        <div className="flex justify-between text-sm font-bold mb-3">
          <span>{pct.toFixed(0)}% of budget used</span>
          {(syncing || queue.length > 0) && (
            <span className="flex items-center gap-1.5 text-accent" data-testid="expense-sync-badge">
              <CloudArrowUp size={16} /> {syncing ? "Syncing…" : `${queue.length} queued offline`}
            </span>
          )}
        </div>
        <Progress value={pct} className="h-3 bg-secondary [&>div]:bg-primary" />
        <div className="mt-5 space-y-2.5" data-testid="category-breakdown">
          {CATEGORIES.map(({ key, label, icon: Icon }) => {
            const amt = summary?.by_category?.[key] || 0;
            const w = spent > 0 ? (amt / spent) * 100 : 0;
            return (
              <div key={key} className="flex items-center gap-3">
                <Icon size={16} weight="duotone" className="text-muted-foreground shrink-0" />
                <span className="text-xs font-bold w-20 shrink-0">{label}</span>
                <div className="flex-1 h-2 bg-secondary rounded-full overflow-hidden">
                  <div className="h-full bg-primary/70 rounded-full transition-[width]" style={{ width: `${w}%` }} />
                </div>
                <span className="text-xs font-bold w-20 text-right">{trip.currency}{amt.toLocaleString()}</span>
              </div>
            );
          })}
        </div>
      </div>

      <form onSubmit={addExpense} className="bg-white rounded-3xl shadow-soft p-6 mb-8" data-testid="expense-form">
        <p className="label-overline mb-4">{editingId ? "Edit expense" : "Log an expense"}</p>
        <div className="flex flex-wrap gap-2 mb-4">
          {CATEGORIES.map(({ key, label, icon: Icon }) => (
            <button key={key} type="button" onClick={() => setForm({ ...form, category: key })} data-testid={`expense-category-${key}`}
              className={`tap-scale flex items-center gap-1.5 px-4 py-2 rounded-full text-sm font-medium transition-colors ${
                form.category === key ? "bg-primary text-white" : "bg-secondary"}`}>
              <Icon size={15} weight="duotone" /> {label}
            </button>
          ))}
        </div>
        <div className="flex flex-col sm:flex-row gap-3">
          <Input type="number" min="0.01" step="0.01" required placeholder={`Amount (${trip.currency})`} data-testid="expense-amount-input"
            value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} className="rounded-full h-12 px-5 sm:w-44" />
          <Input placeholder="Note (optional)" maxLength={200} data-testid="expense-note-input"
            value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} className="rounded-full h-12 px-5 flex-1" />
          <Button type="submit" disabled={adding} data-testid="expense-add-button" className="rounded-full h-12 px-8 bg-primary text-white font-bold tap-scale">
            {adding ? "Saving…" : editingId ? "Save" : "Add"}
          </Button>
        </div>
      </form>

      <div className="space-y-3" data-testid="expense-list">
        {queue.map((q, i) => (
          <div key={`q-${i}`} className="flex items-center gap-4 bg-accent/5 border border-accent/20 rounded-3xl px-5 py-4" data-testid={`expense-queued-${i}`}>
            <span className="flex-1 text-sm"><span className="font-bold capitalize">{q.category}</span>{q.note ? ` · ${q.note}` : ""}</span>
            <span className="text-xs font-bold text-accent uppercase tracking-wider">Offline</span>
            <span className="font-heading font-bold">{trip.currency}{Number(q.amount).toLocaleString()}</span>
          </div>
        ))}
        {expenses === null ? (
          <p className="text-sm text-muted-foreground">Loading…</p>
        ) : expenses.length === 0 && queue.length === 0 ? (
          <div className="bg-secondary/60 rounded-3xl p-10 text-center" data-testid="expenses-empty">
            <p className="text-muted-foreground">No expenses yet. Log your first one above — it even works offline.</p>
          </div>
        ) : (
          expenses.map((exp) => {
            const cat = CATEGORIES.find((c) => c.key === exp.category) || CATEGORIES[4];
            const Icon = cat.icon;
            return (
              <div key={exp.id} className="flex items-center gap-4 bg-white rounded-3xl shadow-soft px-5 py-4" data-testid={`expense-item-${exp.id}`}>
                <span className="w-10 h-10 rounded-full bg-secondary flex items-center justify-center shrink-0">
                  <Icon size={18} weight="duotone" />
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold capitalize">{exp.category}</p>
                  {exp.note && <p className="text-xs text-muted-foreground truncate">{exp.note}</p>}
                </div>
                <span className="font-heading font-bold">{trip.currency}{exp.amount.toLocaleString()}</span>
                <button onClick={() => edit(exp)} data-testid={`expense-edit-${exp.id}`} aria-label="Edit expense"
                  className="tap-scale w-9 h-9 rounded-full hover:bg-secondary text-muted-foreground flex items-center justify-center transition-colors">
                  <PencilSimple size={16} />
                </button>
                <button onClick={() => remove(exp.id)} data-testid={`expense-delete-${exp.id}`} aria-label="Delete expense"
                  className="tap-scale w-9 h-9 rounded-full hover:bg-destructive/10 hover:text-destructive text-muted-foreground flex items-center justify-center transition-colors">
                  <Trash size={16} />
                </button>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
