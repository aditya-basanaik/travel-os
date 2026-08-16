import { useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { toast } from "sonner";
import api, { fmtErr } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export default function ResetPassword() {
  const [params] = useSearchParams();
  const token = params.get("token") || "";
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await api.post("/auth/reset-password", { token, password });
      toast.success("Password updated — please log in");
      navigate("/login");
    } catch (err) {
      setError(fmtErr(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-background" data-testid="reset-password-page">
      <div className="w-full max-w-md bg-white rounded-3xl shadow-soft p-8">
        <h1 className="font-heading font-bold text-2xl mb-2">Choose a new password</h1>
        <p className="text-sm text-muted-foreground mb-6">Must be at least 8 characters.</p>
        {!token ? (
          <p className="text-sm text-destructive" data-testid="reset-missing-token">
            This reset link is missing its token. Request a new one from the{" "}
            <Link to="/forgot-password" className="underline">forgot password</Link> page.
          </p>
        ) : (
          <form onSubmit={submit} className="space-y-5">
            <div className="space-y-2">
              <Label htmlFor="new-password">New password</Label>
              <Input id="new-password" type="password" required minLength={8} data-testid="reset-password-input"
                value={password} onChange={(e) => setPassword(e.target.value)} className="rounded-full h-12 px-5" />
            </div>
            {error && <p className="text-sm text-destructive" data-testid="reset-error">{error}</p>}
            <Button type="submit" disabled={loading} data-testid="reset-submit-button"
              className="w-full h-12 rounded-full bg-primary text-white font-bold tap-scale">
              {loading ? "Updating…" : "Update password"}
            </Button>
          </form>
        )}
      </div>
    </div>
  );
}
