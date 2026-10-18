# MediaMTX binary source.
# Versjonen er pinnet slik at nye utgivelser ikke endrer oppførsel uventet.
# Oppgrader bevisst og test publisering + avspilling etterpå.
FROM bluenviron/mediamtx:1.19.2 AS mediamtx

# Liten runtime med CA-pakke (HTTP-auth mot Supabase) og curl (hooks som
# melder fra til live-video-event når en strøm starter/stopper). Det offisielle
# MediaMTX-imaget har verken skall eller curl.
FROM alpine:3.22

RUN apk add --no-cache ca-certificates curl \
    && update-ca-certificates

COPY --from=mediamtx /mediamtx /mediamtx
COPY hooks/live-event.sh /usr/local/bin/live-event.sh
COPY mediamtx.yml /mediamtx.yml

# MediaMTX gjør ingen omkoding: H.264 fra RTMP kopieres rått til WebRTC.
EXPOSE 1935/tcp 8889/tcp 8189/tcp

ENTRYPOINT ["/mediamtx", "/mediamtx.yml"]
