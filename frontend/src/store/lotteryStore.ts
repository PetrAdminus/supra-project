import { create } from "zustand";

interface LotterySelectionState {
  selectedLotteryId: number | null;
  setSelectedLotteryId: (lotteryId: number) => void;
  resetSelection: () => void;
}

export const useLotterySelectionStore = create<LotterySelectionState>((set) => ({
  selectedLotteryId: null,
  setSelectedLotteryId: (lotteryId) => set({ selectedLotteryId: lotteryId }),
  resetSelection: () => set({ selectedLotteryId: null }),
}));
