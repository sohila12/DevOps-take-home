import logging
import os
import sys
from datetime import datetime, timezone

import boto3
import psycopg2
from flask import Flask, jsonify

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    stream=sys.stdout,  # captured by the CloudWatch Agent via the Docker log driver / mounted log dir
)
logger = logging.getLogger("app")

app = Flask(__name__)

AWS_REGION = os.environ.get("AWS_REGION", "eu-west-1")
SSM_DB_PARAM_PREFIX = os.environ.get("SSM_DB_PARAM_PREFIX")  # e.g. /devops-takehome/dev/db


def _load_db_config():
    """
    Resolve DB connection info at process startup:
      1. host + name from SSM Parameter Store (plain strings, not secret)
      2. the secret ARN from SSM, then the actual password from Secrets Manager

    This indirection is what lets the Launch Template stay static (no DB
    host/password baked into user-data) — the app discovers everything at
    runtime using only its IAM role's scoped read permissions.
    """
    if not SSM_DB_PARAM_PREFIX:
        logger.warning("SSM_DB_PARAM_PREFIX not set — DB features disabled (local/dev mode)")
        return None

    ssm = boto3.client("ssm", region_name=AWS_REGION)
    secretsmanager = boto3.client("secretsmanager", region_name=AWS_REGION)

    host = ssm.get_parameter(Name=f"{SSM_DB_PARAM_PREFIX}/host")["Parameter"]["Value"]
    db_name = ssm.get_parameter(Name=f"{SSM_DB_PARAM_PREFIX}/name")["Parameter"]["Value"]
    secret_arn = ssm.get_parameter(Name=f"{SSM_DB_PARAM_PREFIX}/secret_arn")["Parameter"]["Value"]

    secret = secretsmanager.get_secret_value(SecretId=secret_arn)
    import json

    creds = json.loads(secret["SecretString"])

    return {
        "host": host,
        "port": 5432,
        "dbname": db_name,
        "user": creds["username"],
        "password": creds["password"],
    }


_db_config = None
_db_config_loaded = False


def get_db_config():
    global _db_config, _db_config_loaded
    if not _db_config_loaded:
        try:
            _db_config = _load_db_config()
        except Exception:
            logger.exception("Failed to load DB config")
            _db_config = None
        _db_config_loaded = True
    return _db_config


@app.route("/health")
def health():
    """
    ALB target group health check. Deliberately does NOT touch the database —
    a slow/unavailable DB shouldn't make the ALB tear down otherwise-healthy
    instances. DB connectivity is checked separately via /ready.
    """
    return jsonify(status="ok", time=datetime.now(timezone.utc).isoformat())


@app.route("/ready")
def ready():
    """Deeper check that actually exercises the DB connection."""
    config = get_db_config()
    if config is None:
        return jsonify(status="not_ready", reason="db_config_unavailable"), 503

    try:
        conn = psycopg2.connect(**config, connect_timeout=3)
        conn.close()
        return jsonify(status="ready")
    except Exception as exc:
        logger.exception("DB readiness check failed")
        return jsonify(status="not_ready", reason=str(exc)), 503


@app.route("/")
def index():
    return jsonify(
        message="Hello from the DevOps take-home backend",
        time=datetime.now(timezone.utc).isoformat(),
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
