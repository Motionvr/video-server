# AviSafe live video (MediaMTX på Fly.io)

Fly-app: **`video-server-app`** (`video-server-app.fly.dev`). Dette repoet er
den eneste kilden til konfigurasjonen.

Tar imot RTMP-videostrøm fra DJI-apper (Pilot 2, FlightHub 2, Fly, GO 4) og
andre kilder (OBS, Larix …) og leverer den videre til AviSafe i nettleseren
via WebRTC (WHEP). Ingen omkoding, ingen opptak – kun live.

Denne appen er helt uavhengig av `mqtt-broker-avisafe`.

```
DJI-apper      --RTMP  1935--------------------> MediaMTX --WebRTC/WHEP 443--> AviSafe
OBS / Larix    --RTMPS 1936 (Fly terminerer TLS)-->   |
                                                      +--HTTP auth--> live-video-auth (Supabase)
```

DJI-appene godtar **bare `rtmp://`**, så port 1935 er hovedveien. Adressen
som AviSafe viser under drone → Live video → Oppsett er
`rtmp://video-server-app.fly.dev:1935/live/<strømnøkkel>`.

## Deploy

```bash
fly deploy -a video-server-app
```

Første gang (ny app):

```bash
fly launch --no-deploy --name video-server-app --region ams
fly ips allocate-v4 -a video-server-app     # se «Egen IPv4» under
fly ips list -a video-server-app            # noter IPv4-adressen
fly secrets set -a video-server-app MTX_WEBRTCADDITIONALHOSTS="<IPv4>"
fly deploy -a video-server-app
```

### Egen IPv4 (påkrevd)

Port 1935 (RTMP) og 8189 (WebRTC-media) er ren TCP (`handlers = []`). Fly
ruter ren TCP **kun via en dedikert IPv4** – med bare delt IPv4 når
tilkoblingene aldri fram, og det står ingenting i loggen. Sjekk med
`fly ips list`: står det bare `shared v4`, kjør `fly ips allocate-v4`.

`MTX_WEBRTCADDITIONALHOSTS` **må** være satt som secret. Mangler den (eller er
den tom), avslutter MediaMTX ved oppstart med «at least one between
'webrtcIPsFromInterfaces' or 'webrtcAdditionalHosts' must be filled», og da
svarer verken RTMP, RTMPS eller nettleseren. Byttes IPv4-adressen, må secreten
oppdateres til den nye.

## Konfigurasjon

MediaMTX utvider ikke `${...}` i `mediamtx.yml`. Alle innstillinger kan
overstyres med miljøvariabler/secrets med prefiks `MTX_`
(f.eks. `MTX_WEBRTCADDITIONALHOSTS`).

MediaMTX-versjonen er låst i `Dockerfile`. Oppgrader bevisst og les
endringsloggen – konfignavn har endret seg mellom versjoner.

## Porter

| Port utad | Internt | Bruk                                              |
| --------- | ------- | ------------------------------------------------- |
| 443 / 80  | 8889    | WebRTC-signalering (WHEP) til nettleser           |
| 1935      | 1935    | RTMP inn – DJI Pilot 2 / FH2 / Fly / GO 4 (krever egen IPv4) |
| 1936      | 1935    | RTMPS inn (Fly terminerer TLS) – OBS, Larix o.l.  |
| 8189      | 8189    | WebRTC-media over TCP (krever egen IPv4)          |

## Én maskin

`min_machines_running = 1` og `auto_stop_machines = false` er bevisst: den som
publiserer og den som ser på må treffe samme instans. Skal dette skaleres må
det inn en relay-/edge-løsning foran.

Ikke merge Fly-dashboardets automatiske «scale»-PR-er uten å lese dem: de kan
legge inn `[http_service]` med `auto_stop_machines` og `min_machines_running = 0`.

## Feilsøking

Følg loggen mens du starter strømmen: `fly logs -a video-server-app`.

- **Ingenting i loggen når DJI/Larix kobler til:** tilkoblingen når ikke
  fram. Sjekk `fly status` (kjører maskinen?) og `fly ips list` (egen IPv4?).
  Test fra PC: `nc -vz video-server-app.fly.dev 1935`.
- **RTMPS (1936) virker, RTMP (1935) ikke:** appen mangler egen IPv4.
- **«authentication failed» / «Not authorized» ved publisering:** strømnøkkelen
  er ukjent, sperret eller fornyet. Lag ny adresse i AviSafe
  (drone → Live video → Oppsett).
- **Avspilling henger på «kobler til»:** `MTX_WEBRTCADDITIONALHOSTS` mangler
  eller peker på feil IP.
- **Maskinen starter ikke / feil ved oppstart:** les starten av
  `fly logs --no-tail`; ukjente konfignavn stopper MediaMTX.

Testsending uten drone (ffmpeg):

```bash
ffmpeg -re -f lavfi -i testsrc=size=1280x720:rate=30 -f lavfi -i sine \
  -c:v libx264 -preset veryfast -g 60 -c:a aac \
  -f flv "rtmp://video-server-app.fly.dev:1935/live/<strømnøkkel>"
```
