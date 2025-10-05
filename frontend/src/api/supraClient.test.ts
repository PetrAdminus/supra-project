import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  STATUS_CACHE_TTL_MS,
  fetchAdminConfigSupra,
  fetchLotteryStatusSupra,
  fetchWhitelistStatusSupra,
  fetchTreasuryBalancesSupra,
  fetchTreasuryConfigSupra,
  invalidateSupraStatusCache,
  listSupraCommandsSupra,
  recordClientWhitelistSnapshotSupra,
  recordConsumerWhitelistSnapshotSupra,
  refreshSupraStatus,
  updateGasConfigSupra,
  updateTreasuryDistributionSupra,
  updateVrfConfigSupra,
} from "./supraClient";
import type { AdminConfig } from "./types";
import * as mockClient from "./mockClient";

declare global {
  // eslint-disable-next-line no-var
  var fetch: typeof fetch;
}

describe("supraClient caching", () => {
  const baseResponse = {
    timestamp: "2024-04-12T12:00:00Z",
    profile: "default",
    lottery: {
      status: [
        {
          round: 7,
          jackpot_amount: "42",
          ticket_count: 3,
        },
      ],
      ticket_price: "10",
      registered_tickets: ["A-1", "A-2", "A-3"],
      whitelist_status: [
        {
          aggregator: "0x001",
        },
      ],
    },
    deposit: {
      subscription_info: {
        subscription_id: "123",
      },
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
    expect(status.ticketPriceSupra).toBe("10");

    const whitelist = await fetchWhitelistStatusSupra();
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
      lottery: {
        ...baseResponse.lottery,
        status: [
          {
            round: 8,
            ticket_count: 1,
            jackpot_amount: "50",
          },
        ],
        whitelist_status: [
          {
            aggregator: "0x002",
          },
        ],
      },
    };

    queueResponse(nextResponse);

    const status = await fetchLotteryStatusSupra();
    expect(status.round).toBe(8);
    expect(globalThis.fetch).toHaveBeenCalledTimes(2);
  });

  it("forces refresh via helper", async () => {
    queueResponse(baseResponse);
    await fetchLotteryStatusSupra();
    expect(fetchMock).toHaveBeenCalledTimes(1);

    const refreshed = {
      ...baseResponse,
      lottery: {
        ...baseResponse.lottery,
        status: [
          {
            round: 9,
            ticket_count: 5,
            jackpot_amount: "99",
          },
        ],
      },
    };

    queueResponse(refreshed);

    const result = await refreshSupraStatus();
    expect(result.lottery?.status).not.toBeUndefined();
    expect(globalThis.fetch).toHaveBeenCalledTimes(2);
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
      },
      lottery: {
        vrf_request_config: [
          {
            rng_count: "3",
            client_seed: "7",
          },
        ],
        client_whitelist_snapshot: [
          {
            max_gas_price: "1000",
            max_gas_limit: "500000",
            min_balance_limit: "9000000000",
          },
        ],
        consumer_whitelist_snapshot: [
          {
            callback_gas_price: "42",
            callback_gas_limit: "210000",
          },
        ],
        status: [
          {
            jackpot_amount: "12345",
          },
        ],
        ticket_price: "77",
      },
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
        config: [4000, 2500, 2500, 1000, 0, 0, 0],
        recipients: ["0xdead", "0xmarketing"],
        balance: "987654321",
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
    expect(result.vrf.requestedRngCount).toBe(3);
    expect(result.vrf.clientSeed).toBe(7);
    expect(result.vrf.lastConfiguredAt).toBe("2024-04-12T12:00:00.000Z");

    expect(result.whitelist.clientConfigured).toBe(true);
    expect(result.whitelist.client).not.toBeNull();
    expect(result.whitelist?.client?.maxGasPrice).toBe("1000");
    expect(result.whitelist.consumerConfigured).toBe(true);
    expect(result.whitelist.consumer?.callbackGasPrice).toBe("42");

    expect(result.treasury.config.ticketPriceSupra).toBe("77");
    expect(result.treasury.config.treasuryAddress).toBe("0xdead");
    expect(result.treasury.config.salesEnabled).toBe(fallbackConfig.treasury.config.salesEnabled);
    expect(result.treasury.config.distributionBp).toEqual({
      jackpot: 4000,
      prize: 2500,
      treasury: 2500,
      marketing: 1000,
    });
    expect(result.treasury.config.updatedAt).toBe("2024-04-12T12:00:00.000Z");

    expect(result.treasury.balances.jackpotSupra).toBe("12345");
    expect(result.treasury.balances.treasurySupra).toBe("987654321");
    expect(result.treasury.balances.prizeSupra).toBe(fallbackConfig.treasury.balances.prizeSupra);
    expect(result.treasury.balances.marketingSupra).toBe(
      fallbackConfig.treasury.balances.marketingSupra,
    );
    expect(result.treasury.balances.updatedAt).toBe("2024-04-12T12:00:00.000Z");

    expect(fallbackSpy).toHaveBeenCalled();
  });

  it("falls back to mock admin config when Supra payload lacks data", async () => {
    queueResponse({ timestamp: "2024-04-12T12:00:00Z" });

    const result = await fetchAdminConfigSupra();

    expect(result).toEqual({
      gas: fallbackConfig.gas,
      vrf: fallbackConfig.vrf,
      whitelist: fallbackConfig.whitelist,
      treasury: {
        config: {
          ...fallbackConfig.treasury.config,
          distributionBp: { ...fallbackConfig.treasury.config.distributionBp },
        },
        balances: { ...fallbackConfig.treasury.balances },
      },
    });
    expect(fallbackSpy).toHaveBeenCalled();
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
      lottery: {
        ticket_price: "42",
      },
      treasury: {
        config: [3000, 2500, 2500, 1000, 0, 0, 0],
        recipients: ["0xdeadbeef"],
      },
    });

    const result = await fetchTreasuryConfigSupra();

    expect(result.ticketPriceSupra).toBe("42");
    expect(result.treasuryAddress).toBe("0xdeadbeef");
    expect(result.salesEnabled).toBe(false);
    expect(result.distributionBp).toEqual({
      jackpot: 3000,
      prize: 2500,
      treasury: 2500,
      marketing: 1000,
    });
    expect(result.updatedAt).toBe("2024-05-01T00:00:00.000Z");

    expect(configSpy).toHaveBeenCalled();
  });

  it("parses treasury balances from status", async () => {
    queueResponse({
      timestamp: "2024-05-02T00:00:00Z",
      lottery: {
        status: [
          {
            jackpot_amount: "54321",
          },
        ],
      },
      treasury: {
        balance: "111222333",
      },
    });

    const result = await fetchTreasuryBalancesSupra();

    expect(result.jackpotSupra).toBe("54321");
    expect(result.treasurySupra).toBe("111222333");
    expect(result.prizeSupra).toBe("200");
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
