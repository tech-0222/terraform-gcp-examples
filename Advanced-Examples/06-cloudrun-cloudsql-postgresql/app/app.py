import logging
import os

import psycopg
from flask import Flask, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)


def connect():
    return psycopg.connect(
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        host=os.environ["INSTANCE_UNIX_SOCKET"],
        connect_timeout=5,
    )


@app.get("/healthz")
def healthz():
    return jsonify(status="ok")


@app.get("/")
def index():
    try:
        with connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT current_database(), current_user")
                database, user = cur.fetchone()

        return jsonify(
            status="ok",
            database=database,
            user=user,
            connection="cloud-sql-unix-socket",
        )
    except Exception:
        app.logger.exception("Database connection failed")
        return jsonify(status="error", message="database connection failed"), 500
