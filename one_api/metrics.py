from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from threading import Lock


@dataclass(slots=True)
class MetricSnapshot:
    counters: dict[str, int]
    timings_ms: dict[str, list[float]]


_LOCK = Lock()
_COUNTERS: defaultdict[str, int] = defaultdict(int)
_TIMINGS: defaultdict[str, list[float]] = defaultdict(list)


def increment(name: str, amount: int = 1) -> None:
    with _LOCK:
        _COUNTERS[name] += amount


def observe_ms(name: str, value: float) -> None:
    with _LOCK:
        _TIMINGS[name].append(value)


def record_request(duration_ms: float, status_code: int) -> None:
    increment("requests_total")
    increment(f"requests_status_{status_code}")
    observe_ms("request_latency_ms", duration_ms)


def record_db_query_duration(duration_ms: float) -> None:
    increment("db_queries_total")
    observe_ms("db_query_latency_ms", duration_ms)


def record_materialization_call(created_logs: int) -> None:
    increment("materialization_calls")
    increment("materialization_logs_created", created_logs)


def snapshot() -> MetricSnapshot:
    with _LOCK:
        return MetricSnapshot(counters=dict(_COUNTERS), timings_ms={k: list(v) for k, v in _TIMINGS.items()})
