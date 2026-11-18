"""Run inside the app Pod: python - < scripts/check-db.py (or PowerShell pipeline)."""
import os
import socket
import sys

import psycopg

host = os.environ["DB_HOST"]
port = int(os.environ["DB_PORT"])
try:
    print(f"DNS: {host} -> {socket.gethostbyname(host)}", flush=True)
    with socket.create_connection((host, port), timeout=3):
        print(f"TCP: {host}:{port} accesible", flush=True)
    with psycopg.connect(host=host, port=port, dbname=os.environ["DB_NAME"],
                         user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"],
                         connect_timeout=3) as connection:
        print(f"SQL: SELECT 1 -> {connection.execute('SELECT 1').fetchone()[0]}", flush=True)
except Exception as error:
    print(f"FALLO: {type(error).__name__}; revisar DNS, Service/targetPort y Secret", flush=True)
    sys.exit(1)
