import { useEffect, useRef, useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import api, { fmtErr } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export default function AuthPage() {
  const [isLogin, setIsLogin] = useState(true);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const googleButtonRef = useRef(null);
  
  const { setUser } = useAuth();
  const navigate = useNavigate();

  const handleGoogleCredential = async (response) => {
    setError("");
    setLoading(true);
    try {
      const { data } = await api.post("/auth/google/token", { id_token: response.credential });
      setUser(data);
      navigate("/", { replace: true });
    } catch (err) {
      setError(fmtErr(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const clientId = process.env.REACT_APP_GOOGLE_CLIENT_ID;
    if (!clientId || !googleButtonRef.current) return undefined;

    const renderGoogleButton = () => {
      if (!window.google?.accounts?.id || !googleButtonRef.current) return;
      googleButtonRef.current.replaceChildren();
      window.google.accounts.id.initialize({ client_id: clientId, callback: handleGoogleCredential });
      window.google.accounts.id.renderButton(googleButtonRef.current, {
        type: "standard",
        theme: "outline",
        size: "large",
        text: "continue_with",
        shape: "pill",
        width: 360,
      });
    };

    const existingScript = document.getElementById("google-gsi-script");
    if (existingScript) {
      renderGoogleButton();
      return undefined;
    }

    const script = document.createElement("script");
    script.id = "google-gsi-script";
    script.src = "https://accounts.google.com/gsi/client";
    script.async = true;
    script.defer = true;
    script.onload = renderGoogleButton;
    document.head.appendChild(script);
    return undefined;
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    
    const endpoint = isLogin ? "/auth/login" : "/auth/register";
    const payload = isLogin 
      ? { email, password } 
      : { name: name.trim(), email, password };

    try {
      const { data } = await api.post(endpoint, payload);
      setUser(data);
      navigate("/", { replace: true });
    } catch (err) {
      setError(fmtErr(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-background" data-testid="auth-page">
      <div className="w-full max-w-md bg-white rounded-3xl shadow-soft p-8 border border-border">
        
        {/* Header */}
        <div className="text-center mb-8">
          <span className="label-overline">Travel OS</span>
          <h1 className="font-heading font-extrabold text-3xl text-foreground mt-2">
            {isLogin ? "Welcome back" : "Create your account"}
          </h1>
          <p className="text-sm text-muted-foreground mt-2">
            {isLogin 
              ? "Plan, organize, and track your journeys in one place." 
              : "Start planning your next adventure today."}
          </p>
        </div>

        {/* Auth Error */}
        {error && (
          <div className="mb-6 p-4 bg-destructive/10 border border-destructive/20 text-destructive text-sm rounded-2xl" data-testid="auth-error">
            {error}
          </div>
        )}

        {/* Local Credentials Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          {!isLogin && (
            <div className="space-y-2">
              <Label htmlFor="auth-name">Full Name</Label>
              <Input
                id="auth-name"
                type="text"
                required
                data-testid="register-name-input"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="rounded-full h-12 px-5"
                placeholder="John Doe"
              />
            </div>
          )}
          
          <div className="space-y-2">
            <Label htmlFor="auth-email">Email Address</Label>
            <Input
              id="auth-email"
              type="email"
              required
              data-testid="login-email-input"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="rounded-full h-12 px-5"
              placeholder="you@example.com"
            />
          </div>

          <div className="space-y-2">
            <div className="flex justify-between items-center">
              <Label htmlFor="auth-password">Password</Label>
              {isLogin && (
                <Link to="/forgot-password" className="text-xs text-primary font-bold hover:underline">
                  Forgot?
                </Link>
              )}
            </div>
            <Input
              id="auth-password"
              type="password"
              required
              data-testid="login-password-input"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="rounded-full h-12 px-5"
              placeholder="••••••••"
            />
          </div>

          <Button
            type="submit"
            disabled={loading}
            data-testid="auth-submit-button"
            className="w-full h-12 rounded-full bg-primary text-white font-bold tap-scale mt-2"
          >
            {loading ? "Please wait..." : isLogin ? "Sign In" : "Register"}
          </Button>
        </form>

        {/* Divider */}
        <div className="flex items-center my-6">
          <div className="flex-grow border-t border-border"></div>
          <span className="mx-4 text-xs uppercase tracking-wider text-muted-foreground font-semibold">Or continue with</span>
          <div className="flex-grow border-t border-border"></div>
        </div>

        {/* Direct Google Identity Services button */}
        {process.env.REACT_APP_GOOGLE_CLIENT_ID ? (
          <div ref={googleButtonRef} className="min-h-10 flex justify-center" data-testid="google-signin-button" />
        ) : (
          <p className="text-center text-xs text-muted-foreground" data-testid="google-config-error">
            Google login is not configured for this web build.
          </p>
        )}

        {/* Toggle Option */}
        <div className="text-center mt-8 text-sm">
          <span className="text-muted-foreground">
            {isLogin ? "Don't have an account?" : "Already have an account?"}{" "}
          </span>
          <button
            onClick={() => {
              setIsLogin(!isLogin);
              setError("");
            }}
            className="text-primary font-bold hover:underline"
            data-testid="auth-toggle-link"
          >
            {isLogin ? "Sign up free" : "Sign in here"}
          </button>
        </div>

      </div>
    </div>
  );
}
