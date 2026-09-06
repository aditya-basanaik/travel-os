import { NavLink, useNavigate } from "react-router-dom";
import { Compass, Sparkle, User, SignOut, AirplaneTilt, Question, HeartStraight } from "@phosphor-icons/react";
import { useAuth } from "@/context/AuthContext";

const NAV = [
  { to: "/", label: "Trips", icon: Compass, testid: "nav-trips" },
  { to: "/plan", label: "Plan", icon: Sparkle, testid: "nav-plan" },
  { to: "/profile", label: "Profile", icon: User, testid: "nav-profile" },
  { to: "/favorites", label: "Favorites", icon: HeartStraight, testid: "nav-favorites" },
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
    <div className="min-h-screen bg-background page-shell">
      {/* Desktop sidebar */}
      <aside className="hidden md:flex fixed left-0 top-0 bottom-0 w-64 flex-col bg-[#fffdf9]/90 border-r border-[#e7dfd3] p-6 z-40 shadow-[8px_0_30px_rgba(22,101,52,0.04)]">
        <div className="flex items-center gap-3 mb-10">
          <div className="w-10 h-10 rounded-2xl bg-primary flex items-center justify-center shadow-md shadow-primary/25">
            <AirplaneTilt size={22} weight="duotone" className="text-white" />
          </div>
          <span className="font-heading font-bold text-xl tracking-tight text-foreground">Travel OS</span>
        </div>
        <nav className="flex flex-col gap-2 flex-1">
          {NAV.map(({ to, label, icon: Icon, testid }) => (
            <NavLink
              key={to}
              to={to}
              end={to === "/"}
              data-testid={testid}
              className={({ isActive }) =>
                `flex items-center gap-3 px-4 py-3 rounded-full font-medium transition-all ${
                  isActive ? "bg-primary text-white shadow-md shadow-primary/20" : "text-foreground/70 hover:bg-white hover:text-primary"
                }`
              }
            >
              <Icon size={20} weight="duotone" />
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="flex items-center gap-3 pt-4 border-t border-[#ece4d9]">
          <div className="w-9 h-9 rounded-full bg-primary/10 text-primary flex items-center justify-center font-heading font-bold ring-1 ring-primary/10">
            {user?.name?.[0]?.toUpperCase() || "?"}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold truncate text-foreground">{user?.name}</p>
            <p className="text-xs text-muted-foreground truncate">{user?.email}</p>
          </div>
          <button onClick={handleLogout} data-testid="logout-button" aria-label="Log out" className="tap-scale text-muted-foreground hover:text-destructive transition-colors rounded-full p-1.5 hover:bg-secondary">
            <SignOut size={20} />
          </button>
        </div>
      </aside>

      {/* Mobile top bar */}
      <header className="md:hidden sticky top-0 z-40 glass px-4 py-3 flex items-center justify-between rounded-b-2xl border-b border-[#ece4d9]">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-xl bg-primary flex items-center justify-center shadow-sm shadow-primary/20">
            <AirplaneTilt size={18} weight="duotone" className="text-white" />
          </div>
          <span className="font-heading font-bold text-lg tracking-tight text-foreground">Travel OS</span>
        </div>
        <button onClick={handleLogout} data-testid="logout-button-mobile" aria-label="Log out" className="tap-scale text-muted-foreground hover:text-destructive rounded-full p-2 hover:bg-secondary/80">
          <SignOut size={20} />
        </button>
      </header>

      <main className="md:ml-64 pb-28 md:pb-10">
        <div className="max-w-7xl mx-auto p-4 md:p-8">{children}</div>
      </main>

      {/* Mobile bottom nav */}
      <nav className="md:hidden fixed bottom-4 left-4 right-4 z-40 glass rounded-full shadow-soft px-4 py-2 flex justify-between items-center" data-testid="mobile-bottom-nav">
        {NAV.map(({ to, label, icon: Icon, testid }) => (
          <NavLink
            key={to}
            to={to}
            end={to === "/"}
            data-testid={`${testid}-mobile`}
            className={({ isActive }) =>
              `flex flex-col items-center gap-0.5 py-1.5 px-3 rounded-full transition-all ${
                isActive ? "text-primary bg-primary/5" : "text-muted-foreground"
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
