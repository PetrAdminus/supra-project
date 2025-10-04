import { useMutation, useQueryClient } from '@tanstack/react-query';
import {
  recordClientWhitelistSnapshot,
  recordConsumerWhitelistSnapshot,
  updateGasConfig,
  updateTreasuryControls,
  updateTreasuryDistribution,
  updateVrfConfig,
} from '../../../api/client';
import type {
  AdminMutationResult,
  RecordClientWhitelistInput,
  RecordConsumerWhitelistInput,
  UpdateGasConfigInput,
  UpdateTreasuryControlsInput,
  UpdateTreasuryDistributionInput,
  UpdateVrfConfigInput,
} from '../../../api/types';
import { ADMIN_CONFIG_QUERY_KEY } from './useAdminConfig';
import { WHITELIST_STATUS_QUERY_KEY } from './useWhitelistStatus';

function useInvalidateAdminConfig(): () => void {
  const queryClient = useQueryClient();
  return () => {
    void queryClient.invalidateQueries({ queryKey: ADMIN_CONFIG_QUERY_KEY });
  };
}

function useInvalidateWhitelistStatus(): () => void {
  const queryClient = useQueryClient();
  return () => {
    void queryClient.invalidateQueries({ queryKey: WHITELIST_STATUS_QUERY_KEY });
  };
}

export function useUpdateGasConfigMutation() {
  const invalidateAdminConfig = useInvalidateAdminConfig();

  return useMutation<AdminMutationResult, unknown, UpdateGasConfigInput>({
    mutationFn: updateGasConfig,
    onSuccess: () => invalidateAdminConfig(),
  });
}

export function useUpdateVrfConfigMutation() {
  const invalidateAdminConfig = useInvalidateAdminConfig();

  return useMutation<AdminMutationResult, unknown, UpdateVrfConfigInput>({
    mutationFn: updateVrfConfig,
    onSuccess: () => invalidateAdminConfig(),
  });
}

export function useUpdateTreasuryDistributionMutation() {
  const invalidateAdminConfig = useInvalidateAdminConfig();

  return useMutation<AdminMutationResult, unknown, UpdateTreasuryDistributionInput>({
    mutationFn: updateTreasuryDistribution,
    onSuccess: () => invalidateAdminConfig(),
  });
}

export function useUpdateTreasuryControlsMutation() {
  const invalidateAdminConfig = useInvalidateAdminConfig();

  return useMutation<AdminMutationResult, unknown, UpdateTreasuryControlsInput>({
    mutationFn: updateTreasuryControls,
    onSuccess: () => invalidateAdminConfig(),
  });
}

export function useRecordClientWhitelistMutation() {
  const invalidateAdminConfig = useInvalidateAdminConfig();
  const invalidateWhitelist = useInvalidateWhitelistStatus();

  return useMutation<AdminMutationResult, unknown, RecordClientWhitelistInput>({
    mutationFn: recordClientWhitelistSnapshot,
    onSuccess: () => {
      invalidateAdminConfig();
      invalidateWhitelist();
    },
  });
}

export function useRecordConsumerWhitelistMutation() {
  const invalidateAdminConfig = useInvalidateAdminConfig();
  const invalidateWhitelist = useInvalidateWhitelistStatus();

  return useMutation<AdminMutationResult, unknown, RecordConsumerWhitelistInput>({
    mutationFn: recordConsumerWhitelistSnapshot,
    onSuccess: () => {
      invalidateAdminConfig();
      invalidateWhitelist();
    },
  });
}
