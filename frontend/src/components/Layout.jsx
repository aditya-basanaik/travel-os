import { NavLink, useNavigate } from "react-router-dom";
import { Compass, Sparkle, User, SignOut, AirplaneTilt, Question } from "@phosphor-icons/react";
import { useAuth } from "@/context/AuthContext";

const NAV = [
  { to: "/", label: "Trips", icon: Compass, testid: "nav-trips" },
  { to: "/plan", label: "Plan", icon: Sparkle, testid: "nav-plan" },
  { to: "/profile", label: "Profile", icon: User, testid: "nav-profile" },
  { to: "/help", label: "Help", icon: Question, testid: "nav-help" },
];

export default function Layout({ children }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate("/login");
  };

  return (
    <div className="min-h-screen bg-background">
      {/* Desktop sidebar */}
      <aside className="hidden md:flex fixed left-0 top-0 bottom-0 w-64 flex-col bg-secondary/60 border-r border-black/5 p-6 z-40">
        <div className="flex items-center gap-3 mb-10">
          <div className="w-10 h-10 rounded-2xl bg-primary flex items-center justify-center">
            <AirplaneTilt size={22} weight="duotone" className="text-white" />
          </div>
          <span className="font-heading font-bold text-xl tracking-tight">Travel OS</span>
        </div>
        <nav className="flex flex-col gap-2 flex-1">
          {NAV.map(({ to, label, icon: Icon, testid }) => (
            <NavLink
              key={to}
              to={to}
              end={to === "/"}
              data-testid={testid}
              className={({ isActive }) =>
                `flex items-center gap-3 px-4 py-3 rounded-full font-medium transition-colors ${
                  isActive ? "bg-primary text-white" : "text-foreground/70 hover:bg-white"
                }`
              }
            >
              <Icon size={20} weight="duotone" />
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="flex items-center gap-3 pt-4 border-t border-black/5">
          <div className="w-9 h-9 rounded-full bg-primary/10 text-primary flex items-center justify-center font-heading font-bold">
            {user?.name?.[0]?.toUpperCase() || "?"}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium truncate">{user?.name}</p>
            <p className="text-xs text-muted-foreground truncate">{user?.email}</p>
          </div>
          <button onClick={handleLogout} data-testid="logout-button" aria-label="Log out" className="tap-scale text-muted-foreground hover:text-destructive transition-colors">
            <SignOut size={20} />
          </button>
        </div>
      </aside>

      {/* Mobile top bar */}
      <header className="md:hidden sticky top-0 z-40 glass border-b border-black/5 px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-xl bg-primary flex items-center justify-center">
            <AirplaneTilt size={18} weight="duotone" className="text-white" />
          </div>
          <span className="font-heading font-bold text-lg tracking-tight">Travel OS</span>
        </div>
        <button onClick={handleLogout} data-testid="logout-button-mobile" aria-label="Log out" className="tap-scale text-muted-foreground">
          <SignOut size={20} />
        </button>
      </header>

      <main className="md:ml-64 pb-28 md:pb-10">
        <div className="max-w-6xl mx-auto p-4 md:p-8">{children}</div>
      </main>

      {/* Mobile bottom nav */}
      <nav className="md:hidden fixed bottom-4 left-4 right-4 z-40 glass rounded-full shadow-soft px-6 py-2 flex justify-between items-center" data-testid="mobile-bottom-nav">
        {NAV.map(({ to, label, icon: Icon, testid }) => (
          <NavLink
            key={to}
            to={to}
            end={to === "/"}
            data-testid={`${testid}-mobile`}
            className={({ isActive }) =>
              `flex flex-col items-center gap-0.5 py-1.5 px-4 rounded-full transition-colors ${
                isActive ? "text-primary" : "text-muted-foreground"
              }`
            }
          >
            <Icon size={24} weight={({ active }) => active ? "fill" : "duotone"} />
            <span className="text-[10px] font-bold uppercase tracking-wider">{label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}
