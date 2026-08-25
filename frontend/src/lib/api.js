import axios from "axios";

export const API = `${process.env.REACT_APP_BACKEND_URL || "http://localhost:8001"}/api`;

const api = axios.create({ baseURL: API, withCredentials: true, timeout: 45000 });

export function fmtErr(e) {
  const d = e?.response?.data?.detail;
  if (d == null) return e?.message || "Something went wrong. Please try again.";
  if (typeof d === "string") return d;
  if (Array.isArray(d)) return d.map((x) => (x && typeof x.msg === "string" ? x.msg : JSON.stringify(x))).join(" ");
  if (typeof d.msg === "string") return d.msg;
  return String(d);
}

let refreshing = null;
api.interceptors.response.use(
  (r) => r,
  async (error) => {
    const orig = error.config;
    if (error.response?.status === 401 && orig && !orig._retry && !orig.url.includes("/auth/")) {
      orig._retry = true;
      try {
        refreshing = refreshing || api.post("/auth/refresh").finally(() => { refreshing = null; });
        await refreshing;
        return api(orig);
      } catch {
        // refresh failed — fall through
      }
    }
    return Promise.reject(error);
  }
);

export default api;
