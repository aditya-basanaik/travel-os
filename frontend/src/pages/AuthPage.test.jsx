import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import AuthPage from "./AuthPage";
import { AuthProvider } from "@/context/AuthContext";
import api from "@/lib/api";

jest.mock("@/lib/api", () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn() },
  fmtErr: (error) => error?.response?.data?.detail || "Something went wrong",
}));

const renderAuth = () => render(
  <AuthProvider>
    <MemoryRouter initialEntries={["/login"]}>
      <Routes>
        <Route path="/login" element={<AuthPage />} />
        <Route path="/" element={<div data-testid="dashboard-route">Dashboard</div>} />
      </Routes>
    </MemoryRouter>
  </AuthProvider>,
);

describe("AuthPage", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    api.get.mockRejectedValue(new Error("not signed in"));
  });

  test("logs in with valid credentials and redirects to Dashboard", async () => {
    api.post.mockResolvedValue({ data: { id: "user-1", name: "Traveler" } });
    renderAuth();

    fireEvent.change(screen.getByTestId("login-email-input"), { target: { value: "traveler@example.com" } });
    fireEvent.change(screen.getByTestId("login-password-input"), { target: { value: "password123" } });
    fireEvent.click(screen.getByTestId("auth-submit-button"));

    await waitFor(() => expect(screen.getByTestId("dashboard-route")).toBeInTheDocument());
    expect(api.post).toHaveBeenCalledWith("/auth/login", { email: "traveler@example.com", password: "password123" });
  });

  test("shows login errors and sign-up prompt", async () => {
    api.post.mockRejectedValue({ response: { data: { detail: "Invalid email or password" } } });
    renderAuth();

    fireEvent.change(screen.getByTestId("login-email-input"), { target: { value: "wrong@example.com" } });
    fireEvent.change(screen.getByTestId("login-password-input"), { target: { value: "wrongpass" } });
    fireEvent.click(screen.getByTestId("auth-submit-button"));

    expect(await screen.findByTestId("auth-error")).toHaveTextContent("Invalid email or password");
    expect(screen.getByTestId("auth-toggle-link")).toHaveTextContent("Sign up free");
  });

  test("preserves the typed email when switching between login and sign up", () => {
    renderAuth();
    fireEvent.change(screen.getByTestId("login-email-input"), { target: { value: "keep@example.com" } });
    fireEvent.click(screen.getByTestId("auth-toggle-link"));

    expect(screen.getByTestId("login-email-input")).toHaveValue("keep@example.com");
    expect(screen.getByTestId("auth-toggle-link")).toHaveTextContent("Sign in here");
  });
});
