from __future__ import annotations

import argparse
import json
import socket
import ssl
import sys
import urllib.error
import urllib.request


def _tls_probe(hostname: str) -> dict[str, str]:
    context = ssl.create_default_context()
    raw = socket.socket()
    wrapped = context.wrap_socket(raw, server_hostname=hostname)
    wrapped.settimeout(10)
    wrapped.connect((hostname, 443))
    cert = wrapped.getpeercert()
    subject = dict(item[0] for item in cert["subject"]).get("commonName", "")
    tls_version = wrapped.version() or ""
    cipher = wrapped.cipher()[0] if wrapped.cipher() else ""
    wrapped.close()
    return {
        "subject_common_name": subject,
        "tls_version": tls_version,
        "cipher": cipher,
    }


def _get_json(url: str) -> tuple[int, dict]:
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            status = resp.status
            body = resp.read().decode("utf-8")
            return status, json.loads(body)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"HTTP {exc.code} for {url}: {body}") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify public HTTPS backend readiness")
    parser.add_argument(
        "--base-url",
        required=True,
        help="Public HTTPS backend URL, e.g. https://flatground-map-backend.onrender.com",
    )
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")
    if not base_url.startswith("https://"):
        print("FAIL: base URL must start with https://")
        return 1

    host = base_url.replace("https://", "").split("/")[0]
    tls = _tls_probe(host)
    print(f"TLS OK: {tls}")

    health_status, health_payload = _get_json(f"{base_url}/health")
    print(f"/health status: {health_status}")
    print(f"/health payload: {health_payload}")
    if health_status != 200:
        print("FAIL: /health did not return 200")
        return 1
    if health_payload.get("environment") != "production":
        print("FAIL: environment is not production")
        return 1
    if health_payload.get("storage") != "supabase":
        print("FAIL: storage is not supabase")
        return 1

    spots_status, spots_payload = _get_json(f"{base_url}/spots")
    print(f"/spots status: {spots_status}, count: {len(spots_payload) if isinstance(spots_payload, list) else 'n/a'}")
    if spots_status != 200:
        print("FAIL: /spots did not return 200")
        return 1

    print("PASS: public HTTPS backend checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
