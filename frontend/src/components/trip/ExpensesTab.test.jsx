import { render, screen, waitFor } from "@testing-library/react";
import ExpensesTab from "./ExpensesTab";
import api from "@/lib/api";

jest.mock("@/lib/api", () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), put: jest.fn(), delete: jest.fn() },
  fmtErr: () => "Unable to update expense",
}));
jest.mock("sonner", () => ({ toast: { success: jest.fn(), error: jest.fn(), info: jest.fn() } }));

const trip = { id: "trip-1", budget: 1000, currency: "₹" };

test("includes queued offline expense exactly once in totals", async () => {
  Object.defineProperty(window.navigator, "onLine", { configurable: true, value: false });
  localStorage.setItem("expense_queue_trip-1", JSON.stringify([
    { category: "food", amount: 50, note: "Queued meal", client_id: "client-1" },
  ]));
  api.get.mockImplementation((path) => {
    if (path.endsWith("/summary")) {
      return Promise.resolve({ data: { spent: 100, budget: 1000, by_category: { food: 100 } } });
    }
    return Promise.resolve({ data: [{ id: "expense-1", category: "food", amount: 100, note: "Confirmed" }] });
  });

  render(<ExpensesTab trip={trip} />);

  await waitFor(() => expect(screen.getByTestId("spent-card")).toHaveTextContent("₹150"));
  expect(screen.getByTestId("remaining-card")).toHaveTextContent("₹850");
  expect(screen.getByTestId("expense-queued-0")).toHaveTextContent("Pending sync");
  expect(screen.getByTestId("category-breakdown")).toHaveTextContent("₹150");
});
