# PDF-to-Audiobook Pipeline (Self-Hosted)

Convert a personal PDF library into audiobooks (M4B with chapters) and
listen to them on iPhone via Audiobookshelf — entirely on a single
self-hosted Docker server.

## Pipeline overview

```
PDFs (your library)
   │
   ▼
[Calibre]  -- PDF -> EPUB cleanup (strips headers/footers, keeps chapters)
   │
   ▼
[abogen]   -- EPUB -> M4B audiobook via Kokoro TTS (on-demand, CPU/GPU)
   │
   ▼
[Audiobookshelf] -- always-on library server
   │
   ▼
iPhone (Audiobookshelf app) -- manual download per book, offline listening
```

**Design choices baked into this setup:**
- Calibre and abogen are **manually started** (`profiles: ["convert"]`),
  so they never run in the background or compete with your other
  containers for CPU/RAM unless you explicitly start them.
- Audiobookshelf is **always-on** but very lightweight at idle.
- All resource limits are set conservatively for an older 4-core /
  16GB homeserver. Adjust in `docker-compose.yml` if your hardware
  differs.

---

## Prerequisites

- Docker and Docker Compose v2 installed on your homeserver
- Git installed
- Your existing PDF collection, placed somewhere accessible

---

## 1. Clone this repository

```bash
git clone <your-repo-url> audiobook-pipeline
cd audiobook-pipeline
```

## 2. Set up environment variables

```bash
cp .env.example .env
```

Find your user/group IDs (so container file permissions match your host
user):

```bash
id -u   # PUID
id -g   # PGID
```

Edit `.env` and fill in `PUID`, `PGID`, and your `TZ` (e.g. `Asia/Kolkata`,
`Europe/Oslo`).

## 3. Clone abogen's source (needed to build the image)

abogen has no official prebuilt Docker image, so we build it from
source. Clone it into `abogen-src/` next to this README:

```bash
git clone https://github.com/denizsafak/abogen.git abogen-src
```

> If abogen's repo structure changes in the future and the build
> fails, check their README for the current `Dockerfile` path and
> update the `dockerfile:` line in `docker-compose.yml` accordingly.

## 4. Fix folder ownership

The `data/` folders are tracked in git as empty placeholders, but once
cloned they may be owned by whichever user/process did the cloning.
Make sure they're owned by your `abhix` user so containers (running as
`PUID`/`PGID` from `.env`) and Docker itself can read/write without
permission errors:

```bash
sudo chown -R abhix:abhix data/
```

Confirm `abhix`'s UID/GID match what you put in `.env`:

```bash
id -u abhix   # should match PUID in .env
id -g abhix   # should match PGID in .env
```

## 5. Add your PDFs

Copy your PDF collection into:

```
data/pdfs/
```

## 6. Start Audiobookshelf (always-on service)

```bash
docker compose up -d audiobookshelf
```

Visit `http://<server-ip>:19378` and complete the initial setup
(create admin user, add a library pointing at `/audiobooks`).

---

## 7. Convert PDFs to EPUB (Calibre, on-demand)

Start Calibre only when you need it:

```bash
docker compose --profile convert run --rm calibre bash /scripts/convert-pdfs.sh
```

This batch-converts every PDF in `data/pdfs/` into a matching EPUB in
`data/epubs/`, skipping any that have already been converted. The
container exits automatically when done (`--rm`), so nothing lingers
in the background.

> Optional: if you ever want the visual Calibre desktop (e.g. to
> manually fix a messy PDF before conversion), run
> `docker compose --profile convert up -d calibre` and open
> `http://<server-ip>:18083` in a browser. Stop it afterwards with
> `docker compose stop calibre`.

---

## 8. Benchmark before converting a full book (recommended)

Processing speed varies a lot by hardware. Before queuing an entire
500-page book, test with a single chapter first:

1. Save one chapter (~3,000–5,000 words) as a `.txt` file in
   `data/epubs/_benchmark_sample.txt`
2. Run:
   ```bash
   bash scripts/benchmark-chapter.sh
   ```
3. Follow the printed instructions to time a single job in the
   abogen Web UI, then scale that time up to your full book's word
   count.

This avoids accidentally kicking off a multi-day job you didn't
expect.

---

## 9. Convert EPUB to Audiobook (abogen, on-demand)

Start abogen only when you have EPUBs ready to process:

```bash
docker compose --profile convert up -d abogen
```

Open the Web UI:

```
http://<server-ip>:18808
```

1. Drag in EPUB file(s) from your library (mounted at `/data/uploads`
   inside the container, i.e. your local `data/epubs/` folder)
2. Configure:
   - **Voice**: pick one, preview before committing
   - **Output format**: `M4B (with chapters)`
   - **Output bitrate**: 64 kbps is the audiobook-standard sweet spot
     (smaller files, plenty clear for speech)
3. Use **queue mode** to add multiple books and let them process
   back-to-back unattended
4. Optional: configure **Settings → Integrations → Audiobookshelf** in
   the abogen UI (base URL, library ID, API token) so finished M4B
   files are pushed directly into your Audiobookshelf library —
   no manual file copying needed

When the queue is done, stop the container so it's not idling on
resources:

```bash
docker compose stop abogen
```

(Or `docker compose --profile convert down` to fully remove it until
next time.)

---

## 10. Listen on iPhone

1. Install the official **Audiobookshelf** app from the App Store
2. Connect it to `http://<server-ip>:19378` (or your reverse-proxied
   HTTPS URL if accessing outside your home network — see note below)
3. Sign in with the user you created in step 5
4. Browse your library — books only **stream** by default
5. Tap the **download icon** on any book you want available offline
   for your commute; delete it from the app afterwards to free up
   space
6. No auto-sync — you stay in full manual control of what's stored on
   your phone

### Accessing Audiobookshelf outside your home network

The setup above only works on your home Wi-Fi. For commute/office
access, you'll need either:
- A reverse proxy (e.g. Nginx Proxy Manager, Caddy, Traefik) with a
  domain and TLS certificate, or
- A mesh VPN like **Tailscale** installed on both your server and
  iPhone (simplest option, no port-forwarding or public domain
  required)

This is outside the scope of this repo, but both are well documented
elsewhere if you want to add either later.

---

## Ports used by this stack

Chosen specifically to avoid clashing with common defaults (8080,
3000, 5000, 8096, etc.) that homelab stacks tend to grab:

| Service | Host port | Purpose |
|---|---|---|
| audiobookshelf | 19378 | Web UI + API (always-on) |
| abogen | 18808 | Web UI (only when started) |
| calibre | 18083 | Optional GUI (only when started) |

If any of these still happen to collide with something on your
server, just change the host-side number (left of the colon) in
`docker-compose.yml` — the container-internal port (right of the
colon) should stay as-is.

## Resource notes

| Container | When it runs | CPU limit | RAM limit |
|---|---|---|---|
| calibre | manual / on-demand | 1.0 | 1 GB |
| abogen | manual / on-demand | 3.0 | 6 GB |
| audiobookshelf | always-on | 0.5 | 512 MB |

Adjust these in `docker-compose.yml` under each service's
`deploy.resources.limits` to match your actual hardware and how much
headroom you want left for other containers.

## Troubleshooting

- **abogen build fails**: check that `abogen-src/Dockerfile`
  exists after cloning; abogen's repo structure may change over time.
- **Permission errors on mounted folders**: double check `PUID`/`PGID`
  in `.env` match your host user (`id -u`, `id -g`).
- **Conversion seems stuck**: check container logs with
  `docker compose logs -f abogen`.
- **Audiobookshelf doesn't see new books**: trigger a library rescan
  from its web UI, or check the scan settings under library settings.

## Project structure

```
audiobook-pipeline/
├── docker-compose.yml
├── .env.example
├── README.md
├── scripts/
│   ├── convert-pdfs.sh        # batch PDF -> EPUB via Calibre CLI
│   └── benchmark-chapter.sh   # timing helper before full-book runs
├── abogen-src/                # cloned separately, see step 3 (gitignored)
└── data/
    ├── pdfs/                  # put source PDFs here
    ├── epubs/                 # Calibre output / abogen input
    ├── audiobooks/            # abogen output / Audiobookshelf library
    ├── calibre-config/
    ├── abogen-config/
    ├── abs-config/
    └── abs-metadata/
```
