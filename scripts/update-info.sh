#!/usr/bin/env bash
# Syncs info.json with the Carbon remote config, mirroring the GitHub Action behaviour.

set -euo pipefail

URL="https://carbon.website/carbon/android-resources/dapps/info.json"
INFO_FILE="info.json"
ETAG_FILE="info.etag"

cleanup() {
  rm -f "${TMP_JSON:-}" "${TMP_ETAG:-}"
}
trap cleanup EXIT

TMP_JSON="$(mktemp)"
TMP_ETAG="$(mktemp)"

echo "Checking remote ETag..."
if curl -fsSI "$URL" | awk 'BEGIN {IGNORECASE=1} /^etag:/ {print $2; exit}' | tr -d '\r' > "$TMP_ETAG"; then
  if [ -s "$TMP_ETAG" ]; then
    NEW_ETAG="$(cat "$TMP_ETAG")"
    OLD_ETAG="$(cat "$ETAG_FILE" 2>/dev/null || true)"
    if [ "$NEW_ETAG" = "$OLD_ETAG" ]; then
      echo "ETag unchanged ($NEW_ETAG). Nothing to do."
      exit 0
    fi
    echo "ETag changed from '${OLD_ETAG:-<none>}' to '$NEW_ETAG'. Downloading new info.json..."
    curl -fsSL "$URL" -o "$TMP_JSON"
    mv "$TMP_JSON" "$INFO_FILE"
    printf '%s\n' "$NEW_ETAG" > "$ETAG_FILE"
    echo "info.json updated and ETag stored."
    exit 0
  fi
  echo "No ETag found in response; falling back to file comparison."
else
  echo "Failed to fetch headers from $URL" >&2
  exit 1
fi

curl -fsSL "$URL" -o "$TMP_JSON"
if [ -f "$INFO_FILE" ] && cmp -s "$TMP_JSON" "$INFO_FILE"; then
  echo "Remote info.json matches local copy. Nothing to do."
  exit 0
fi

mv "$TMP_JSON" "$INFO_FILE"
rm -f "$ETAG_FILE"
echo "info.json updated (ETag unavailable). Removed cached ETag."
