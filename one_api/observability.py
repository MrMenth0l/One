from __future__ import annotations

import logging
import time
from uuid import uuid4

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

from one_api.metrics import record_request


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        logger = logging.getLogger("one_api.request")
        start = time.perf_counter()
        request_id = request.headers.get("x-request-id") or str(uuid4())

        response = None
        user_id = "anonymous"
        try:
            response = await call_next(request)
            user_id = getattr(request.state, "user_id", user_id)
            duration_ms = (time.perf_counter() - start) * 1000
            response.headers["x-request-id"] = request_id
            record_request(duration_ms=duration_ms, status_code=response.status_code)
            logger.info(
                "request completed",
                extra={
                    "request_id": request_id,
                    "user_id": user_id,
                    "route": request.url.path,
                    "status": response.status_code,
                    "duration_ms": round(duration_ms, 2),
                },
            )
            return response
        except Exception:
            duration_ms = (time.perf_counter() - start) * 1000
            record_request(duration_ms=duration_ms, status_code=500)
            logger.exception(
                "request failed",
                extra={
                    "request_id": request_id,
                    "user_id": user_id,
                    "route": request.url.path,
                    "status": 500,
                    "duration_ms": round(duration_ms, 2),
                },
            )
            raise
