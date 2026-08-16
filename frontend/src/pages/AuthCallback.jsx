import { useEffect, useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import api, { fmtErr } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";

export default function AuthCallback() {
  const [error, setError] = useState("");
  const { setUser } = useAuth();
  const navigate = useNavigate();
  const ran = useRef(false);

  useEffect(() => {
    if (ran.current) return;
    ran.current = true;
    const hash = window.location.hash;
    const sessionId = new URLSearchParams(hash.replace(/^#/, "")).get("session_id");
    if (!sessionId) {
      setError("Google sign-in didn't return a session. Please try again.");
      return;
    }
    api.post("/auth/google/session", { session_id: sessionId })
      .then(({ data }) => {
        setUser(data);
        window.history.replaceState(null, "", "/");
        navigate("/", { replace: true });
      })
      .catch((e) => setError(fmtErr(e)));
  }, [navigate, setUser]);

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-background" data-testid="auth-callback-page">
      {error ? (
        <div className="text-center space-y-4">
          <p className="text-destructive font-medium" data-testid="auth-callback-error">{error}</p>
          <Link to="/login" className="text-primary font-bold underline">Back to login</Link>
        </div>
      ) : (
        <div className="flex flex-col items-center gap-4">
          <div className="w-10 h-10 rounded-full border-4 border-secondary border-t-primary animate-spin" />
          <p className="text-sm text-muted-foreground font-medium">Signing you in with Google…</p>
        </div>
      )}
    </div>
  );
}
