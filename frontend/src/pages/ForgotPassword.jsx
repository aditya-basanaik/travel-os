import { useState } from "react";
import { Link } from "react-router-dom";
import { ArrowLeft } from "@phosphor-icons/react";
import api, { fmtErr } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export default function ForgotPassword() {
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [devLink, setDevLink] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const { data } = await api.post("/auth/forgot-password", { email });
      setMessage(data.message);
      if (data.dev_reset_link) setDevLink(data.dev_reset_link);
    } catch (err) {
      setError(fmtErr(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-background" data-testid="forgot-password-page">
      <div className="w-full max-w-md bg-white rounded-3xl shadow-soft p-8">
        <Link to="/login" className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground mb-6">
          <ArrowLeft size={16} /> Back to login
        </Link>
        <h1 className="font-heading font-bold text-2xl mb-2">Reset your password</h1>
        <p className="text-sm text-muted-foreground mb-6">Enter your account email and we'll generate a reset link.</p>
        {message ? (
          <div className="space-y-4">
            <p className="text-sm text-primary font-medium" data-testid="forgot-success-message">{message}</p>
            {devLink && (
              <div className="bg-secondary rounded-2xl p-4 text-xs break-all" data-testid="dev-reset-link">
                <p className="font-bold mb-1">Dev mode (no email provider configured):</p>
                <a href={devLink} className="text-primary underline">{devLink}</a>
              </div>
            )}
          </div>
        ) : (
          <form onSubmit={submit} className="space-y-5">
            <div className="space-y-2">
              <Label htmlFor="reset-email">Email</Label>
              <Input id="reset-email" type="email" required data-testid="forgot-email-input" value={email}
                onChange={(e) => setEmail(e.target.value)} className="rounded-full h-12 px-5" placeholder="you@example.com" />
            </div>
            {error && <p className="text-sm text-destructive" data-testid="forgot-error">{error}</p>}
            <Button type="submit" disabled={loading} data-testid="forgot-submit-button"
              className="w-full h-12 rounded-full bg-primary text-white font-bold tap-scale">
              {loading ? "Sending…" : "Send reset link"}
            </Button>
          </form>
        )}
      </div>
    </div>
  );
}
