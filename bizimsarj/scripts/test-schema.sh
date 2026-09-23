#!/usr/bin/env bash
# Geçici bir PostgreSQL kümesi açar, şemayı + seed'i yükler, şema testlerini çalıştırır, kapatır.
# Kullanım: bizimsarj/scripts/test-schema.sh   (PG_BIN ile postgres bin dizini verilebilir)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG_BIN="${PG_BIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
[ -x "$PG_BIN/initdb" ] || { echo "initdb bulunamadı (PG_BIN=$PG_BIN)"; exit 1; }
TMP="$(mktemp -d)"; PORT="${PORT:-54329}"
cleanup() { "$PG_BIN/pg_ctl" -D "$TMP/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT
if [ "$(id -u)" = "0" ]; then RUN="runuser -u postgres --"; chown -R postgres "$TMP"; else RUN=""; fi
$RUN "$PG_BIN/initdb" -D "$TMP/data" -U postgres --auth=trust -E UTF8 --locale=C.UTF-8 >/dev/null
$RUN "$PG_BIN/pg_ctl" -D "$TMP/data" -o "-p $PORT -k $TMP -c listen_addresses=''" -w start >/dev/null
PSQL=(psql -h "$TMP" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q)
"${PSQL[@]}" -c "CREATE DATABASE bizimsarj"
"${PSQL[@]}" -d bizimsarj -f "$ROOT/database/schema.sql" >/dev/null
"${PSQL[@]}" -d bizimsarj -f "$ROOT/database/seed_dev.sql" >/dev/null
"${PSQL[@]}" -d bizimsarj -f "$ROOT/database/tests/schema_test.sql" 2>&1 | sed -n 's/.*NOTICE:  //p'
echo "Tablo sayısı: $("${PSQL[@]}" -d bizimsarj -tAc "SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename !~ '_[0-9]{6}$'")"
