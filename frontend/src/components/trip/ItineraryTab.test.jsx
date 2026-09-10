import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import ItineraryTab from "./ItineraryTab";
import api from "@/lib/api";

jest.mock("@/lib/api", () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), put: jest.fn(), delete: jest.fn() },
  fmtErr: () => "Unable to update itinerary",
}));
jest.mock("sonner", () => ({ toast: { success: jest.fn(), error: jest.fn() } }));

const baseTrip = {
  id: "trip-1",
  destination: "Goa",
  currency: "₹",
  itinerary: {
    cost_breakdown: { food: 100, activities: 200 },
    days: [{
      day_number: 1,
      date: "2026-01-29",
      title: "Arrival",
      estimated_cost: 300,
      activities: [{ time: "09:00", title: "Beach", type: "activity", estimated_cost: 200, description: "" }],
    }],
  },
};

const renderItinerary = () => {
  let currentTrip = baseTrip;
  const onUpdate = jest.fn((next) => { currentTrip = next; });
  const view = render(<ItineraryTab trip={currentTrip} onUpdate={onUpdate} />);
  return { ...view, onUpdate };
};

describe("ItineraryTab day management", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    api.get.mockResolvedValue({ data: {} });
    window.confirm = jest.fn(() => true);
  });

  test("adds a day through the API and updates the displayed cost summary", async () => {
    api.post.mockResolvedValue({ data: {
      ...baseTrip,
      itinerary: {
        ...baseTrip.itinerary,
        days: [...baseTrip.itinerary.days, { day_number: 2, date: "2026-01-30", title: "Day 2", estimated_cost: 0, activities: [] }],
        cost_breakdown: { food: 100, activities: 200 },
        estimated_cost: 300,
      },
    } });
    renderItinerary();
    fireEvent.click(screen.getByTestId("itinerary-edit-btn"));
    fireEvent.click(screen.getByTestId("day-add"));

    await waitFor(() => expect(api.post).toHaveBeenCalledWith("/trips/trip-1/itinerary/days"));
    expect(screen.getByTestId("cost-breakdown")).toHaveTextContent("₹100");
    expect(screen.getByTestId("cost-breakdown")).toHaveTextContent("₹200");
  });

  test("removes a day through the API and refreshes the displayed cost summary", async () => {
    api.delete.mockResolvedValue({ data: {
      ...baseTrip,
      itinerary: { ...baseTrip.itinerary, cost_breakdown: { food: 100, activities: 0 }, estimated_cost: 100 },
    } });
    const trip = {
      ...baseTrip,
      itinerary: {
        ...baseTrip.itinerary,
        days: [
          ...baseTrip.itinerary.days,
          { day_number: 2, date: "2026-01-30", title: "Day 2", estimated_cost: 200, activities: [] },
        ],
      },
    };
    render(<ItineraryTab trip={trip} onUpdate={jest.fn()} />);
    fireEvent.click(screen.getByTestId("itinerary-edit-btn"));
    fireEvent.click(screen.getByTestId("day-remove-0"));

    await waitFor(() => expect(api.delete).toHaveBeenCalledWith("/trips/trip-1/itinerary/days/1"));
    expect(screen.getByTestId("cost-breakdown")).toHaveTextContent("₹100");
  });
});
