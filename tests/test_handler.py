"""Unit tests for the health check handler. No AWS account required."""

import base64
import importlib
import json
import os
import sys

import boto3
import pytest
from moto import mock_aws

TABLE_NAME = "test-requests-db"
REGION = "eu-north-1"

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))


@pytest.fixture()
def handler_module():
    os.environ.update(
        {
            "TABLE_NAME": TABLE_NAME,
            "ENVIRONMENT": "test",
            "AWS_DEFAULT_REGION": REGION,
            "AWS_ACCESS_KEY_ID": "testing",
            "AWS_SECRET_ACCESS_KEY": "testing",
            "AWS_SECURITY_TOKEN": "testing",
            "AWS_SESSION_TOKEN": "testing",
        }
    )
    with mock_aws():
        boto3.client("dynamodb", region_name=REGION).create_table(
            TableName=TABLE_NAME,
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        sys.modules.pop("handler", None)
        module = importlib.import_module("handler")
        yield module


def _event(body, is_base64=False, method="POST"):
    return {
        "httpMethod": method,
        "path": "/health",
        "isBase64Encoded": is_base64,
        "body": body,
        "requestContext": {
            "requestId": "abc-123",
            "httpMethod": method,
            "path": "/staging/health",
            "identity": {"sourceIp": "203.0.113.7", "userAgent": "pytest"},
        },
    }


def _scan(handler_module):
    return boto3.resource("dynamodb", region_name=REGION).Table(TABLE_NAME).scan()["Items"]


def test_valid_payload_returns_200_and_persists(handler_module):
    result = handler_module.handler(_event(json.dumps({"payload": {"check": "ok"}})))

    assert result["statusCode"] == 200
    assert json.loads(result["body"]) == {
        "status": "healthy",
        "message": "Request processed and saved.",
    }

    items = _scan(handler_module)
    assert len(items) == 1
    assert json.loads(items[0]["payload"]) == {"check": "ok"}
    assert items[0]["source_ip"] == "203.0.113.7"
    assert items[0]["environment"] == "test"


def test_missing_payload_key_returns_400(handler_module):
    result = handler_module.handler(_event(json.dumps({"something_else": 1})))

    assert result["statusCode"] == 400
    assert "payload" in json.loads(result["body"])["message"]
    assert _scan(handler_module) == []


def test_absent_body_returns_400(handler_module):
    result = handler_module.handler(_event(None, method="GET"))

    assert result["statusCode"] == 400
    assert _scan(handler_module) == []


def test_malformed_json_returns_400(handler_module):
    result = handler_module.handler(_event("{not json"))

    assert result["statusCode"] == 400
    assert "valid JSON" in json.loads(result["body"])["message"]


def test_json_array_body_returns_400(handler_module):
    result = handler_module.handler(_event(json.dumps([1, 2, 3])))

    assert result["statusCode"] == 400
    assert "JSON object" in json.loads(result["body"])["message"]


def test_base64_encoded_body_is_decoded(handler_module):
    encoded = base64.b64encode(json.dumps({"payload": "hi"}).encode()).decode()
    result = handler_module.handler(_event(encoded, is_base64=True))

    assert result["statusCode"] == 200
    assert json.loads(_scan(handler_module)[0]["payload"]) == "hi"


def test_null_payload_is_accepted(handler_module):
    """The contract is that the key exists, not that it is truthy."""
    result = handler_module.handler(_event(json.dumps({"payload": None})))

    assert result["statusCode"] == 200


def test_ttl_attribute_is_written(handler_module):
    handler_module.handler(_event(json.dumps({"payload": "x"})))
    assert int(_scan(handler_module)[0]["expires_at"]) > 0
