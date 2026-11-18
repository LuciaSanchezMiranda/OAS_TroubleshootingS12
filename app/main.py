"""Small, deliberately diagnosable application for the S12 Kubernetes lab."""
import logging
import os
import socket
import time
from contextlib import asynccontextmanager
from pathlib import Path

import psycopg
from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("s12")


def settings():
    required = ("APP_ENV", "DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD")
    for name in required:
        if not os.environ.get(name):
            raise ValueError(f"CONFIG_ERROR: falta la variable {name}")
    if os.environ["APP_ENV"] != "lab":
        raise ValueError("CONFIG_ERROR: APP_ENV debe ser 'lab'; revisar ConfigMap s12-config")
    try:
        port = int(os.environ["DB_PORT"])
    except ValueError:
        raise ValueError("CONFIG_ERROR: DB_PORT debe ser un entero") from None
    if not 1 <= port <= 65535:
        raise ValueError("CONFIG_ERROR: DB_PORT debe estar entre 1 y 65535")
    return dict(host=os.environ["DB_HOST"], port=port, dbname=os.environ["DB_NAME"],
                user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"],
                connect_timeout=3)


def query_database():
    with psycopg.connect(**settings()) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT current_database(), current_user, 1")
            database, user, result = cursor.fetchone()
    return {"status": "connected", "database": database, "user": user, "query_result": result}


def error_category(error):
    # Never print connection exceptions: they can contain connection parameters.
    if isinstance(error, ValueError):
        return "CONFIG_ERROR"
    if getattr(error, "sqlstate", None) == "28P01":
        return "DB_AUTH_ERROR"
    return "DB_CONNECTION_ERROR"


@asynccontextmanager
async def lifespan(application):
    settings()  # Invalid ConfigMap/Secret injection must fail the process at startup.
    for attempt in range(1, 13):
        try:
            query_database()
            break
        except psycopg.Error as error:
            log.error("%s: intento %s/12; revisar Secret, DNS y Service/targetPort",
                      error_category(error), attempt)
            if attempt == 12:
                raise RuntimeError("DB_CONNECTION_ERROR: no se pudo iniciar; revisar logs y Service") from None
            time.sleep(2)
    log.info("STARTUP_OK: PostgreSQL conectado; uid=%s; puerto HTTP=8080", os.getuid())
    yield


app = FastAPI(title="S12 Cloud Lab", lifespan=lifespan)


@app.get("/", include_in_schema=False)
def home():
    return FileResponse(Path(__file__).with_name("index.html"))


@app.get("/health/live")
def live():
    return {"status": "alive"}


@app.get("/health/ready")
def ready():
    try:
        query_database()
        return {"status": "ready", "database": "connected"}
    except (psycopg.Error, ValueError) as error:
        log.warning("%s: readiness no disponible", error_category(error))
        return JSONResponse(status_code=503, content={"status": "not_ready", "code": error_category(error)})


@app.get("/api/status")
def status():
    payload = {"application": "S12 Cloud Lab", "environment": os.getenv("APP_ENV"),
               "hostname": socket.gethostname(), "uid": os.getuid(), "gid": os.getgid(),
               "non_root": os.getuid() != 0}
    try:
        payload["database"] = query_database()
        payload["status"] = "ok"
        return payload
    except (psycopg.Error, ValueError) as error:
        payload.update(status="degraded", database={"status": "disconnected", "code": error_category(error)})
        log.warning("%s: consulta de estado fallida", error_category(error))
        return JSONResponse(status_code=503, content=payload)
