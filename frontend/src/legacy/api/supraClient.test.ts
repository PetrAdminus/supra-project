import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  STATUS_CACHE_TTL_MS,
  completeChecklistTaskSupra,
  fetchAccountProfileSupra,
  fetchAdminConfigSupra,
  fetchAchievementsSupra,
  fetchAnnouncementsSupra,
  fetchChatMessagesSupra,
  fetchChecklistSupra,
  fetchLotteryVrfLogSupra,
  fetchLotteryStatusSupra,
  fetchWhitelistStatusSupra,
  fetchTreasuryBalancesSupra,
  fetchTreasuryConfigSupra,
  invalidateSupraStatusCache,
  listSupraCommandsSupra,
  postAnnouncementSupra,
  postChatMessageSupra,
  recordClientWhitelistSnapshotSupra,
  recordConsumerWhitelistSnapshotSupra,
  refreshSupraStatus,
  upsertAccountProfileSupra,
  updateGasConfigSupra,
  updateTreasuryDistributionSupra,
  updateVrfConfigSupra,
  unlockAchievementSupra,
} from "./supraClient";
import type { AdminConfig } from "./types";
import * as mockClient from "./mockClient";

declare global {
  var fetch: typeof fetch;
}

describe("supraClient caching", () => {
  const baseResponse = {
    timestamp: "2024-04-12T12:00:00Z",
    profile: "default",
    addresses: { lottery: "0xlottery", hub: "0xhub", factory: "0xfactory", deposit: "0xdeposit", client: "0xclient" },
    hub: {
      lottery_count: 1,
      next_lottery_id: 2,
      callback_sender: "0xsender",
      configured_lottery_ids: [0],
    },
    lotteries: [
      {
        lottery_id: 0,
        registration: { owner: "0xowner", lottery: "0xlottery", metadata: "0x", active: true },
        factory: {
          owner: "0xowner",
          lottery: "0xlottery",
          blueprint: { ticket_price: "10", jackpot_share_bps: 2500 },
        },
        instance: {
          owner: "0xowner",
          lottery: "0xlottery",
          blueprint: { ticket_price: "10", jackpot_share_bps: 2500 },
        },
        stats: { tickets_sold: 3, jackpot_accumulated: "42" },
        round: {
          snapshot: {
            ticket_count: 3,
            draw_scheduled: true,
            has_pending_request: false,
            next_ticket_id: 4,
          },
          pending_request_id: null,
        },
        treasury: {
          config: { jackpot_bps: 3000, prize_bps: 5000, operations_bps: 2000 },
          pool: { prize_balance: "12", operations_balance: "6" },
        },
      },
    ],
    deposit: {
      balance: "100",
      min_balance: "80",
      min_balance_reached: true,
      subscription_info: {
        subscription_id: "123",
        last_request_time: "2024-04-12T10:00:00Z",
        last_fulfillment_time: "2024-04-11T10:00:00Z",
      },
      contract_details: {
        callback_gas_price: "3",
        callback_gas_limit: "4",
      },
      whitelisted_contracts: ["0x001"],
      max_gas_price: "1",
      max_gas_limit: "2",
    },
    treasury: {
      jackpot_balance: "150",
      token_balance: "500",
      total_supply: "1000",
      metadata: { symbol: "SLT" },
    },
    calculation: {
      min_balance: "80",
      max_gas_price: "1",
      max_gas_limit: "2",
    },
  };

  let fetchMock: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2024-04-12T12:00:00Z"));
    invalidateSupraStatusCache();
    fetchMock = vi.spyOn(globalThis, "fetch");
  });

  afterEach(() => {
    fetchMock.mockRestore();
    vi.restoreAllMocks();
    vi.useRealTimers();
    invalidateSupraStatusCache();
  });

  function queueResponse(payload: object) {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(payload), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );
  }

  it("reuses the cached response across multiple readers", async () => {
    queueResponse(baseResponse);

    const status = await fetchLotteryStatusSupra();
    expect(status.lotteries[0]?.stats?.ticketsSold).toBe(3);
    expect(status.vrf.subscriptionId).toBe("123");

    const whitelist = await fetchWhitelistStatusSupra();
    expect(whitelist.account).toBe("0x001");
    expect(whitelist.isWhitelisted).toBe(true);

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("invalidates the cache after TTL", async () => {
    queueResponse(baseResponse);
    await fetchLotteryStatusSupra();
    expect(fetchMock).toHaveBeenCalledTimes(1);

    vi.advanceTimersByTime(STATUS_CACHE_TTL_MS + 1);

    const nextResponse = {
      ...baseResponse,
      lotteries: [
        {
          ...baseResponse.lotteries[0],
          stats: { tickets_sold: 1, jackpot_accumulated: "55" },
        },
      ],
      deposit: {
        ...baseResponse.deposit,
        whitelisted_contracts: ["0x002"],
      },
    };

    queueResponse(nextResponse);

    const status = await fetchLotteryStatusSupra();
    expect(status.lotteries[0]?.stats?.ticketsSold).toBe(1);
    expect(globalThis.fetch).toHaveBeenCalledTimes(2);
  });

  it("forces refresh via helper", async () => {
    queueResponse(baseResponse);
    await fetchLotteryStatusSupra();
    expect(fetchMock).toHaveBeenCalledTimes(1);

    const refreshed = {
      ...baseResponse,
      lotteries: [
        {
          ...baseResponse.lotteries[0],
          stats: { tickets_sold: 5, jackpot_accumulated: "99" },
        },
      ],
    };

    queueResponse(refreshed);

    const result = await refreshSupraStatus();
    expect(Array.isArray(result.lotteries)).toBe(true);
    expect(globalThis.fetch).toHaveBeenCalledTimes(2);
  });

  it("maps VRF log payloads and respects the requested limit", async () => {
    queueResponse({
      lottery_id: 7,
      limit: 50,
      round: {
        snapshot: { ticket_count: 128, next_ticket_id: 129, draw_scheduled: true },
        pending_request_id: "0xabc",
        requests: [
          {
            event_type: "lottery::DrawRequestIssuedEvent",
            timestamp: "2024-05-24T10:15:00Z",
            data: { request_id: "0xabc", round_id: 3 },
          },
        ],
        fulfillments: [
          {
            event_type: "lottery::DrawFulfilledEvent",
            data: { request_id: "0xabc", round_id: 3, winner_index: 42 },
          },
        ],
      },
      hub: {
        requests: [
          {
            event_type: "lottery_vrf_gateway::RandomnessRequestedEvent",
            data: { request_id: "0xabc" },
          },
        ],
        fulfillments: [
          {
            event_type: "lottery_vrf_gateway::RandomnessFulfilledEvent",
            data: { request_id: "0xabc", randomness: "0x4455" },
          },
        ],
      },
    });

    const log = await fetchLotteryVrfLogSupra(7, 10);

    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining("/lotteries/7/vrf-log?limit=10"),
      expect.objectContaining({ headers: expect.objectContaining({ Accept: "application/json" }) }),
    );
    expect(log.lotteryId).toBe(7);
    expect(log.limit).toBe(10);
    expect(log.round.pendingRequestId).toBe("0xabc");
    expect(log.round.snapshot?.["ticket_count"]).toBe(128);
    expect(log.round.requests).toHaveLength(1);
    expect(log.hub.fulfillments[0]?.event_type).toBe("lottery_vrf_gateway::RandomnessFulfilledEvent");
  });

  it("clamps limit and falls back to the requested lottery id", async () => {
    queueResponse({});

    const log = await fetchLotteryVrfLogSupra(3, 9999);

    expect(log.limit).toBe(500);
    expect(log.lotteryId).toBe(3);
    expect(log.round.requests).toHaveLength(0);
    expect(log.hub.fulfillments).toHaveLength(0);
  });

  it("fetches chat messages и нормализует комнату", async () => {
    queueResponse([
      {
        id: 1,
        room: "GLOBAL",
        sender_address: "0xabc",
        body: "Привет",
        metadata: { mood: "happy" },
        created_at: "2024-04-12T11:00:00Z",
      },
      {
        id: 2,
        room: "",
        sender_address: null,
        body: "",
        metadata: null,
        created_at: null,
      },
    ]);

    const messages = await fetchChatMessagesSupra(" Global ", 5);

    expect(fetchMock).toHaveBeenLastCalledWith(
      "http://localhost:8000/chat/messages?room=global&limit=5",
      expect.objectContaining({ headers: expect.objectContaining({ Accept: "application/json" }) }),
    );
    expect(messages).toHaveLength(2);
    expect(messages[0]).toMatchObject({
      id: 1,
      room: "global",
      senderAddress: "0xabc",
      body: "Привет",
      metadata: { mood: "happy" },
    });
    expect(messages[1].metadata).toEqual({});
  });

  it("отправляет сообщения в чат с нормализацией тела", async () => {
    queueResponse({
      id: 99,
      room: "global",
      sender_address: "0xabc",
      body: "Привет",
      metadata: { locale: "ru" },
      created_at: "2024-04-12T11:05:00Z",
    });

    const result = await postChatMessageSupra({ address: "0xABC", body: "Привет" });

    const [, init] = fetchMock.mock.calls.at(-1) ?? [];
    expect(fetchMock).toHaveBeenLastCalledWith(
      "http://localhost:8000/chat/messages",
      expect.objectContaining({ method: "POST" }),
    );
    expect(JSON.parse((init as RequestInit).body as string)).toEqual({
      address: "0xABC",
      body: "Привет",
      room: "global",
      metadata: null,
    });
    expect(result.metadata).toEqual({ locale: "ru" });
  });

  it("получает объявления с фильтром по лотерее", async () => {
    queueResponse([
      {
        id: 7,
        title: "Анонс",
        body: "Описание",
        lottery_id: "speed",
        metadata: { priority: "high" },
        created_at: "2024-04-12T09:00:00Z",
      },
    ]);

    const announcements = await fetchAnnouncementsSupra(10, " speed ");
    expect(fetchMock).toHaveBeenLastCalledWith(
      "http://localhost:8000/chat/announcements?limit=10&lottery_id=speed",
      expect.objectContaining({ headers: expect.objectContaining({ Accept: "application/json" }) }),
    );
    expect(announcements[0]).toMatchObject({ id: 7, lotteryId: "speed" });
  });

  it("создаёт объявление и возвращает результат", async () => {
    queueResponse({
      id: 8,
      title: "Старт недели",
      body: "Не пропустите",
      lottery_id: null,
      metadata: { category: "info" },
      created_at: "2024-04-12T08:00:00Z",
    });

    const announcement = await postAnnouncementSupra({ title: "Старт недели", body: "Не пропустите" });
    const [, init] = fetchMock.mock.calls.at(-1) ?? [];
    expect(fetchMock).toHaveBeenLastCalledWith(
      "http://localhost:8000/chat/announcements",
      expect.objectContaining({ method: "POST" }),
    );
    expect(JSON.parse((init as RequestInit).body as string)).toEqual({
      title: "Старт недели",
      body: "Не пропустите",
    });
    expect(announcement.metadata).toEqual({ category: "info" });
  });
});

describe("supraClient progress API", () => {
  let fetchMock: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    fetchMock = vi.spyOn(globalThis, "fetch");
  });

  afterEach(() => {
    fetchMock.mockRestore();
  });

  it("maps checklist responses", async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          address: "0xabc",
          tasks: [
            {
              task: {
                code: "day1",
                title: "День 1",
                description: "Привет",
                day_index: 0,
                reward_kind: "ticket",
                reward_value: { amount: 1 },
                metadata: { group: "daily" },
                is_active: true,
                created_at: "2024-05-24T00:00:00Z",
                updated_at: "2024-05-24T01:00:00Z",
              },
              completed: true,
              completed_at: "2024-05-24T02:00:00Z",
              reward_claimed: false,
              metadata: { source: "test" },
            },
          ],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );

    const result = await fetchChecklistSupra(" 0xABC ");

    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining("/progress/0xABC/checklist"),
      expect.objectContaining({ headers: expect.objectContaining({ Accept: "application/json" }) }),
    );
    expect(result.address).toBe("0xabc");
    expect(result.tasks).toHaveLength(1);
    expect(result.tasks[0]?.task.rewardValue).toEqual({ amount: 1 });
    expect(result.tasks[0]?.metadata).toEqual({ source: "test" });
  });

  it("posts completion payload", async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          task: {
            code: "day1",
            title: "День 1",
            description: "Привет",
            day_index: 0,
            reward_kind: "ticket",
            reward_value: { amount: 1 },
            metadata: null,
            is_active: true,
            created_at: "2024-05-24T00:00:00Z",
            updated_at: "2024-05-24T01:00:00Z",
          },
          completed: true,
          completed_at: "2024-05-24T02:00:00Z",
          reward_claimed: true,
          metadata: { source: "ui" },
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );

    const entry = await completeChecklistTaskSupra("0xABC", "day1", {
      rewardClaimed: true,
      metadata: { source: "ui" },
    });

    const request = fetchMock.mock.calls[0];
    expect(request?.[0]).toBe("http://localhost:8000/progress/0xABC/checklist/day1/complete");
    expect(request?.[1]).toMatchObject({ method: "POST" });
    expect(JSON.parse((request?.[1]?.body ?? "{}") as string)).toEqual({
      reward_claimed: true,
      metadata: { source: "ui" },
    });
    expect(entry.rewardClaimed).toBe(true);
    expect(entry.completedAt).toBe("2024-05-24T02:00:00.000Z");
  });

  it("maps achievements and unlocks progress", async () => {
    fetchMock
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            address: "0xabc",
            achievements: [
              {
                achievement: {
                  code: "early",
                  title: "Ранний",
                  description: "Описание",
                  points: 25,
                  metadata: { category: "daily" },
                  is_active: true,
                  created_at: "2024-05-24T00:00:00Z",
                  updated_at: "2024-05-24T01:00:00Z",
                },
                unlocked: false,
                unlocked_at: null,
                progress_value: 0,
                metadata: null,
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            achievement: {
              code: "early",
              title: "Ранний",
              description: "Описание",
              points: 25,
              metadata: { category: "daily" },
              is_active: true,
              created_at: "2024-05-24T00:00:00Z",
              updated_at: "2024-05-24T01:00:00Z",
            },
            unlocked: true,
            unlocked_at: "2024-05-24T03:00:00Z",
            progress_value: 10,
            metadata: { source: "ui" },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );

    const status = await fetchAchievementsSupra("0xABC");
    expect(status.achievements).toHaveLength(1);
    expect(status.achievements[0]?.achievement.points).toBe(25);

    const progress = await unlockAchievementSupra("0xABC", "early", {
      progressValue: 10,
      metadata: { source: "ui" },
    });

    expect(fetchMock).toHaveBeenLastCalledWith(
      "http://localhost:8000/progress/0xABC/achievements/early/unlock",
      expect.objectContaining({ method: "POST" }),
    );
    expect(progress.unlocked).toBe(true);
    expect(progress.metadata).toEqual({ source: "ui" });
    expect(progress.unlockedAt).toBe("2024-05-24T03:00:00.000Z");
  });
});

describe("supraClient admin config", () => {
  const fallbackConfig: AdminConfig = {
    gas: { maxGasFee: 10, minBalance: 20, updatedAt: "2024-01-01T00:00:00.000Z" },
    vrf: {
      maxGasPrice: "1",
      maxGasLimit: "2",
      callbackGasPrice: "3",
      callbackGasLimit: "4",
      requestedRngCount: 1,
      clientSeed: 2,
      lastConfiguredAt: "2024-01-01T00:00:00.000Z",
    },
    whitelist: {
      clientConfigured: false,
      consumerConfigured: false,
      client: null,
      consumer: null,
    },
    treasury: {
      config: {
        ticketPriceSupra: "5",
        salesEnabled: false,
        treasuryAddress: "0xabc",
        distributionBp: { jackpot: 6000, prize: 2500, treasury: 1000, marketing: 500 },
        updatedAt: "2024-01-01T00:00:00.000Z",
      },
      balances: {
        jackpotSupra: "0",
        prizeSupra: "0",
        treasurySupra: "0",
        marketingSupra: "0",
        updatedAt: "2024-01-01T00:00:00.000Z",
      },
    },
  };

  let fetchMock: ReturnType<typeof vi.spyOn>;
  let fallbackSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    invalidateSupraStatusCache();
    fetchMock = vi.spyOn(globalThis, "fetch");
    fallbackSpy = vi.spyOn(mockClient, "fetchAdminConfigMock").mockResolvedValue(fallbackConfig);
  });

  afterEach(() => {
    fetchMock.mockRestore();
    fallbackSpy.mockRestore();
    invalidateSupraStatusCache();
  });

  function queueResponse(payload: object) {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(payload), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );
  }

  it("derives admin config from Supra status response", async () => {
    queueResponse({
      timestamp: "2024-04-12T12:00:00Z",
      calculation: {
        per_request_fee: "999",
        min_balance: "888",
        max_gas_price: "150",
        max_gas_limit: "600000",
      },
      lotteries: [
        {
          lottery_id: 0,
          factory: {
            owner: "0xowner",
            lottery: "0xlottery",
            blueprint: { ticket_price: "77", jackpot_share_bps: 2500 },
          },
          instance: {
            owner: "0xowner",
            lottery: "0xlottery",
            blueprint: { ticket_price: "77", jackpot_share_bps: 2500 },
          },
          treasury: {
            config: { jackpot_bps: 4000, prize_bps: 2500, operations_bps: 3500 },
            pool: { prize_balance: "12345", operations_balance: "987654321" },
          },
        },
      ],
      deposit: {
        max_gas_price: "150",
        max_gas_limit: "600000",
        min_balance: "12000000000",
        contract_details: {
          callback_gas_price: "55",
          callback_gas_limit: "250000",
        },
      },
      treasury: {
        jackpot_balance: "444444",
      },
    });

    const result = await fetchAdminConfigSupra();

    expect(result.gas.maxGasFee).toBe(999);
    expect(result.gas.minBalance).toBe(12_000_000_000);
    expect(result.gas.updatedAt).toBe("2024-04-12T12:00:00.000Z");

    expect(result.vrf.maxGasPrice).toBe("150");
    expect(result.vrf.maxGasLimit).toBe("600000");
    expect(result.vrf.callbackGasPrice).toBe("55");
    expect(result.vrf.callbackGasLimit).toBe("250000");
    expect(result.vrf.requestedRngCount).toBe(0);
    expect(result.vrf.clientSeed).toBe(0);
    expect(result.vrf.lastConfiguredAt).toBe("2024-04-12T12:00:00.000Z");

    expect(result.whitelist).toEqual(fallbackConfig.whitelist);

    expect(result.treasury.config.ticketPriceSupra).toBe("77");
    expect(result.treasury.config.treasuryAddress).toBe(fallbackConfig.treasury.config.treasuryAddress);
    expect(result.treasury.config.salesEnabled).toBe(fallbackConfig.treasury.config.salesEnabled);
    expect(result.treasury.config.distributionBp).toEqual({
      jackpot: 4000,
      prize: 2500,
      treasury: 3500,
      marketing: 0,
    });
    expect(result.treasury.config.updatedAt).toBe("2024-04-12T12:00:00.000Z");

    expect(result.treasury.balances.jackpotSupra).toBe("444444");
    expect(result.treasury.balances.treasurySupra).toBe("987654321");
    expect(result.treasury.balances.prizeSupra).toBe("12345");
    expect(result.treasury.balances.marketingSupra).toBe(
      fallbackConfig.treasury.balances.marketingSupra,
    );
    expect(result.treasury.balances.updatedAt).toBe("2024-04-12T12:00:00.000Z");

    expect(fallbackSpy).toHaveBeenCalled();
  });

  it("falls back to mock admin config when Supra payload lacks data", async () => {
    queueResponse({ timestamp: "2024-04-12T12:00:00Z" });

    const result = await fetchAdminConfigSupra();

    expect(result.gas).toEqual(fallbackConfig.gas);
    expect(result.vrf).toEqual(fallbackConfig.vrf);
    expect(result.whitelist).toEqual(fallbackConfig.whitelist);
    expect(result.treasury.config.ticketPriceSupra).toBe(
      fallbackConfig.treasury.config.ticketPriceSupra,
    );
    expect(result.treasury.config.distributionBp).toEqual(
      fallbackConfig.treasury.config.distributionBp,
    );
    expect(result.treasury.config.updatedAt).toBe(fallbackConfig.treasury.config.updatedAt);
    expect(result.treasury.config.treasuryAddress).toBe(
      fallbackConfig.treasury.config.treasuryAddress,
    );
    expect(result.treasury.balances).toEqual(fallbackConfig.treasury.balances);
    expect(fallbackSpy).toHaveBeenCalled();
  });
});

describe("supraClient accounts", () => {
  let fetchMock: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    fetchMock = vi.spyOn(globalThis, "fetch");
  });

  afterEach(() => {
    fetchMock.mockRestore();
  });

  it("возвращает null при пустом адресе", async () => {
    expect(await fetchAccountProfileSupra("   ")).toBeNull();
  });

  it("возвращает null при 404", async () => {
    fetchMock.mockResolvedValueOnce(new Response("", { status: 404 }));

    const profile = await fetchAccountProfileSupra("0xabc");
    expect(profile).toBeNull();
    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining("/accounts/0xabc"),
      expect.any(Object),
    );
  });

  it("нормализует профиль из API", async () => {
    const payload = {
      address: "0xAbC",
      nickname: "Player",
      avatar_kind: "external",
      avatar_value: "ipfs://hash",
      telegram: "user",
      twitter: null,
      settings: { theme: "dark" },
      created_at: "2024-02-01T00:00:00Z",
      updated_at: "2024-02-02T00:00:00Z",
    };

    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(payload), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );

    const profile = await fetchAccountProfileSupra("0xAbC");

    expect(profile).not.toBeNull();
    expect(profile?.address).toBe("0xAbC");
    expect(profile?.avatar.kind).toBe("external");
    expect(profile?.settings.theme).toBe("dark");
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("отправляет корректный payload при upsert", async () => {
    const responsePayload = {
      address: "0xabc",
      nickname: "Updated",
      avatar_kind: "crystara",
      avatar_value: "nft-123",
      telegram: "new_user",
      twitter: null,
      settings: { autoBuy: true },
      created_at: "2024-02-01T00:00:00Z",
      updated_at: "2024-02-03T00:00:00Z",
    };

    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(responsePayload), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );

    const profile = await upsertAccountProfileSupra("0xabc", {
      nickname: "Updated",
      avatar: { kind: "crystara", value: "nft-123" },
      telegram: "new_user",
      settings: { autoBuy: true },
    });

    expect(profile.nickname).toBe("Updated");
    expect(profile.avatar.value).toBe("nft-123");

    const call = fetchMock.mock.calls[0];
    expect(call?.[0]).toContain("/accounts/0xabc");
    const init = call?.[1] as RequestInit;
    expect(init?.method).toBe("PUT");
    const body = init?.body ? JSON.parse(init.body as string) : {};
    expect(body).toMatchObject({
      nickname: "Updated",
      avatar: { kind: "crystara", value: "nft-123" },
      telegram: "new_user",
      settings: { autoBuy: true },
    });
  });
});

describe("supraClient treasury helpers", () => {
  const fallbackConfig = {
    ticketPriceSupra: "5",
    salesEnabled: false,
    treasuryAddress: "0xabc",
    distributionBp: { jackpot: 6000, prize: 2000, treasury: 1500, marketing: 500 },
    updatedAt: "2024-01-01T00:00:00.000Z",
  };
  const fallbackBalances = {
    jackpotSupra: "100",
    prizeSupra: "200",
    treasurySupra: "300",
    marketingSupra: "400",
    updatedAt: "2024-01-01T00:00:00.000Z",
  };

  let fetchMock: ReturnType<typeof vi.spyOn>;
  let configSpy: ReturnType<typeof vi.spyOn>;
  let balancesSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    invalidateSupraStatusCache();
    fetchMock = vi.spyOn(globalThis, "fetch");
    configSpy = vi
      .spyOn(mockClient, "fetchTreasuryConfigMock")
      .mockResolvedValue(fallbackConfig);
    balancesSpy = vi
      .spyOn(mockClient, "fetchTreasuryBalancesMock")
      .mockResolvedValue(fallbackBalances);
  });

  afterEach(() => {
    fetchMock.mockRestore();
    configSpy.mockRestore();
    balancesSpy.mockRestore();
    invalidateSupraStatusCache();
  });

  function queueResponse(payload: object) {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(payload), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );
  }

  it("parses treasury config from status", async () => {
    queueResponse({
      timestamp: "2024-05-01T00:00:00Z",
      lotteries: [
        {
          lottery_id: 0,
          factory: {
            owner: "0xowner",
            lottery: "0xlottery",
            blueprint: { ticket_price: "42", jackpot_share_bps: 2000 },
          },
          treasury: {
            config: { jackpot_bps: 3000, prize_bps: 2500, operations_bps: 2500 },
          },
        },
      ],
    });

    const result = await fetchTreasuryConfigSupra();

    expect(result.ticketPriceSupra).toBe("42");
    expect(result.treasuryAddress).toBe(fallbackConfig.treasuryAddress);
    expect(result.salesEnabled).toBe(false);
    expect(result.distributionBp).toEqual({
      jackpot: 3000,
      prize: 2500,
      treasury: 2500,
      marketing: 0,
    });
    expect(result.updatedAt).toBe("2024-05-01T00:00:00.000Z");

    expect(configSpy).toHaveBeenCalled();
  });

  it("parses treasury balances from status", async () => {
    queueResponse({
      timestamp: "2024-05-02T00:00:00Z",
      lotteries: [
        {
          lottery_id: 0,
          treasury: {
            pool: { prize_balance: "54321", operations_balance: "111222333" },
          },
        },
      ],
      treasury: {
        jackpot_balance: "999888777",
      },
    });

    const result = await fetchTreasuryBalancesSupra();

    expect(result.jackpotSupra).toBe("999888777");
    expect(result.treasurySupra).toBe("111222333");
    expect(result.prizeSupra).toBe("54321");
    expect(result.marketingSupra).toBe("400");
    expect(result.updatedAt).toBe("2024-05-02T00:00:00.000Z");

    expect(balancesSpy).toHaveBeenCalled();
  });
});

describe("supraClient command mutations", () => {
  let fetchMock: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    invalidateSupraStatusCache();
    fetchMock = vi.spyOn(globalThis, "fetch");
  });

  afterEach(() => {
    fetchMock.mockRestore();
    invalidateSupraStatusCache();
  });

  function queueCommandResponse(overrides: Partial<Record<string, unknown>> = {}) {
    const responseBody = {
      command: "record-client-whitelist",
      args: [],
      returncode: 0,
      stdout: JSON.stringify({
        tx_hash: "0x".padEnd(66, "a"),
        submitted_at: "2024-05-01T00:00:00.000Z",
        stdout: "Transaction executed",
      }),
      stderr: "",
      ...overrides,
    } satisfies Record<string, unknown>;

    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(responseBody), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );

    return responseBody;
  }

  it("returns mutation result for client whitelist snapshot", async () => {
    queueCommandResponse();

    const result = await recordClientWhitelistSnapshotSupra({
      maxGasPrice: "1",
      maxGasLimit: "2",
      minBalanceLimit: "3",
    });

    expect(result.txHash).toMatch(/^0x/);
    expect(result.submittedAt).toBe("2024-05-01T00:00:00.000Z");

    const [, init] = fetchMock.mock.calls[0];
    expect(init?.method).toBe("POST");
    expect(JSON.parse(String(init?.body))).toEqual({
      args: [
        "--max-gas-price",
        "1",
        "--max-gas-limit",
        "2",
        "--min-balance-limit",
        "3",
        "--assume-yes",
      ],
    });
  });

  it("parses tx hash from stdout fallback", async () => {
    queueCommandResponse({
      stdout: "Transaction hash: 0x" + "b".repeat(64),
    });

    const result = await recordConsumerWhitelistSnapshotSupra({
      callbackGasPrice: "5",
      callbackGasLimit: "6",
    });

    expect(result.txHash).toMatch(/^0x/);
    const [, init] = fetchMock.mock.calls[0];
    expect(JSON.parse(String(init?.body)).args).toEqual([
      "--callback-gas-price",
      "5",
      "--callback-gas-limit",
      "6",
      "--assume-yes",
    ]);
  });

  it("throws on non-zero return code", async () => {
    queueCommandResponse({ returncode: 1, stderr: "failure" });

    await recordClientWhitelistSnapshotSupra({
      maxGasPrice: "1",
      maxGasLimit: "2",
      minBalanceLimit: "3",
    }).then(
      () => {
        throw new Error("ожидали ошибку Supra CLI");
      },
      (error) => {
        expect(error).toBeInstanceOf(Error);
        expect(String(error)).toMatch(/кодом 1/);
      },
    );
  });

  it("настраивает VRF через configure-vrf-gas и configure-vrf-request", async () => {
    const verificationGasResponse = {
      calculation: { verification_gas_value: "7000" },
      deposit: {},
      lottery: {},
    };

    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(verificationGasResponse), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );

    const gasHash = `0x${"1".repeat(64)}`;
    const requestHash = `0x${"2".repeat(64)}`;

    queueCommandResponse({
      command: "configure-vrf-gas",
      stdout: JSON.stringify({
        tx_hash: gasHash,
        submitted_at: "2024-06-01T00:00:00.000Z",
      }),
    });

    queueCommandResponse({
      command: "configure-vrf-request",
      stdout: JSON.stringify({
        tx_hash: requestHash,
        submitted_at: "2024-06-01T01:00:00.000Z",
      }),
    });

    const result = await updateVrfConfigSupra({
      maxGasPrice: "11",
      maxGasLimit: "22",
      callbackGasPrice: "33",
      callbackGasLimit: "44",
      requestedRngCount: 2,
      clientSeed: 777,
    });

    expect(result.txHash).toBe(requestHash);
    expect(result.submittedAt).toBe("2024-06-01T01:00:00.000Z");
    expect(fetchMock).toHaveBeenCalledTimes(3);

    const gasPayload = JSON.parse(String(fetchMock.mock.calls[1]?.[1]?.body));
    expect(gasPayload.args).toEqual([
      "--max-gas-price",
      "11",
      "--max-gas-limit",
      "22",
      "--callback-gas-price",
      "33",
      "--callback-gas-limit",
      "44",
      "--verification-gas",
      "7000",
      "--assume-yes",
    ]);

    const requestPayload = JSON.parse(String(fetchMock.mock.calls[2]?.[1]?.body));
    expect(requestPayload.args).toEqual([
      "--rng-count",
      "2",
      "--client-seed",
      "777",
      "--assume-yes",
    ]);
  });

  it("прерывает выполнение, если configure-vrf-gas вернул ошибку", async () => {
    const statusPayload = { calculation: {}, deposit: {}, lottery: {} };

    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(statusPayload), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );

    queueCommandResponse({
      command: "configure-vrf-gas",
      returncode: 1,
      stderr: "gas failed",
    });

    await expect(
      updateVrfConfigSupra({
        maxGasPrice: "10",
        maxGasLimit: "20",
        callbackGasPrice: "30",
        callbackGasLimit: "40",
        requestedRngCount: 1,
        clientSeed: 5,
      }),
    ).rejects.toThrow(/configure-vrf-gas завершилась с кодом 1: gas failed/);

    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it("добавляет подсказку о выполненном configure-vrf-gas, если вторая команда упала", async () => {
    const statusPayload = { calculation: {}, deposit: {}, lottery: {} };

    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(statusPayload), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );

    const gasHash = `0x${"c".repeat(64)}`;

    queueCommandResponse({
      command: "configure-vrf-gas",
      stdout: JSON.stringify({
        tx_hash: gasHash,
        submitted_at: "2024-06-02T00:00:00.000Z",
      }),
    });

    queueCommandResponse({
      command: "configure-vrf-request",
      returncode: 1,
      stderr: "request failed",
    });

    await expect(
      updateVrfConfigSupra({
        maxGasPrice: "12",
        maxGasLimit: "24",
        callbackGasPrice: "36",
        callbackGasLimit: "48",
        requestedRngCount: 3,
        clientSeed: 9,
      }),
    ).rejects.toThrow(/газ обновлён, tx/);

    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it("выполняет set-minimum-balance после проверки расчётов", async () => {
    const statusPayload = {
      calculation: { per_request_fee: "1500", min_balance: "9000" },
      deposit: { min_balance: "9000" },
      lottery: {},
    };

    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(statusPayload), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );

    const txHash = `0x${"d".repeat(64)}`;
    queueCommandResponse({
      command: "set-minimum-balance",
      stdout: JSON.stringify({ tx_hash: txHash, submitted_at: "2024-06-03T00:00:00.000Z" }),
    });

    const result = await updateGasConfigSupra({ maxGasFee: 1500, minBalance: 9000 });
    expect(result.txHash).toBe(txHash);

    expect(fetchMock).toHaveBeenCalledTimes(2);
    const [, init] = fetchMock.mock.calls[1];
    expect(JSON.parse(String(init?.body))).toEqual({
      args: [
        "--expected-min-balance",
        "9000",
        "--expected-max-gas-fee",
        "1500",
        "--assume-yes",
      ],
    });
  });

  it("отклоняет ручной ввод, если значения не совпадают с расчётом", async () => {
    const statusPayload = {
      calculation: { per_request_fee: "2000", min_balance: "12000" },
      deposit: { min_balance: "12000" },
      lottery: {},
    };

    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(statusPayload), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );

    await expect(updateGasConfigSupra({ maxGasFee: 1999, minBalance: 12000 })).rejects.toThrow(/maxGasFee/);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("выполняет configure-treasury-distribution и сбрасывает кэш", async () => {
    queueCommandResponse({
      command: "configure-treasury-distribution",
      stdout: JSON.stringify({
        tx_hash: `0x${"f".repeat(64)}`,
        submitted_at: "2024-06-05T00:00:00.000Z",
      }),
    });

    const result = await updateTreasuryDistributionSupra({
      jackpotBp: 4000,
      prizeBp: 2500,
      treasuryBp: 2500,
      marketingBp: 1000,
    });

    expect(result.txHash).toMatch(/^0x/);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [, init] = fetchMock.mock.calls[0];
    expect(JSON.parse(String(init?.body))).toEqual({
      args: [
        "--bp-jackpot",
        "4000",
        "--bp-prize",
        "2500",
        "--bp-treasury",
        "2500",
        "--bp-marketing",
        "1000",
        "--bp-community",
        "0",
        "--bp-team",
        "0",
        "--bp-partners",
        "0",
        "--assume-yes",
      ],
    });
  });

  it("валидирует сумму распределения перед вызовом команды", async () => {
    await expect(
      updateTreasuryDistributionSupra({
        jackpotBp: 4000,
        prizeBp: 2500,
        treasuryBp: 2500,
        marketingBp: 999,
      }),
    ).rejects.toThrow(/10000 bps/);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

describe("listSupraCommandsSupra", () => {
  let fetchMock: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    fetchMock = vi.spyOn(globalThis, "fetch");
  });

  afterEach(() => {
    fetchMock.mockRestore();
  });

  it("возвращает отсортированный и нормализованный список команд", async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify([
          { name: "beta", module: "supra.beta", description: "Beta command" },
          { name: "alpha", module: "supra.alpha", description: "Alpha command" },
          { name: "skip", module: null, description: "missing module" },
        ]),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
      ),
    );

    const result = await listSupraCommandsSupra();

    expect(result).toEqual([
      { name: "alpha", module: "supra.alpha", description: "Alpha command" },
      { name: "beta", module: "supra.beta", description: "Beta command" },
    ]);

    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:8000/commands",
      expect.objectContaining({ headers: { Accept: "application/json" } }),
    );
  });

  it("прокидывает ошибки HTTP", async () => {
    fetchMock.mockResolvedValueOnce(new Response("failure", { status: 502 }));

    await expect(listSupraCommandsSupra()).rejects.toThrow(/Supra API 502/);
  });
});
