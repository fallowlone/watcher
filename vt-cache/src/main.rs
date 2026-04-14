use hex;
use rusqlite::{params, Connection};
use sha2::{Digest, Sha256};
use std::env;
use std::fs;
use std::io;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

// ── DB ────────────────────────────────────────────────────────────────────────

fn db_path() -> String {
    let home = env::var("HOME").unwrap_or_else(|_| ".".into());
    env::var("VT_CACHE_DB").unwrap_or_else(|_| {
        format!("{}/.config/filesandbox/vt-cache.db", home)
    })
}

fn open_db() -> Connection {
    let path = db_path();
    if let Some(parent) = Path::new(&path).parent() {
        fs::create_dir_all(parent).ok();
    }
    let conn = Connection::open(&path).expect("Failed to open cache DB");
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS cache (
            sha256     TEXT PRIMARY KEY,
            verdict    TEXT NOT NULL,
            cached_at  INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_sha256 ON cache (sha256);",
    )
    .expect("Failed to init schema");
    conn
}

// ── Hashing ───────────────────────────────────────────────────────────────────

fn hash_file(path: &str) -> io::Result<String> {
    let bytes = fs::read(path)?;
    let mut h = Sha256::new();
    h.update(&bytes);
    Ok(hex::encode(h.finalize()))
}

fn now_secs() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
}

// ── Commands ──────────────────────────────────────────────────────────────────

/// check <filepath> → print verdict or "miss"
fn cmd_check(path: &str) {
    let sha = match hash_file(path) {
        Ok(h) => h,
        Err(_) => {
            println!("miss");
            return;
        }
    };
    let conn = open_db();
    let result: rusqlite::Result<String> = conn.query_row(
        "SELECT verdict FROM cache WHERE sha256 = ?1",
        params![sha],
        |row| row.get(0),
    );
    match result {
        Ok(verdict) => println!("{}", verdict),
        Err(_) => println!("miss"),
    }
}

/// store <filepath> <verdict>  — cache the result
fn cmd_store(path: &str, verdict: &str) {
    let sha = match hash_file(path) {
        Ok(h) => h,
        Err(e) => {
            eprintln!("error hashing {}: {}", path, e);
            std::process::exit(1);
        }
    };
    let conn = open_db();
    conn.execute(
        "INSERT OR REPLACE INTO cache (sha256, verdict, cached_at) VALUES (?1, ?2, ?3)",
        params![sha, verdict, now_secs()],
    )
    .expect("Failed to store verdict");
    eprintln!("cached {}…  →  {}", &sha[..16], verdict);
}

/// list — print recent cache entries
fn cmd_list() {
    let conn = open_db();
    let mut stmt = conn
        .prepare(
            "SELECT sha256, verdict, cached_at FROM cache ORDER BY cached_at DESC LIMIT 100",
        )
        .unwrap();
    let rows = stmt
        .query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, i64>(2)?,
            ))
        })
        .unwrap();
    for row in rows.flatten() {
        println!("{:.16}  {:18}  {}", row.0, row.1, row.2);
    }
}

/// clear — wipe the entire cache
fn cmd_clear() {
    let conn = open_db();
    let deleted = conn
        .execute("DELETE FROM cache", [])
        .expect("Failed to clear cache");
    eprintln!("cleared {} entries", deleted);
}

// ── Main ──────────────────────────────────────────────────────────────────────

fn usage() {
    eprintln!(
        "vt-cache — SHA-256 verdict cache for FileSandbox\n\
         \n\
         Commands:\n\
           check  <filepath>            print verdict or 'miss'\n\
           store  <filepath> <verdict>  cache a verdict\n\
           list                         show recent entries\n\
           clear                        wipe cache\n\
         \n\
         Env:\n\
           VT_CACHE_DB   path to SQLite DB  (default: ~/.config/filesandbox/vt-cache.db)"
    );
    std::process::exit(1);
}

fn main() {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("check") => cmd_check(args.get(2).map(String::as_str).unwrap_or_else(|| {
            eprintln!("check requires <filepath>");
            std::process::exit(1);
        })),
        Some("store") => {
            let path = args.get(2).map(String::as_str).unwrap_or_else(|| {
                eprintln!("store requires <filepath> <verdict>");
                std::process::exit(1);
            });
            let verdict = args.get(3).map(String::as_str).unwrap_or_else(|| {
                eprintln!("store requires <filepath> <verdict>");
                std::process::exit(1);
            });
            cmd_store(path, verdict);
        }
        Some("list") => cmd_list(),
        Some("clear") => cmd_clear(),
        _ => usage(),
    }
}
