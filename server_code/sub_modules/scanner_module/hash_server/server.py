import asyncio
import csv
import os
import sqlite3
import urllib.request
from io import StringIO
from pathlib import Path

from fastapi import FastAPI, HTTPException

BASE_DIR     = Path(__file__).resolve().parent
RAW_DB_DIR   = BASE_DIR / "raw_database"
COMPILED_DIR = BASE_DIR / "compiled"
HASH_DB      = COMPILED_DIR / "hashes.db"
BAZAAR_OUT   = RAW_DB_DIR / "bazaar_recent_hashes.txt"

BAZAAR_INTERVAL = int(os.getenv("BAZAAR_INTERVAL", str(60 * 60 * 2)))
BAZAAR_URL      = "https://bazaar.abuse.ch/export/csv/recent/"

app = FastAPI(title="SafeHaven Hash Server")


def _conn() -> sqlite3.Connection:
    conn = sqlite3.connect(str(HASH_DB))
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")
    return conn


def _init_db() -> None:
    COMPILED_DIR.mkdir(parents=True, exist_ok=True)
    conn = _conn()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS hashes (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            file_hash TEXT UNIQUE,
            metadata  TEXT
        )
    """)
    conn.commit()
    conn.close()


def _compile_db() -> int:
    if not RAW_DB_DIR.is_dir():
        return 0

    conn = _conn()
    batch: list[tuple[str, str]] = []
    total = 0

    for path in RAW_DB_DIR.glob("*.txt"):
        with open(path, "r", errors="ignore") as f:
            for line in f:
                h = line.strip()
                if not h:
                    continue
                batch.append((h, path.name))
                if len(batch) >= 5000:
                    conn.executemany(
                        "INSERT OR IGNORE INTO hashes (file_hash, metadata) VALUES (?, ?)",
                        batch,
                    )
                    conn.commit()
                    total += len(batch)
                    batch.clear()

    if batch:
        conn.executemany(
            "INSERT OR IGNORE INTO hashes (file_hash, metadata) VALUES (?, ?)",
            batch,
        )
        conn.commit()
        total += len(batch)

    conn.close()
    return total


def _fetch_bazaar() -> None:
    print("[bazaar] fetching from MalwareBazaar")
    req = urllib.request.Request(BAZAAR_URL, headers={"User-Agent": "CS-Hash-Fetch/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        text = resp.read().decode("utf-8", errors="ignore")

    sha256_list: list[str] = []
    md5_list: list[str]    = []

    reader = csv.reader(StringIO(text))
    for row in reader:
        if not row or row[0].startswith("#"):
            continue
        if len(row) > 2:
            sha256_list.append(row[1].strip().strip('"').lower())
            md5_list.append(row[2].strip().strip('"').lower())

    RAW_DB_DIR.mkdir(parents=True, exist_ok=True)
    with open(BAZAAR_OUT, "w", encoding="utf-8") as f:
        for h in sha256_list + md5_list:
            f.write(h + "\n")

    count = _compile_db()
    print(f"[bazaar] done — {len(sha256_list)} sha256 + {len(md5_list)} md5, {count} total in DB")


async def _bazaar_loop() -> None:
    print(f"[bazaar] loop started — interval={BAZAAR_INTERVAL}s")
    while True:
        try:
            await asyncio.to_thread(_fetch_bazaar)
        except Exception as exc:
            print(f"[bazaar] fetch error: {exc}")
        await asyncio.sleep(BAZAAR_INTERVAL)


@app.on_event("startup")
async def _startup() -> None:
    _init_db()
    asyncio.create_task(_bazaar_loop())


@app.get("/health")
async def health() -> dict:
    conn = _conn()
    count = conn.execute("SELECT COUNT(*) FROM hashes").fetchone()[0]
    conn.close()
    return {"ok": True, "hash_count": count}


@app.get("/check/{h}")
async def check_hash(h: str) -> dict:
    conn = _conn()
    row = conn.execute("SELECT file_hash FROM hashes WHERE file_hash = ?", (h,)).fetchone()
    conn.close()
    return {"exists": bool(row)}


@app.post("/add/{h}")
async def add_hash(h: str) -> dict:
    conn = _conn()
    try:
        conn.execute("INSERT INTO hashes (file_hash) VALUES (?)", (h,))
        conn.commit()
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=400, detail="already exists")
    conn.close()
    return {"status": "added"}


@app.post("/check_batch")
async def check_batch(hashes: list[str]) -> dict:
    if not hashes:
        return {"found": []}
    placeholders = ",".join("?" for _ in hashes)
    conn = _conn()
    rows = conn.execute(
        f"SELECT file_hash FROM hashes WHERE file_hash IN ({placeholders})",
        hashes,
    ).fetchall()
    conn.close()
    return {"found": [r[0] for r in rows]}