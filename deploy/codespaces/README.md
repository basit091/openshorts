# Run OpenShorts privately in GitHub Codespaces (iPad / iPhone guide)

This folder runs the full self-host OpenShorts stack (backend + production
dashboard behind nginx) inside a GitHub Codespace. Everything happens in your
browser: no computer, no paid service, no public URL.

What you get: paste a YouTube link or upload a video, the AI picks the best
moments, and you get vertical 9:16 clips with burned subtitles, a hook and a
title, ready to preview and save to Files or Photos.

## Files in this folder

1. `docker-compose.codespaces.yml`: override on top of the root
   `docker-compose.yml`. Production dashboard on port 8080 (bound to
   127.0.0.1), backend not published, named volumes for clips, uploads and the
   model cache, limits sized for a 4-core / 16 GB machine (one job at a time).
2. `nginx.conf`: serves the built dashboard and forwards the API, `/videos`,
   `/thumbnails`, `/gallery`, `/mcp` and health routes to the backend, with
   2 GB uploads.
3. `start.sh`, `stop.sh`, `status.sh`: start, stop and inspect the stack.
4. `../../.devcontainer/devcontainer.json`: tells Codespaces to use a 4-core
   machine with Docker, forward port 8080 and run `start.sh` on every start.

## Before you start (one time)

1. Prevent charges. Personal accounts get a monthly free Codespaces quota
   (120 core-hours of compute and 15 GB-month of storage at the time of
   writing; check https://docs.github.com/en/billing/concepts/product-billing/github-codespaces).
   If no payment method is on your account, Codespaces simply stops working
   when the quota is used up: nothing is charged. If you do have a payment
   method, open https://github.com/settings/billing, go to Budgets and alerts,
   and make sure the Codespaces budget is $0 with "Stop usage when budget
   limit is reached" turned on.
2. Set the idle timeout and retention: open
   https://github.com/settings/codespaces. Set "Default idle timeout" to a
   value you are comfortable with (30 minutes saves quota; up to 240 minutes
   keeps a long render alive while you are away). Set "Default retention
   period" to the number of days a stopped codespace is kept (max 30).
3. Get a free Gemini API key at https://aistudio.google.com/apikey. Keep it to
   yourself: you will type it into the OpenShorts settings page in Safari,
   never into a file, a commit or a chat.
4. Optional: also save it as a Codespaces secret named `GEMINI_API_KEY`
   (https://github.com/settings/codespaces, "Codespaces secrets", give it
   access to your OpenShorts repository). The dashboard still asks for the key
   in its settings; the secret is only the server fallback used by the REST
   API and MCP when a request carries no key.

## Create the codespace (first time, about 15 to 25 minutes)

1. In Safari open your fork on github.com and pick the branch you want (the
   deployment branch, or `main` once it is merged).
2. Tap the green "Code" button, then the "Codespaces" tab, then "..." and
   "New with options".
3. Choose the branch, region closest to you, and the "4-core" machine type.
   Tap "Create codespace". VS Code opens in the browser.
4. The first start builds the backend and dashboard images. Open the terminal
   (menu, View, Terminal) to follow it. If nothing is building, run:

```
bash deploy/codespaces/start.sh
```

5. Wait for the line "OpenShorts is running" followed by your private URL.

## Open OpenShorts on iPad or iPhone

1. In VS Code open the "Ports" tab. Port 8080 ("OpenShorts") must show
   Visibility "Private". If it says Public, long-press it, choose
   "Port Visibility" and pick "Private".
2. Tap the globe icon next to port 8080, or copy the URL printed by
   `start.sh`. It looks like https://YOUR-CODESPACE-NAME-8080.app.github.dev
3. Safari may ask you to sign in to GitHub: only you (the codespace owner) can
   open a private port. Add the page to your Home Screen for quick access
   while the codespace runs.
4. Open Settings (gear icon) and paste your Gemini key. It is stored only in
   Safari on this device and sent only to your own codespace.

## Make clips

1. Paste a YouTube link, or tap the upload tab and pick a video from Files or
   Photos (MP4 and iPhone MOV/HEVC both work, up to 2 GB).
2. Choose the number of clips and options, then start. One job runs at a time;
   a 2 to 3 minute video takes about 2 minutes, longer videos take longer.
3. When it finishes, play each clip in the page. Use the download button on a
   clip, or "download all" for a ZIP. Safari saves downloads to the Files app
   (Downloads folder). To put a clip in Photos: open it in Files, tap Share,
   then "Save Video".

## Stop, restart and keep your files

1. Stop the codespace when you are done so it stops using quota: on
   https://github.com/codespaces tap "..." next to it and "Stop codespace".
   It also stops by itself after the idle timeout.
2. A stopped codespace keeps everything: clips, uploads, the downloaded AI
   models and the built images. Start it again from the same page; `start.sh`
   runs automatically and the app is back in about a minute.
3. Inside the codespace you can also stop only the app with:

```
bash deploy/codespaces/stop.sh
```

4. Clips are not a permanent archive. Finished jobs are removed after 3 days,
   older files are pruned when the output folder passes 8 GB, and a codespace
   unused for its retention period is deleted with everything in it. Download
   the clips you want to keep.
5. Deleting the codespace deletes all clips inside it. Your code on GitHub is
   not affected.

## Check status

```
bash deploy/codespaces/status.sh
```

Shows containers, health, memory, disk and the private URL. Follow the
backend log (this also counts as activity for the idle timer) with:

```
bash deploy/codespaces/status.sh logs
```

Free disk space taken by old build layers with:

```
bash deploy/codespaces/status.sh clean
```

## Optional: the Remotion renderer

The default stack does not start the Remotion renderer service (the dashboard
renders style edits in the browser). To include it:

```
WITH_RENDERER=1 bash deploy/codespaces/start.sh --rebuild
```

It adds an image of about 3 GB, so it uses more storage quota. Known issue:
the renderer image currently builds but exits at startup with "export
'Interactive' was not found in 'remotion'" (its Remotion packages are pinned
only to `^4.0.0` and resolve to mismatched versions). Nothing in the dashboard
or the clip pipeline needs it, so leave it off unless that is fixed.

## Quotas and costs

1. Compute: a 4-core machine uses 4 core-hours per hour, so the 120 free
   core-hours give about 30 hours of running time per month. Stopped
   codespaces use no compute.
2. Storage: the codespace disk (built images, AI models, clips) counts
   against the 15 GB-month storage quota for as long as the codespace
   exists, even when stopped. Expect roughly 7 GB for the built images and
   models plus your clips (up to 8 GB of clips and 4 GB of uploads before the
   caps prune old files). Run `status.sh clean` after rebuilds, download
   and delete clips you no longer need, and delete codespaces you do not use.
   Do not enable prebuilds: they use extra storage.
3. Gemini: the free tier of the default model has per-minute and per-day
   request limits set by Google (shown in Google AI Studio). One job makes a
   handful of requests; if you hit the limit the job retries once and then
   fails with a quota message: wait and try again later.
4. Nothing in this setup needs a payment method.

## Security notes

1. Keep port 8080 Private. A Public port would let anyone with the URL use
   your codespace and your Gemini key fallback, because self-host OpenShorts
   has no login of its own.
2. A private port is reachable only after signing in to GitHub as the
   codespace owner. The GitHub sign-in for forwarded ports expires after a
   few hours; Safari will ask again.
3. The backend port 8000 is not forwarded; only nginx on 8080 is.
4. Never commit keys or put them in `.env` files in the repository. Use the
   dashboard settings or Codespaces secrets.

## Troubleshooting

1. YouTube says "Sign in to confirm you're not a bot": YouTube often blocks
   cloud servers. This setup does not use cookies. Download the video on your
   device (or use your own copy) and use the upload tab instead.
2. "Gemini API key missing" banner: open Settings and paste the key again
   (Safari private browsing does not keep it).
3. Job fails with a quota or 429 message: the Gemini free limit was reached.
   Wait a few minutes (per-minute limit) or until the next day (daily limit).
4. The page does not open or shows a 502: run `bash deploy/codespaces/status.sh`.
   If Docker is not running, use the command palette, "Codespaces: Rebuild
   Container", then run `start.sh` again.
5. "No space left on device": run `bash deploy/codespaces/status.sh clean`,
   then delete old clips in the dashboard.
6. After pulling new code, rebuild the images with:

```
bash deploy/codespaces/start.sh --rebuild
```

7. A large upload fails or stalls: try a shorter or smaller file (trim it in
   Photos first). Very large uploads through the Codespaces port forwarder
   have not been tested.
8. The start log says "could not confirm the port visibility automatically":
   this is normal inside a codespace. Check the Ports tab: port 8080 must show
   Private (it is private unless someone changed it).
9. The start log says "Allowed traffic between the app containers (Docker
   network fix)": normal on some machines; `start.sh` fixed the Docker network
   so the dashboard can reach the backend. Nothing to do.
10. The startup did not run after a restart (the page does not load): open a
   terminal and run `bash deploy/codespaces/start.sh`.
11. The dashboard here is the production build served by nginx, not the Vite
   dev server, so the Vite "host not allowed" error does not apply.
