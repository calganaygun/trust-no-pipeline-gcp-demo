#!/usr/bin/env python3
"""
Payments Vault API — Zero-Trust Workload Identity Demo App
Demonstrates:
1. Zero static JSON keys in environment or volume mounts
2. Pod-level GKE Workload Identity Federation token introspection
"""
import json
import os
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

METADATA_TOKEN_URL = (
    "http://metadata.google.internal/computeMetadata/v1/"
    "instance/service-accounts/default/token"
)
METADATA_EMAIL_URL = (
    "http://metadata.google.internal/computeMetadata/v1/"
    "instance/service-accounts/default/email"
)


def fetch_metadata(url: str) -> str:
    req = urllib.request.Request(url, headers={"Metadata-Flavor": "Google"})
    with urllib.request.urlopen(req, timeout=2) as resp:
        return resp.read().decode("utf-8")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            identity = fetch_metadata(METADATA_EMAIL_URL).strip()
            token_raw = json.loads(fetch_metadata(METADATA_TOKEN_URL))
            payload = {
                "status": "HARDENED_WORKLOAD_ACTIVE",
                "workload_identity_principal": identity,
                "token_type": token_raw.get("token_type"),
                "token_ttl_seconds": token_raw.get("expires_in"),
                "static_json_keys_present": "GOOGLE_APPLICATION_CREDENTIALS" in os.environ,
            }
        except Exception as exc:
            payload = {
                "status": "LOCAL_DEMO_MODE",
                "note": "GKE Metadata Server not reachable outside cluster",
                "detail": str(exc),
                "static_json_keys_present": "GOOGLE_APPLICATION_CREDENTIALS" in os.environ,
            }

        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    print(f"Starting Zero-Trust Demo App on port {port}...")
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
