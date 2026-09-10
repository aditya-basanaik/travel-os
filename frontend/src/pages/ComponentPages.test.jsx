import { fireEvent, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import Dashboard from "./Dashboard";
import Favorites from "./Favorites";
import { AuthProvider } from "@/context/AuthContext";
import api from "@/lib/api";

jest.mock("@/components/ui/dropdown-menu", () => ({
  DropdownMenu: ({ children }) => <div>{children}</div>,
  DropdownMenuContent: ({ children }) => <div>{children}</div>,
  DropdownMenuItem: ({ children }) => <div>{children}</div>,
  DropdownMenuTrigger: ({ children }) => <div>{children}</div>,
}));

jest.mock("@/lib/api", () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), delete: jest.fn() },
  fmtErr: () => "Unable to load",
}));
jest.mock("@/context/AuthContext", () => ({
  useAuth: () => ({ user: { name: "Ada Traveler" } }),
  AuthProvider: ({ children }) => children,
}));

const trip = {
  id: "trip-1",
  title: "Goa Weekend",
  destination: "Goa",
  start_date: "2026-01-29",
  end_date: "2026-02-02",
  people_count: 2,
  currency: "₹",
  budget: 10000,
  status: "planned",
  cover_image: "https://example.com/goa.jpg",
};

const renderPage = (page) => render(<MemoryRouter>{page}</MemoryRouter>);

describe("Dashboard", () => {
  beforeEach(() => jest.clearAllMocks());

  test("shows loading skeleton before trips arrive", () => {
    api.get.mockImplementation(() => new Promise(() => {}));
    renderPage(<AuthProvider><Dashboard /></AuthProvider>);
    expect(screen.getByTestId("trips-loading")).toBeInTheDocument();
  });

  test("renders trip cards correctly", async () => {
    api.get.mockImplementation((path) => {
      if (path === "/trips") return Promise.resolve({ data: { items: [trip] } });
      if (path === "/trips/deleted") return Promise.resolve({ data: { items: [] } });
      return Promise.resolve({ data: { favourite_destinations: [] } });
    });
    renderPage(<Dashboard />);

    expect(await screen.findByTestId("trip-card-trip-1")).toBeInTheDocument();
    expect(screen.getByText("Goa Weekend")).toBeInTheDocument();
  });

  test("shows the empty state when there are no trips", async () => {
    api.get.mockImplementation((path) => {
      if (path === "/trips") return Promise.resolve({ data: { items: [] } });
      if (path === "/trips/deleted") return Promise.resolve({ data: { items: [] } });
      return Promise.resolve({ data: {} });
    });
    renderPage(<Dashboard />);

    expect(await screen.findByTestId("trips-empty-state")).toBeInTheDocument();
    expect(screen.getByText("No trips yet")).toBeInTheDocument();
  });
});

describe("Favorites", () => {
  beforeEach(() => jest.clearAllMocks());

  test("renders and filters favorites by type", async () => {
    api.get.mockResolvedValue({ data: [
      { id: "hotel-1", name: "Goa Stay", type: "hotel", trip_id: "trip-1", trip_destination: "Goa", meta: {} },
      { id: "food-1", name: "Goa Cafe", type: "restaurant", trip_id: "trip-1", trip_destination: "Goa", meta: {} },
    ] });
    renderPage(<Favorites />);

    expect(await screen.findByTestId("favorite-card-hotel-1")).toBeInTheDocument();
    fireEvent.click(screen.getByTestId("favorites-filter-restaurant"));
    expect(screen.getByTestId("favorite-card-food-1")).toBeInTheDocument();
    expect(screen.queryByTestId("favorite-card-hotel-1")).not.toBeInTheDocument();
  });

  test("shows the empty state with no favorites", async () => {
    api.get.mockResolvedValue({ data: [] });
    renderPage(<Favorites />);
    expect(await screen.findByTestId("favorites-empty")).toBeInTheDocument();
  });
});
