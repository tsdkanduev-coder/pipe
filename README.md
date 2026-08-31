# Sled

A private, local-first work journal for Mac. Sled keeps Dayflow’s capture and timeline UI, rebranded, and stores everything on disk.

Derived from [Dayflow](https://github.com/JerryZLiu/Dayflow) (MIT). See `NOTICE`.

**macOS 14+.** Unsigned builds are OK. Not on the App Store.

## Permissions (S1)

Sled needs **Screen & System Audio Recording**.

1. Open Sled.
2. When prompted, grant Screen Recording, or open **System Settings → Privacy & Security → Screen Recording** and enable Sled.
3. If permission is missing, recording does **not** start silently. Status shows `Recording: off — Screen Recording permission required`.
4. Menu bar and Settings → Storage show **Recording: on** or **Recording: off**.
5. Stop recording does **not** delete SQLite rows.

## SQLite (S2)

Path (not iCloud):

```text
~/Library/Application Support/Sled/sled.sqlite
```

Same Dayflow store, path-shifted. Frames are JPEG files under `~/Library/Application Support/Sled/recordings/`. Screenshot bytes are never stored in the loopback API.

Rows used by the API (`timeline_cards`): `started_at`, `ended_at`, `app`, `window_title`, `summary`.

Stop capture does not delete these rows. There is no network for the store.

## Loopback API (S3)

While Sled is running:

```text
GET http://127.0.0.1:18741/v1/actions?since=<iso8601>&limit=50
```

- Host: `127.0.0.1` only. Port: `18741`.
- Fields: `id`, `started_at`, `ended_at`, `app`, `window_title`, `summary`.
- Default `limit` is 50. Max is 200.
- Empty result is `[]`.
- No screenshot bytes.
- If Sled is not running: connection refused. No cloud fallback.

```bash
curl 'http://127.0.0.1:18741/v1/actions?since=2026-08-31T00:00:00Z&limit=50'
```

## Local LLM only (S6)

Summaries and action extraction never leave the Mac.

- Provider is locked to **Local**.
- Ollama: `http://127.0.0.1:11434`
- LM Studio: `http://127.0.0.1:1234`
- Default vision model: `llama3.2-vision` if already present. Sled does **not** re-pull models.
- Gemini, ChatGPT, Claude, OpenRouter, and other cloud hosts are disabled. There is no API-key fallback.
- If Ollama / LM Studio is down: capture and the raw timeline still work; `summary` stays null; status shows **Install/start Ollama (or LM Studio)**.

If the model is not installed yet:

```bash
ollama pull llama3.2-vision
```

Keep Ollama running, or start LM Studio’s local server on port 1234.

## Gatekeeper (S4)

This environment is Linux and cannot produce a real `.app` / `.dmg`. Build on a Mac (see below), then:

1. Open `Sled.dmg`.
2. Drag **Sled** into Applications.
3. First launch: **Right-click → Open** (unsigned is OK).
4. No App Store.

## Build on macOS 14+ (exact commands)

Requires Xcode and [create-dmg](https://github.com/create-dmg/create-dmg) (`brew install create-dmg`).

```bash
git clone https://github.com/tsdkanduev-coder/sled.git
cd sled

xcodebuild \
  -project Dayflow/Dayflow.xcodeproj \
  -scheme Dayflow \
  -configuration Release \
  -derivedDataPath build \
  MACOSX_DEPLOYMENT_TARGET=14.0 \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

# Optional unsigned DMG named Sled.dmg
create-dmg \
  --volname "Sled" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 100 \
  --app-drop-link 400 180 \
  --icon "Sled.app" 140 180 \
  "Sled.dmg" \
  "build/Build/Products/Release/Sled.app"
```

Helper script (same commands): `scripts/build_macos.sh`.

The Xcode scheme remains `Dayflow`; the shipped product name is **Sled** (`Sled.app`, bundle id `ru.kanduev.sled`).

Do not invent a `.dmg` on Linux. A GitHub Release with a binary is published only after a real Mac build.

## Verify

| Check | How |
| --- | --- |
| TCC | Grant Screen Recording; status must not stay on without permission |
| Recording status | Menu / Settings show `on` or `off` |
| Stop | Stop recording; `sled.sqlite` rows remain |
| SQLite path | `ls ~/Library/Application\ Support/Sled/sled.sqlite` |
| Loopback | `curl` example above; empty `[]` is success |
| Process down | Quit Sled; `curl` gets connection refused |
| Ollama | Stop Ollama; capture continues; summaries stay null; UI says install/start Ollama |
| Gatekeeper | Right-click → Open on an unsigned Mac build |

## License

MIT. Copyright for Sled modifications is 2026 Tsevdn Kanduev. Upstream Dayflow remains copyright Jerry Liu. See `LICENSE` and `NOTICE`.
