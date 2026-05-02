#!/usr/bin/env python3
"""
Export backend data from Swasthya Setu APIs into local JSON files.

Usage examples:

1) Use an existing token:
   python scripts/export_db_snapshot.py --token "<JWT>"

2) Login first, then export:
   python scripts/export_db_snapshot.py --employee-id "A123" --password "secret" --role "asha"

3) Custom output folder:
   python scripts/export_db_snapshot.py --token "<JWT>" --out "exports/my_snapshot"
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, List, Optional, Tuple


DEFAULT_BASE_URL = "https://swasthya-setu-full.onrender.com"

ENDPOINTS: List[Tuple[str, str]] = [
    ("me", "/api/v1/users/me"),
    ("asha_workers", "/api/v1/users/asha"),
    ("patients", "/api/v1/patients/"),
    ("triage_records", "/api/v1/triage_records/"),
    ("outbreaks", "/api/v1/outbreaks"),
    ("reviews", "/api/v1/reviews"),
]


def _request_json(
    method: str,
    url: str,
    token: Optional[str] = None,
    payload: Optional[Dict[str, Any]] = None,
    timeout: int = 60,
) -> Any:
    body = None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    if payload is not None:
        body = json.dumps(payload).encode("utf-8")

    req = urllib.request.Request(url=url, data=body, method=method.upper(), headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            if not raw.strip():
                return {}
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"HTTP {e.code} for {url}: {detail}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"Network error for {url}: {e}") from e


def _login(base_url: str, employee_id: str, password: str, role: str) -> str:
    login_url = urllib.parse.urljoin(base_url, "/api/v1/auth/login")
    data = _request_json(
        "POST",
        login_url,
        payload={
            "employee_id": employee_id,
            "password": password,
            "role": role,
        },
    )

    token = data.get("access_token")
    if not token:
        raise RuntimeError("Login succeeded but no access_token found in response.")
    return token


def _normalize_possible_page_payload(data: Any) -> Tuple[List[Any], Optional[str]]:
    if isinstance(data, list):
        return data, None

    if isinstance(data, dict):
        if isinstance(data.get("results"), list):
            next_url = data.get("next") if isinstance(data.get("next"), str) else None
            return data["results"], next_url
        if isinstance(data.get("items"), list):
            next_url = data.get("next") if isinstance(data.get("next"), str) else None
            return data["items"], next_url

    return [data], None


def _fetch_all_pages(base_url: str, path: str, token: str) -> Any:
    first_url = urllib.parse.urljoin(base_url, path)
    first = _request_json("GET", first_url, token=token)

    items, next_url = _normalize_possible_page_payload(first)
    if next_url is None:
        if isinstance(first, list):
            return first
        return first

    all_items = list(items)
    while next_url:
        page_data = _request_json("GET", next_url, token=token)
        page_items, next_url = _normalize_possible_page_payload(page_data)
        all_items.extend(page_items)
        time.sleep(0.05)

    return all_items


def _write_json(path: pathlib.Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Export backend DB data into local JSON files.")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="Backend base URL")
    parser.add_argument("--token", default=None, help="JWT token (Bearer token value)")
    parser.add_argument("--employee-id", default=None, help="Employee ID for login")
    parser.add_argument("--password", default=None, help="Password for login")
    parser.add_argument("--role", default="asha", choices=["asha", "tho"], help="Role for login")
    parser.add_argument("--out", default="exports/db_snapshot", help="Output folder")
    args = parser.parse_args()

    token = args.token
    if not token:
        if not args.employee_id or not args.password:
            print(
                "Error: provide either --token OR both --employee-id and --password",
                file=sys.stderr,
            )
            return 2
        print("Logging in to fetch access token...")
        token = _login(args.base_url, args.employee_id, args.password, args.role)

    out_dir = pathlib.Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    manifest: Dict[str, Any] = {
        "base_url": args.base_url,
        "exported_at_epoch": int(time.time()),
        "files": [],
        "errors": [],
    }

    print(f"Exporting API data to: {out_dir.resolve()}")

    for name, path in ENDPOINTS:
        try:
            data = _fetch_all_pages(args.base_url, path, token)
            output_file = out_dir / f"{name}.json"
            _write_json(output_file, data)

            count = len(data) if isinstance(data, list) else 1
            manifest["files"].append(
                {
                    "endpoint": path,
                    "name": name,
                    "file": str(output_file),
                    "count": count,
                }
            )
            print(f"  OK  {path} -> {output_file.name} ({count} records)")
        except Exception as e:  # noqa: BLE001
            msg = str(e)
            manifest["errors"].append({"endpoint": path, "error": msg})
            print(f"  ERR {path} -> {msg}")

    _write_json(out_dir / "manifest.json", manifest)

    if manifest["errors"]:
        print("\nCompleted with errors. Check manifest.json for details.")
        return 1

    print("\nExport complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
