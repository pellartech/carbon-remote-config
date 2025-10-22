#!/usr/bin/env bash
# Syncs info.json with the Carbon remote config, mirroring the GitHub Action behaviour.

set -euo pipefail

URL="https://carbon.website/carbon/android-resources/dapps/info.json"
INFO_FILE="info.json"
ETAG_FILE="info.etag"

cleanup() {
  rm -f "${TMP_JSON:-}" "${TMP_HEADERS:-}"
}
trap cleanup EXIT

TMP_JSON="$(mktemp)"
TMP_HEADERS="$(mktemp)"

OLD_ETAG="$(cat "$ETAG_FILE" 2>/dev/null || true)"

echo "Requesting info.json (If-None-Match: ${OLD_ETAG:-<none>})..."
CURL_ARGS=(-sS -w '%{http_code}' -D "$TMP_HEADERS" -o "$TMP_JSON")
if [ -n "$OLD_ETAG" ]; then
  HTTP_STATUS="$(curl "${CURL_ARGS[@]}" -H "If-None-Match: $OLD_ETAG" "$URL")"
else
  HTTP_STATUS="$(curl "${CURL_ARGS[@]}" "$URL")"
fi

if [ "$HTTP_STATUS" = "304" ]; then
  echo "Remote ETag unchanged; local info.json is up to date."
  exit 0
fi

if [ "$HTTP_STATUS" != "200" ] && [ -n "$OLD_ETAG" ]; then
  echo "Conditional request returned HTTP $HTTP_STATUS. Retrying without ETag header..."
  : > "$TMP_HEADERS"
  HTTP_STATUS="$(curl "${CURL_ARGS[@]}" "$URL")"
fi

if [ "$HTTP_STATUS" != "200" ]; then
  echo "Unexpected HTTP status: $HTTP_STATUS" >&2
  exit 1
fi

NEW_ETAG="$(awk 'BEGIN {IGNORECASE=1} /^etag:/ {print $2; exit}' "$TMP_HEADERS" | tr -d '\r')"

mv "$TMP_JSON" "$INFO_FILE"
echo "info.json downloaded and saved."

if [ -n "$NEW_ETAG" ]; then
  printf '%s\n' "$NEW_ETAG" > "$ETAG_FILE"
  echo "Stored new ETag: $NEW_ETAG"
else
  rm -f "$ETAG_FILE"
  echo "No ETag returned; cleared cached ETag."
fi
