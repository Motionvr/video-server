# AviSafe live video (MediaMTX på Fly.io)

Tar imot RTMP(S)-videostrøm fra DJI Pilot 2 og FlightHub 2 og leverer den
videre til AviSafe i nettleseren via WebRTC (WHEP). Ingen omkoding, ingen
opptak – kun live.

Denne appen er helt uavhengig av `mqtt-broker-avisafe`.

```
Pilot 2 / FlightHub 2 --RTMPS 1936--> MediaMTX --WebRTC/WHEP 443--> AviSafe
                                          |
                                          +--HTTP auth--> live-video-auth (Supabase)
```

## Deploy

```bash
cd video-server
fly launch --no-deploy --name live-video-avisafe --region ams   # kun første gang
fly secrets set \
  MTX_AUTHHTTPADDRESS="https://<prosjekt>.supabase.co/functions/v1/live-video-auth" \
  MTX_WEBRTCALLOWORIGINS="https://app.avisafe.no,https://mil.avisafe.no" \
  LIVE_VIDEO_EVENT_SECRET="<samme som LIVE_VIDEO_EVENT_SECRET i Supabase>"
fly deploy
```

Etter første deploy:

```bash
fly ips list          # noter den offentlige IPv4-adressen
fly secrets set MTX_WEBRTCADDITIONALHOSTS="<offentlig-ip>"
fly deploy
```

**Viktig:** uten `MTX_WEBRTCADDITIONALHOSTS` fullføres signaleringen, men
videoen kommer aldri – ICE finner ingen brukbar kandidat.

MediaMTX leser alle innstillinger i `mediamtx.yml` som kan overstyres av
miljøvariabler med prefiks `MTX_`. Secrets over er derfor nok; `${...}`-verdiene
i yml-filen er kun dokumentasjon av hvilke variabler som brukes.

`MTX_WEBRTCALLOWORIGINS` (flertall, kommaseparert) overstyrer `webrtcAllowOrigins`
(standard `*`; avspilling er uansett beskyttet av kortlevd token). Enkeltallsnavnet
`MTX_WEBRTCALLOWORIGIN` finnes ikke og blir ignorert.

## Aktiv/inaktiv-status

`runOnReady` / `runOnNotReady` i `mediamtx.yml` kjører `hooks/live-event.sh`, som
kaller edge-funksjonen `live-video-event` slik at `drone_live_streams.active`
oppdateres med en gang strømmen starter/stopper. Uten `LIVE_VIDEO_EVENT_SECRET`
gjør skriptet ingenting. Hooken kan ikke stoppe eller forsinke videoen.

## Porter

| Port utad | Internt | Bruk                                   |
| --------- | ------- | -------------------------------------- |
| 443 / 80  | 8889    | WebRTC-signalering (WHEP) til nettleser |
| 1936      | 1935    | RTMPS inn fra Pilot 2 / FH2            |
| 1935      | 1935    | RTMP uten TLS (reserve, mindre sikkert)|
| 8189      | 8189    | WebRTC-media over TCP                  |

## Én maskin

`min_machines_running = 1` og `auto_stop_machines = false` er bevisst: den som
publiserer og den som ser på må treffe samme instans. Skal dette skaleres må
det inn en relay-/edge-løsning foran.

## Feilsøking

- **«Not authorized» ved publisering:** strømnøkkelen er ukjent eller sperret.
  Hent ny adresse i AviSafe (drone → Live video → Oppsett).
- **Avspilling henger på «kobler til»:** `MTX_WEBRTCADDITIONALHOSTS` mangler
  eller peker på feil IP.
- **Pilot 2 nekter `rtmps://`:** bruk `rtmp://<host>:1935/live/<nøkkel>` som
  reserve. Da er strømmen ukryptert på veien – kun for test.
- Logger: `fly logs -a live-video-avisafe`. NB: MediaMTX logger hele stien, og
  stien inneholder strømnøkkelen. Ikke del loggutdrag uten å maskere den.
