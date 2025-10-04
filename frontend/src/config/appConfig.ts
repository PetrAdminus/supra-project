const rawMode = (import.meta.env.VITE_API_MODE ?? 'mock').toLowerCase();

export type ApiMode = 'mock' | 'supra';

export const appConfig: { apiMode: ApiMode } = {
  apiMode: rawMode === 'supra' ? 'supra' : 'mock',
};
