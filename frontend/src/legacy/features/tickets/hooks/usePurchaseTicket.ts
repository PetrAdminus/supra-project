import { useMutation, useQueryClient } from '@tanstack/react-query';
import { purchaseTicket } from '../../../api/client';
import type { PurchaseTicketInput, TicketPurchase } from '../../../api/types';

const TICKETS_QUERY_KEY = ['lottery', 'tickets'] as const;

export function usePurchaseTicket() {
  const queryClient = useQueryClient();

  return useMutation<TicketPurchase, Error, PurchaseTicketInput>({
    mutationFn: purchaseTicket,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: TICKETS_QUERY_KEY });
    },
  });
}
