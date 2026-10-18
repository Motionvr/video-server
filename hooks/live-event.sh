#!/bin/sh
# Kalles av MediaMTX (runOnReady / runOnNotReady) slik at drone_live_streams
# markeres aktiv/inaktiv med en gang strømmen starter eller stopper.
# Bruk: live-event.sh publish|unpublish   (stien kommer i $MTX_PATH)
# Fire-and-forget: feil skal aldri påvirke selve videostrømmen.

EVENT="$1"
[ -n "$LIVE_VIDEO_EVENT_SECRET" ] || exit 0
[ -n "$MTX_PATH" ] || exit 0

URL="${LIVE_VIDEO_EVENT_URL:-https://pmucsvrypogtttrajqxq.supabase.co/functions/v1/live-video-event}"

curl -sS -m 10 -o /dev/null -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "x-event-secret: $LIVE_VIDEO_EVENT_SECRET" \
  -d "{\"event\":\"$EVENT\",\"path\":\"$MTX_PATH\"}" || true
