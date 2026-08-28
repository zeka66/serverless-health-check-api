"""Health check handler.
Logs the incoming event, requires a 'payload' key in the JSON body (400 if
missing), stores the request under a generated UUID, returns 200.
"""

from __future__ import annotations

import base64
import json
import logging
import os
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

TABLE_NAME = os.environ["TABLE_NAME"]
ENVIRONMENT = os.environ.get("ENVIRONMENT", "unknown")
TTL_DAYS = int(os.environ.get("TTL_DAYS", "30"))
_TABLE = boto3.resource("dynamodb").Table(TABLE_NAME)


class ValidationError(Exception):
    """Raised when the incoming request fails input validation."""


def _response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
        },
        "body": json.dumps(body),
    }


def _decode_body(event: Dict[str, Any]) -> str:
    raw = event.get("body")

    if raw is None or (isinstance(raw, str) and raw.strip() == ""):
        raise ValidationError("A JSON request body is required.")

    if event.get("isBase64Encoded") and isinstance(raw, str):
        try:
            raw = base64.b64decode(raw).decode("utf-8")
        except Exception as exc:  # noqa: BLE001 - any decode failure is a client error
            raise ValidationError("Request body is not valid base64.") from exc

    if isinstance(raw, (bytes, bytearray)):
        raw = raw.decode("utf-8", errors="replace")

    return raw


def _parse_and_validate(event: Dict[str, Any]) -> Dict[str, Any]:
    raw = _decode_body(event)

    if isinstance(raw, dict):
        body = raw
    else:
        try:
            body = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ValidationError("Request body must be valid JSON.") from exc

    if not isinstance(body, dict):
        raise ValidationError("Request body must be a JSON object.")

    if "payload" not in body:
        raise ValidationError("Request body must contain a 'payload' key.")

    return body


def _build_item(event: Dict[str, Any], body: Dict[str, Any], request_id: str) -> Dict[str, Any]:
    ctx = event.get("requestContext") or {}
    identity = ctx.get("identity") or {}
    now = datetime.now(timezone.utc)

    item: Dict[str, Any] = {
        "id": str(uuid.uuid4()),
        "received_at": now.isoformat(),
        "environment": ENVIRONMENT,
        "lambda_request_id": request_id,
        "api_request_id": ctx.get("requestId"),
        "http_method": ctx.get("httpMethod") or event.get("httpMethod"),
        "path": ctx.get("path") or event.get("path"),
        "source_ip": identity.get("sourceIp"),
        "user_agent": identity.get("userAgent"),
        "payload": json.dumps(body["payload"], default=str),
    }

    if TTL_DAYS > 0:
        item["expires_at"] = int(time.time()) + TTL_DAYS * 86400

    return {k: v for k, v in item.items() if v is not None}


def handler(event: Dict[str, Any], context: Any = None) -> Dict[str, Any]:
    request_id = getattr(context, "aws_request_id", "local")

    logger.info("Incoming request event: %s", json.dumps(event, default=str))

    try:
        body = _parse_and_validate(event)
    except ValidationError as exc:
        logger.warning("Rejected request %s: %s", request_id, exc)
        return _response(400, {"status": "error", "message": str(exc)})

    item = _build_item(event, body, request_id)

    _TABLE.put_item(Item=item)
    logger.info("Stored request as item id=%s", item["id"])

    return _response(200, {"status": "healthy", "message": "Request processed and saved."})
