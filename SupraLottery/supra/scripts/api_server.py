"""FastAPI service exposing Supra lottery monitoring data."""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from typing import Any, Dict, List, Mapping, MutableMapping, Optional

from fastapi import Depends, FastAPI, HTTPException, Query, Request, status
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware import Middleware
from pydantic import BaseModel, Field
import uvicorn

from . import cli
from .accounts import get_config_from_env as get_accounts_config
from .accounts import init_engine as init_accounts_engine
from .accounts import router as accounts_router
from .progress import router as progress_router
from .realtime import router as realtime_router
from .support import router as support_router
from .lib.monitoring import (
    CliError,
    ConfigError,
    MonitorConfig,
    gather_data,
    monitor_config_from_env,
)
from .lib.vrf_audit import gather_vrf_log

app = FastAPI(title="Supra Lottery API", version="0.1.0")
app.include_router(accounts_router)
app.include_router(realtime_router)
app.include_router(support_router)
app.include_router(progress_router)


def _parse_cors_origins(raw: Optional[str]) -> List[str]:
    if not raw:
        return []
    origins = [item.strip() for item in raw.split(",") if item.strip()]
    if "*" in origins:
        return ["*"]
    return origins


def _configure_cors() -> None:
    origins = _parse_cors_origins(os.environ.get("SUPRA_API_CORS_ORIGINS"))

    app.user_middleware = [
        middleware for middleware in app.user_middleware if middleware.cls is not CORSMiddleware
    ]

    if origins:
        app.user_middleware.append(
            Middleware(
                CORSMiddleware,
                allow_origins=origins,
                allow_credentials=True,
                allow_methods=["*"],
                allow_headers=["*"],
                max_age=60,
            )
        )

    app.middleware_stack = app.build_middleware_stack()


_configure_cors()

# Mapping between HTTP query parameters and environment variable names.
_QUERY_TO_ENV: Dict[str, str] = {
    "profile": "PROFILE",
    "lottery_addr": "LOTTERY_ADDR",
    "hub_addr": "HUB_ADDR",
    "factory_addr": "FACTORY_ADDR",
    "deposit_addr": "DEPOSIT_ADDR",
    "client_addr": "CLIENT_ADDR",
    "supra_cli_bin": "SUPRA_CLI_BIN",
    "supra_config": "SUPRA_CONFIG",
    "max_gas_price": "MAX_GAS_PRICE",
    "max_gas_limit": "MAX_GAS_LIMIT",
    "verification_gas": "VERIFICATION_GAS_VALUE",
    "margin": "MIN_BALANCE_MARGIN",
    "window": "MIN_BALANCE_WINDOW",
    "lottery_ids": "LOTTERY_IDS",
}


def _collect_overrides(params: Mapping[str, str]) -> Dict[str, str]:
    overrides: Dict[str, str] = {}
    for key, value in params.items():
        env_key = _QUERY_TO_ENV.get(key)
        if env_key and value:
            overrides[env_key] = value
    return overrides


@app.on_event("startup")
def _load_base_config() -> None:
    try:
        app.state.monitor_config = monitor_config_from_env()
        app.state.config_error = None
    except ConfigError as exc:  # pragma: no cover - configuration provided at runtime
        app.state.monitor_config = None
        app.state.config_error = exc

    cache_ttl_raw = os.environ.get("SUPRA_API_CACHE_TTL")
    try:
        cache_ttl = float(cache_ttl_raw) if cache_ttl_raw is not None else 0.0
    except ValueError:  # pragma: no cover - configuration error reported via health
        cache_ttl = 0.0
        app.state.config_error = ConfigError("SUPRA_API_CACHE_TTL must be a number")

    app.state.cache_ttl_seconds = max(0.0, cache_ttl)
    app.state.status_cache = None


@app.on_event("startup")
def _init_accounts() -> None:
    config = get_accounts_config()
    init_accounts_engine(config)


def _resolve_config(overrides: Mapping[str, str] | None = None) -> MonitorConfig:
    overrides = overrides or {}
    if overrides:
        return monitor_config_from_env(overrides=overrides)

    config = getattr(app.state, "monitor_config", None)
    if config is None:
        error = getattr(app.state, "config_error", None)
        if error is not None:
            raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(error))
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, detail="Configuration not loaded")
    return config


async def get_monitor_config(request: Request) -> MonitorConfig:
    overrides = _collect_overrides(request.query_params)
    request.state.monitor_overrides = overrides
    try:
        return _resolve_config(overrides)
    except ConfigError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


class CommandInfo(BaseModel):
    """Metadata describing an available CLI helper command."""

    name: str = Field(description="Command identifier passed to the CLI entrypoint")
    module: str = Field(description="Fully-qualified Python module executed for the command")
    description: str = Field(description="Human readable description of the command")


class CommandRequest(BaseModel):
    """Payload for executing CLI commands via the API."""

    args: List[str] = Field(default_factory=list, description="Arguments passed to the CLI command")
    supra_config: Optional[str] = Field(
        default=None,
        description="Override SUPRA_CONFIG for the executed command",
    )


class CommandResponse(BaseModel):
    command: str
    args: List[str]
    returncode: int
    stdout: str
    stderr: str


def _command_environment(supra_config: Optional[str]) -> MutableMapping[str, str]:
    env = os.environ.copy()
    if supra_config:
        env["SUPRA_CONFIG"] = supra_config
    return env


@app.get("/healthz", tags=["health"])
async def health() -> Dict[str, str]:
    """Lightweight health check endpoint."""

    config_error = getattr(app.state, "config_error", None)
    status_value = "ok" if config_error is None else "degraded"
    payload = {"status": status_value}
    if config_error is not None:
        payload["detail"] = str(config_error)
    return payload


def _should_refresh(query: Mapping[str, str]) -> bool:
    raw = query.get("refresh")
    if raw is None:
        return False
    normalized = raw.strip().lower()
    return normalized in {"1", "true", "yes", "on"}


def _cache_available(request: Request) -> bool:
    overrides = getattr(request.state, "monitor_overrides", {}) or {}
    if overrides:
        return False
    ttl = getattr(app.state, "cache_ttl_seconds", 0.0)
    return ttl > 0


def _get_cached_status(config: MonitorConfig) -> Dict[str, object] | None:
    cache = getattr(app.state, "status_cache", None)
    if not cache:
        return None
    if cache.get("config") != config:
        return None
    expires_at = cache.get("expires_at", 0.0)
    if expires_at <= time.monotonic():
        return None
    return cache.get("data")


def _store_cached_status(config: MonitorConfig, data: Dict[str, object]) -> None:
    ttl = getattr(app.state, "cache_ttl_seconds", 0.0)
    if ttl <= 0:
        return
    app.state.status_cache = {
        "config": config,
        "data": data,
        "expires_at": time.monotonic() + ttl,
    }


@app.get("/status", tags=["monitoring"])
async def read_status(
    request: Request,
    config: MonitorConfig = Depends(get_monitor_config),
) -> Dict[str, object]:
    """Return aggregated Supra lottery status via CLI view calls."""

    use_cache = _cache_available(request) and not _should_refresh(request.query_params)
    if use_cache:
        cached = _get_cached_status(config)
        if cached is not None:
            return cached

    try:
        data = gather_data(config)
    except CliError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    if use_cache or _cache_available(request):
        _store_cached_status(config, data)

    return data


@app.get("/lotteries/{lottery_id}/vrf-log", tags=["fairness"])
async def read_vrf_log(
    lottery_id: int,
    limit: int = Query(50, ge=1, le=500),
    config: MonitorConfig = Depends(get_monitor_config),
) -> Dict[str, Any]:
    """Возвращает события VRF и состояние раунда для панели честности."""

    try:
        return gather_vrf_log(config, lottery_id=lottery_id, limit=limit)
    except ValueError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except CliError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


@app.get("/commands", response_model=List[CommandInfo], tags=["commands"])
async def list_commands() -> List[CommandInfo]:
    """Return sorted metadata about the bundled CLI helper commands."""

    commands = [
        CommandInfo(name=name, module=module, description=description)
        for name, module, description in cli.iter_commands()
    ]
    commands.sort(key=lambda item: item.name)
    return commands


@app.post("/commands/{command}", response_model=CommandResponse, tags=["commands"])
async def run_command(command: str, payload: CommandRequest) -> CommandResponse:
    """Execute one of the bundled Supra CLI helper scripts."""

    if command not in cli.COMMAND_MAP:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail=f"Unknown command: {command}")

    cmd = [sys.executable, "-m", "supra.scripts.cli", command]
    if payload.args:
        cmd.extend(payload.args)

    process = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=_command_environment(payload.supra_config),
    )

    return CommandResponse(
        command=command,
        args=payload.args,
        returncode=process.returncode,
        stdout=process.stdout.strip(),
        stderr=process.stderr.strip(),
    )


def main(argv: Optional[List[str]] | None = None) -> None:
    """CLI entry point for running the API server."""

    parser = argparse.ArgumentParser(description="Supra Lottery REST API server")
    parser.add_argument("--host", default=os.environ.get("SUPRA_API_HOST", "0.0.0.0"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("SUPRA_API_PORT", "8000")))
    parser.add_argument(
        "--reload",
        action="store_true",
        help="Enable FastAPI reload (development only)",
    )
    parser.add_argument(
        "--log-level",
        default=os.environ.get("SUPRA_API_LOG_LEVEL", "info"),
        choices=("critical", "error", "warning", "info", "debug", "trace"),
    )
    parser.add_argument(
        "--cache-ttl",
        type=float,
        default=float(os.environ.get("SUPRA_API_CACHE_TTL", "0") or 0),
        help="Cache TTL in seconds for /status responses (0 disables caching)",
    )
    parser.add_argument(
        "--cors-origins",
        default=os.environ.get("SUPRA_API_CORS_ORIGINS"),
        help="Comma-separated list of origins allowed by CORS (set to * to allow all)",
    )
    args = parser.parse_args(argv)

    if args.cache_ttl is not None:
        os.environ["SUPRA_API_CACHE_TTL"] = str(args.cache_ttl)
    if args.cors_origins is not None:
        os.environ["SUPRA_API_CORS_ORIGINS"] = args.cors_origins

    _configure_cors()

    uvicorn.run(
        "supra.scripts.api_server:app",
        host=args.host,
        port=args.port,
        reload=args.reload,
        log_level=args.log_level,
    )


__all__ = ["app", "run_command", "list_commands", "read_status", "health", "main"]
