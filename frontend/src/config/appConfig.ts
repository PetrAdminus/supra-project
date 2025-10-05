const rawMode = (import.meta.env.VITE_API_MODE ?? "mock").toLowerCase();
const rawSupraBaseUrl = (import.meta.env.VITE_SUPRA_API_BASE_URL ?? "http://localhost:8000").replace(/\/$/, "");

export type ApiMode = "mock" | "supra";

export const appConfig: { apiMode: ApiMode; supraApiBaseUrl: string } = {
  apiMode: rawMode === "supra" ? "supra" : "mock",
  supraApiBaseUrl: rawSupraBaseUrl,
};
