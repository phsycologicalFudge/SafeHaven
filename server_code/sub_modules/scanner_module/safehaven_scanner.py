import asyncio
import hashlib
import os
import re
import struct
import time
import httpx
import subprocess
import tempfile
from typing import Any
from fastapi import FastAPI

CS_API_URL       = os.getenv("CS_API_URL", "https://api.colourswift.com").rstrip("/")
VPS_AUTH_SECRET  = os.getenv("VPS_AUTH_SECRET", "").strip()
POLL_INTERVAL    = int(os.getenv("POLL_INTERVAL", "30"))
HASH_API_URL     = "https://efkou1u21ooih2hko.colourswift.com/check_batch"
HASH_API_KEY     = "23JVO3ojo23oO3O423rrTR"
HASH_TIMEOUT     = 8.0
DOWNLOAD_TIMEOUT = 60.0
RESCAN_COOLDOWN  = 7 * 86400
RESCAN_BATCH     = 10
RESCAN_IDLE      = 30
APKSIGNER_BIN    = os.getenv("APKSIGNER_BIN", "apksigner").strip()
AAPT2_BIN        = os.getenv("AAPT2_BIN", "aapt2").strip()

app = FastAPI(title="SafeHaven Scanner")

_rescan_cache: dict[str, int] = {}


def _parse_lp(data: bytes, offset: int) -> tuple[bytes, int]:
    if offset + 4 > len(data):
        raise ValueError("truncated length prefix")
    length = struct.unpack_from("<I", data, offset)[0]
    end = offset + 4 + length
    if end > len(data):
        raise ValueError("length prefix overruns buffer")
    return data[offset + 4:end], end


def extract_apk_manifest_info(apk_bytes: bytes) -> dict[str, Any]:
    apk_path = ""
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".apk") as tmp:
            tmp.write(apk_bytes)
            apk_path = tmp.name

        result = subprocess.run(
            [AAPT2_BIN, "dump", "badging", apk_path],
            capture_output=True,
            text=True,
            timeout=20,
        )

        if result.returncode != 0:
            return {}

        for line in result.stdout.splitlines():
            if not line.startswith("package:"):
                continue
            info: dict[str, Any] = {}
            m = re.search(r"name='([^']+)'", line)
            if m:
                info["packageName"] = m.group(1)
            m = re.search(r"versionCode='([^']+)'", line)
            if m:
                try:
                    info["versionCode"] = int(m.group(1))
                except ValueError:
                    pass
            m = re.search(r"versionName='([^']+)'", line)
            if m:
                info["versionName"] = m.group(1)
            return info

        return {}

    except Exception:
        return {}

    finally:
        if apk_path:
            try:
                os.remove(apk_path)
            except Exception:
                pass


def extract_signing_cert_hash_with_apksigner(apk_bytes: bytes) -> str | None:
    apk_path = ""
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".apk") as tmp:
            tmp.write(apk_bytes)
            apk_path = tmp.name

        result = subprocess.run(
            [APKSIGNER_BIN, "verify", "--print-certs", "--verbose", apk_path],
            capture_output=True,
            text=True,
            timeout=20,
        )

        output = f"{result.stdout}\n{result.stderr}"
        if result.returncode != 0:
            return None

        for line in output.splitlines():
            clean = line.strip()
            lower = clean.lower()
            if "certificate sha-256 digest:" in lower:
                return clean.split(":", 1)[1].strip().replace(" ", "").lower()
            if "signer #1 certificate sha-256 digest:" in lower:
                return clean.split(":", 1)[1].strip().replace(" ", "").lower()

        return None

    except Exception:
        return None

    finally:
        if apk_path:
            try:
                os.remove(apk_path)
            except Exception:
                pass


def extract_signing_cert_hash(apk_bytes: bytes) -> str | None:
    try:
        eocd_offset = apk_bytes.rfind(b"\x50\x4b\x05\x06")
        if eocd_offset < 0:
            return None

        cd_offset = struct.unpack_from("<I", apk_bytes, eocd_offset + 16)[0]
        if cd_offset < 24:
            return None

        if apk_bytes[cd_offset - 16:cd_offset] != b"APK Sig Block 42":
            return None

        sb_size  = struct.unpack_from("<Q", apk_bytes, cd_offset - 24)[0]
        sb_start = cd_offset - 8 - sb_size
        if sb_start < 0:
            return None

        pos = sb_start + 8
        end = cd_offset - 24

        sig_block = None
        while pos + 12 <= end:
            pair_len = struct.unpack_from("<Q", apk_bytes, pos)[0]
            pair_id  = struct.unpack_from("<I", apk_bytes, pos + 8)[0]
            if pair_id in (0x7109871A, 0xF05368C0):
                sig_block = apk_bytes[pos + 12:pos + 8 + pair_len]
                break
            pos += 8 + pair_len

        if sig_block is None:
            return None

        signers_data, _ = _parse_lp(sig_block, 0)
        signer_data,  _ = _parse_lp(signers_data, 0)
        signed_data,  _ = _parse_lp(signer_data, 0)
        _, after_digests = _parse_lp(signed_data, 0)
        certs_data,   _ = _parse_lp(signed_data, after_digests)
        cert_bytes,   _ = _parse_lp(certs_data, 0)

        return hashlib.sha256(cert_bytes).hexdigest()

    except Exception:
        return None


def extract_best_signing_cert_hash(apk_bytes: bytes) -> str | None:
    result = extract_signing_cert_hash_with_apksigner(apk_bytes)
    return result if result else extract_signing_cert_hash(apk_bytes)


async def check_hashes(hashes: list[str]) -> dict[str, Any]:
    if not hashes:
        return {"verdict": "not_checked", "matches": [], "note": "No hashes supplied"}

    normalised = []
    seen: set[str] = set()
    for h in hashes:
        if not isinstance(h, str):
            continue
        v = h.strip().lower()
        if not v or v in seen:
            continue
        seen.add(v)
        normalised.append(v)

    if not normalised:
        return {"verdict": "not_checked", "matches": [], "note": "No valid hashes after normalisation"}

    try:
        async with httpx.AsyncClient(timeout=HASH_TIMEOUT) as http:
            response = await http.post(
                HASH_API_URL,
                headers={"Content-Type": "application/json", "x-cs-key": HASH_API_KEY},
                json=normalised,
            )
        response.raise_for_status()
        data = response.json()

        if not isinstance(data, dict):
            return {"verdict": "unknown", "matches": [], "note": "Unexpected response shape from hash API"}

        found = data.get("found", [])
        if not isinstance(found, list):
            found = []

        found_normalised = []
        found_seen: set[str] = set()
        for h in found:
            if not isinstance(h, str):
                continue
            v = h.strip().lower()
            if not v or v in found_seen:
                continue
            found_seen.add(v)
            found_normalised.append(v)

        if found_normalised:
            return {
                "verdict": "known_malware",
                "matches": [{"hash": h, "label": "known malware hash match"} for h in found_normalised],
            }

        return {"verdict": "clean", "matches": []}

    except httpx.TimeoutException:
        return {"verdict": "unknown", "matches": [], "note": "Hash check timed out"}
    except Exception as exc:
        return {"verdict": "unknown", "matches": [], "note": f"Hash check error: {exc}"}


async def download_apk(url: str) -> bytes:
    async with httpx.AsyncClient(timeout=DOWNLOAD_TIMEOUT, follow_redirects=True) as http:
        response = await http.get(url)
        response.raise_for_status()
        return response.content


async def post_scan_result(submission_id: str, result: dict[str, Any]) -> None:
    async with httpx.AsyncClient(timeout=15.0) as http:
        response = await http.post(
            f"{CS_API_URL}/internal/store/scan-result",
            headers={"Content-Type": "application/json", "x-vps-auth": VPS_AUTH_SECRET},
            json={"submissionId": submission_id, **result},
        )
        response.raise_for_status()


async def post_rescan_result(result: dict[str, Any]) -> None:
    async with httpx.AsyncClient(timeout=15.0) as http:
        response = await http.post(
            f"{CS_API_URL}/internal/store/rescan-result",
            headers={"Content-Type": "application/json", "x-vps-auth": VPS_AUTH_SECRET},
            json=result,
        )
        response.raise_for_status()


async def fetch_pending_scans() -> list[dict[str, Any]]:
    async with httpx.AsyncClient(timeout=15.0) as http:
        response = await http.get(
            f"{CS_API_URL}/internal/store/pending-scans",
            headers={"x-vps-auth": VPS_AUTH_SECRET},
        )
        response.raise_for_status()
        return response.json().get("submissions", [])


async def fetch_rescan_targets() -> list[dict[str, Any]]:
    async with httpx.AsyncClient(timeout=15.0) as http:
        response = await http.get(
            f"{CS_API_URL}/internal/store/rescan-targets",
            headers={"x-vps-auth": VPS_AUTH_SECRET},
        )
        response.raise_for_status()
        return response.json().get("targets", [])


async def process_submission(submission: dict[str, Any]) -> None:
    submission_id       = submission.get("id", "")
    download_url        = submission.get("downloadUrl", "")
    package_name        = submission.get("package_name", "")
    version_code        = submission.get("version_code", "")
    auto_tracked        = bool(submission.get("autoTracked", False))
    stored_signing_hash = (submission.get("storedSigningKeyHash") or "").strip().lower() or None

    if not submission_id or not download_url:
        print(f"[scanner] skipping submission with missing id or downloadUrl: {submission_id}")
        return

    print(f"[scanner] processing {package_name}@{version_code} ({submission_id}) auto_tracked={auto_tracked}")

    try:
        apk_bytes = await download_apk(download_url)
    except Exception as exc:
        print(f"[scanner] download failed for {submission_id}: {exc}")
        await post_scan_result(submission_id, {
            "passed":    False,
            "detail":    {"error": "download_failed", "note": str(exc)},
            "scannedAt": int(time.time()),
        })
        return

    sha256      = hashlib.sha256(apk_bytes).hexdigest()
    apk_size    = len(apk_bytes)
    signing_key = extract_best_signing_cert_hash(apk_bytes)
    manifest    = extract_apk_manifest_info(apk_bytes)
    scanned_at  = int(time.time())

    print(f"[scanner] sha256={sha256} size={apk_size} signingKey={signing_key} manifest={manifest} for {submission_id}")

    if auto_tracked and stored_signing_hash and signing_key:
        if signing_key != stored_signing_hash:
            print(f"[scanner] signing mismatch for {submission_id}: stored={stored_signing_hash} got={signing_key}")
            await post_scan_result(submission_id, {
                "passed":         False,
                "detail":         {
                    "verdict":         "signing_key_changed",
                    "storedKeyHash":   stored_signing_hash,
                    "observedKeyHash": signing_key,
                    "matches":         [],
                },
                "apkSha256":      sha256,
                "apkSize":        apk_size,
                "scannedAt":      scanned_at,
                "signingKeyHash": signing_key,
            })
            return

    hash_result = await check_hashes([sha256])
    verdict     = hash_result.get("verdict", "unknown")
    passed      = verdict != "known_malware"

    print(f"[scanner] verdict={verdict} passed={passed} for {submission_id}")

    payload: dict[str, Any] = {
        "passed":    passed,
        "detail":    hash_result,
        "apkSha256": sha256,
        "apkSize":   apk_size,
        "scannedAt": scanned_at,
    }
    if signing_key:
        payload["signingKeyHash"] = signing_key
    if manifest.get("packageName"):
        payload["packageName"] = manifest["packageName"]
    if manifest.get("versionCode") is not None:
        payload["manifestVersionCode"] = manifest["versionCode"]
    if manifest.get("versionName"):
        payload["manifestVersionName"] = manifest["versionName"]

    await post_scan_result(submission_id, payload)
    print(f"[scanner] result posted for {submission_id}")


async def process_rescan(target: dict[str, Any]) -> None:
    package_name = target.get("packageName", "")
    version_code = target.get("versionCode")
    download_url = target.get("downloadUrl", "")
    cache_key    = f"{package_name}@{version_code}"

    if not package_name or version_code is None or not download_url:
        return

    print(f"[rescan] scanning {cache_key}")

    try:
        apk_bytes = await download_apk(download_url)
    except Exception as exc:
        print(f"[rescan] download failed for {cache_key}: {exc}")
        return

    sha256      = hashlib.sha256(apk_bytes).hexdigest()
    apk_size    = len(apk_bytes)
    signing_key = extract_best_signing_cert_hash(apk_bytes)
    manifest    = extract_apk_manifest_info(apk_bytes)
    scanned_at  = int(time.time())

    hash_result = await check_hashes([sha256])
    verdict     = hash_result.get("verdict", "unknown")
    passed      = verdict != "known_malware"

    print(f"[rescan] verdict={verdict} for {cache_key}")

    payload: dict[str, Any] = {
        "packageName": package_name,
        "versionCode": version_code,
        "passed":      passed,
        "detail":      hash_result,
        "apkSha256":   sha256,
        "apkSize":     apk_size,
        "scannedAt":   scanned_at,
    }
    if signing_key:
        payload["signingKeyHash"] = signing_key
    if manifest.get("packageName"):
        payload["manifestPackageName"] = manifest["packageName"]
    if manifest.get("versionCode") is not None:
        payload["manifestVersionCode"] = manifest["versionCode"]
    if manifest.get("versionName"):
        payload["manifestVersionName"] = manifest["versionName"]

    try:
        await post_rescan_result(payload)
        _rescan_cache[cache_key] = scanned_at
        print(f"[rescan] result posted for {cache_key}")
    except Exception as exc:
        print(f"[rescan] post failed for {cache_key}: {exc}")


async def poll_loop() -> None:
    print(f"[scanner] poll loop started — interval={POLL_INTERVAL}s")
    while True:
        try:
            submissions = await fetch_pending_scans()
            if submissions:
                print(f"[scanner] {len(submissions)} pending scan(s)")
                for submission in submissions:
                    try:
                        await process_submission(submission)
                    except Exception as exc:
                        print(f"[scanner] error processing {submission.get('id')}: {exc}")
        except Exception as exc:
            print(f"[scanner] poll error: {exc}")

        await asyncio.sleep(POLL_INTERVAL)


async def rescan_loop() -> None:
    print(f"[rescan] rescan loop started — cooldown={RESCAN_COOLDOWN}s batch={RESCAN_BATCH} idle={RESCAN_IDLE}s")
    while True:
        try:
            targets = await fetch_rescan_targets()
            now     = int(time.time())

            candidates = []
            for t in targets:
                key          = f"{t.get('packageName')}@{t.get('versionCode')}"
                last_scanned = _rescan_cache.get(key) or t.get("scannedAt") or 0
                if now - last_scanned >= RESCAN_COOLDOWN:
                    candidates.append((last_scanned, t))

            candidates.sort(key=lambda x: x[0])
            batch = [t for _, t in candidates[:RESCAN_BATCH]]

            if batch:
                print(f"[rescan] {len(batch)} target(s) due")
                for target in batch:
                    try:
                        await process_rescan(target)
                    except Exception as exc:
                        print(f"[rescan] error: {exc}")
            else:
                print("[rescan] no targets due, idling")

        except Exception as exc:
            print(f"[rescan] loop error: {exc}")

        await asyncio.sleep(RESCAN_IDLE)


@app.on_event("startup")
async def startup() -> None:
    if not VPS_AUTH_SECRET:
        raise RuntimeError("VPS_AUTH_SECRET is not set")
    asyncio.create_task(poll_loop())
    asyncio.create_task(rescan_loop())


@app.get("/health")
async def health() -> dict[str, Any]:
    return {
        "ok":            True,
        "hash_api_url":  HASH_API_URL,
        "api_url":       CS_API_URL,
        "poll_interval": POLL_INTERVAL,
        "rescan_cached": len(_rescan_cache),
    }