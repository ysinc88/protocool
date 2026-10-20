# Protocool

*It writes the protocol so you don't have to. Stay cool.*

A self-hosted assistant for small volunteer committees (school/education committees, neighbourhood boards, PTA). It runs on one always-on computer and takes care of everything around the meeting:

1. **Reminders**: N days before every meeting (default 2) each member gets an e-mail with the meeting details, the previous meeting's protocol, their open tasks, **✓ coming / ✗ not coming** buttons, and a request to reply with agenda topics.
2. **Replies → RSVPs + agenda**: the committee Gmail inbox is read every 10 minutes. Claude reads each reply, records attendance (yes / no / maybe + a note such as "I'll be late") and pulls out the proposed agenda topics.
3. **Record button**: record the meeting from a phone or laptop browser. Audio streams to the server in 5-second chunks, so a closed tab or dead battery loses at most a few seconds.
4. **Local transcription with speaker separation**: whisper.cpp (ivrit.ai Hebrew Whisper large-v3) plus sherpa-onnx diarization. Everything runs on your own machine; no audio leaves it. You then name the speakers by clicking sample quotes.
5. **Protocol → tasks + community letter**: paste, upload (.docx / .pdf / .txt) or use the transcript. Claude writes a clean protocol, the decisions, concrete tasks per member with due dates, and a short letter to the community. You review and edit, then one click e-mails each member their tasks and another sends the letter.

The UI, e-mails and prompts are in **Hebrew (RTL)**, and the default speech model is Hebrew. For other languages see [Adapting to another language](#adapting-to-another-language).

Reminders never go out on Shabbat. One that would fall on a Saturday goes out on Friday instead, and catch-up sends wait until Saturday night. Set `PROTOCOOL_OBSERVE_SHABBAT=false` to turn this off.

---

## For AI agents installing this

Do the steps in [Installation](#installation) in order and run every verification command. The only things you need from the human are:

1. **A Gmail address and a Gmail App Password** for the committee. Walk them through [Getting a Gmail App Password](#getting-a-gmail-app-password); it takes 2 minutes. Never ask for their normal Google password.
2. **That the `claude` CLI is logged in** on this machine (`claude` → `/login`), or an `ANTHROPIC_API_KEY`.
3. **The committee details**: committee name, settlement/organisation name, chair's name (used to sign e-mails), and members' names and e-mails. These are entered in the web UI, or you can add them for the human (see [First run](#first-run)).
4. **How they will reach the web UI** from their phone: the same machine, the LAN, or Tailscale. See [Network access](#network-access). Do not expose it to the public internet without adding authentication. The app has **no login**.

Do not send test e-mails to real members without asking. Use the committee's own address for tests.

---

## Hardware

| | Minimum | Recommended |
|---|---|---|
| **Machine** | Any always-on Linux or macOS box (desktop, mini-PC, home server) | Desktop or mini-PC that stays on and logged in |
| **CPU** | 4 cores x86-64 / Apple Silicon | 8+ cores (diarization runs on CPU) |
| **RAM** | 8 GB | 16 GB |
| **GPU** | none (CPU works but is slow) | **≥ 4 GB VRAM** with Vulkan (NVIDIA GTX 1060 6 GB or newer, AMD RX 580 or newer, Intel Arc), or any Apple Silicon Mac (Metal) |
| **Disk** | 10 GB free (models ≈ 5 GB) | SSD, plus ~30 MB per recorded hour |
| **Microphone** | the phone that records | a USB/Bluetooth conference speakerphone in the middle of the table |

Measured transcription speed for a meeting recording (diarization + transcription):

| Hardware | Speed | 90-minute meeting |
|---|---|---|
| GTX 1070 8 GB, i7-7700 | ≈ 0.3-0.45× real time | ~30-40 min |
| CPU only, 8 cores | ≈ 1.5-3× real time (estimate) | 2-4 h |

GPU memory: the full model needs about 3.5 GB free VRAM. The 8-bit copy needs about 2 GB. Protocool tries **full model on GPU → 8-bit on GPU → 8-bit on CPU** automatically, so other GPU users (games, local LLMs, TTS) only slow it down.

The machine must be on and the service running at reminder time and while the inbox is polled. A sleeping laptop will send late reminders: missed reminders go out when it wakes, if the meeting hasn't happened yet.

---

## Requirements

| Software | Why | Notes |
|---|---|---|
| Ruby **4.0.x** (see `.ruby-version`) | the app (Rails 8.1) | via mise, rbenv, asdf or a package manager |
| SQLite 3 | database | usually preinstalled |
| ffmpeg + ffprobe | audio conversion | |
| poppler (`pdftotext`), `unzip` | reading uploaded PDF / Word protocols | |
| git, cmake, C++ compiler, curl, bzip2 | `bin/setup-ml` builds whisper.cpp | |
| Vulkan headers + `glslc` (Linux GPU only) | GPU build of whisper.cpp | Arch: `vulkan-headers spirv-headers shaderc`; Debian/Ubuntu: `libvulkan-dev glslc spirv-headers`; Fedora: `vulkan-headers vulkan-loader-devel glslc spirv-headers-devel`; plus a working Vulkan driver (`vulkaninfo --summary` lists your GPU) |
| **Claude Code CLI** (`claude`) | writes protocols, reads replies | `npm i -g @anthropic-ai/claude-code` (or the native installer), then log in with a Claude Pro/Max subscription, **or** export `ANTHROPIC_API_KEY` (pay per use, roughly a few cents per meeting) |
| A **Gmail** account + App Password | sends mail (SMTP) and reads replies (IMAP) | a dedicated committee account is strongly recommended |

Package one-liners:

```sh
# Arch / Manjaro / Omarchy
sudo pacman -S --needed ruby sqlite ffmpeg poppler unzip git cmake base-devel curl bzip2 vulkan-headers spirv-headers shaderc
# Debian / Ubuntu
sudo apt install -y sqlite3 libsqlite3-dev ffmpeg poppler-utils unzip git cmake build-essential curl bzip2 libyaml-dev libvulkan-dev glslc spirv-headers
# macOS (Homebrew)
brew install sqlite ffmpeg poppler cmake
```

Install Ruby 4.0 with your version manager (e.g. `mise use ruby@4.0`). Distro Ruby packages are usually too old.

---

## Installation

```sh
git clone <this repo> protocool && cd protocool

# 1. Ruby gems + database
bundle install
bin/rails db:prepare

# 2. Speech stack (whisper.cpp + Hebrew model + diarization) → ~/.local/share/protocool
bin/setup-ml            # add --cpu to force a CPU-only build
#    Downloads ~3.2 GB and builds whisper.cpp (a few minutes; GPU shaders take longest).
#    Ends with a smoke test that prints "And so my fellow Americans..." and diarization lines.

# 3. Claude CLI must work non-interactively:
echo 'Reply with the JSON {"ok":true}' | claude -p --output-format json | grep -q '"is_error":false' && echo CLAUDE OK

# 4. Run it
SOLID_QUEUE_IN_PUMA=1 bin/rails server -p 3109 -b 127.0.0.1
#    → http://127.0.0.1:3109
```

`SOLID_QUEUE_IN_PUMA=1` runs the background jobs (reminders, inbox polling, transcription, Claude) inside the web server. **Without it nothing gets sent.** Alternatively run `bin/jobs` as a second process.

### Run as a service (Linux, recommended)

```sh
mkdir -p ~/.config/systemd/user
sed "s|__APP__|$PWD|g; s|__PATH__|$PATH|" deploy/protocool.service > ~/.config/systemd/user/protocool.service
systemctl --user daemon-reload && systemctl --user enable --now protocool
sudo loginctl enable-linger "$USER"     # start at boot, keep running after logout
systemctl --user status protocool
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3109/up     # → 200
```

The `PATH` baked into the unit must contain `ruby`/`bundle`, `claude`, `ffmpeg` and `pdftotext`. If you use mise, put its shims directory first (`~/.local/share/mise/shims`).

On macOS use a `launchd` agent with the same command and environment, or just keep it running in a terminal.

### Network access

Recording needs **HTTPS** (browsers only allow the microphone on secure origins), except on `localhost`.

- **Tailscale (recommended)**: `sudo tailscale serve --bg --https=3109 http://127.0.0.1:3109`, then open `https://<machine>.<tailnet>.ts.net:3109/` on any of your devices. Add that hostname to `PROTOCOOL_HOSTS`.
- **LAN with your own TLS reverse proxy** (Caddy, nginx): proxy to `127.0.0.1:3109` and set `PROTOCOOL_HOSTS`.
- **Do not** use Tailscale Funnel, port forwarding or any other public exposure. The app has no authentication, and anyone who reaches it can read protocols and send e-mail as the committee.

Committee members never need access. They only receive e-mail and reply to it.

---

## Getting a Gmail App Password

Protocool logs in to Gmail with an **App Password**: a 16-character password that only works for mail apps and can be revoked any time. Your normal Google password is never used.

**Use a dedicated committee account** (e.g. `ourcommittee@gmail.com`). Replies from members land there, and Protocool only reads messages whose subject contains `[VC-<number>]`.

1. **Sign in** to the committee Google account in a browser.
2. **Turn on 2-Step Verification** (required for App Passwords): open <https://myaccount.google.com/signinoptions/twosv>, click *Turn on* and follow the steps (a phone number is enough).
3. **Create the App Password**: open <https://myaccount.google.com/apppasswords>.
   - App name: `Protocool` → **Create**.
   - Google shows a 16-letter password like `abcd efgh ijkl mnop`. **Copy it now**; it is shown only once. Spaces don't matter.
4. **Enter it in Protocool**: *הגדרות* (Settings) → *חשבון Gmail*: the Gmail address and the App Password → save → **שליחת מייל בדיקה אליי** (send me a test e-mail). The test mail should arrive in the committee inbox within seconds.
5. IMAP is always on for personal Gmail accounts. On a **Google Workspace** account the admin must allow IMAP and App Passwords.

If <https://myaccount.google.com/apppasswords> says *"The setting you are looking for is not available for your account"*, then one of these applies:
- 2-Step Verification is not on yet (do step 2 first);
- the account uses only security keys / Advanced Protection;
- it's a Workspace account whose admin disabled App Passwords.

Troubleshooting:

| Error | Fix |
|---|---|
| `535 Username and Password not accepted` | wrong address or App Password; create a new one |
| `534 … Application-specific password required` | you entered the normal password; use the App Password |
| App Password stopped working | it is revoked automatically when the Google account password changes; create a new one |

To revoke access later, delete the *Protocool* entry at <https://myaccount.google.com/apppasswords>.

The App Password is stored **encrypted** in the database. The key is in `storage/encryption.json`, generated on first boot. Back up `storage/` as a whole, since the database is useless without that key.

---

## First run

In the web UI:

1. **הגדרות (Settings)**:
   - committee name, settlement/organisation, chair's name (signs the e-mails), usual meeting place;
   - reminder days before (default 2) and hour (default 9:00);
   - Gmail + App Password, then send a test e-mail;
   - optionally a community mailing-list address for the letter. Leave it empty to copy the letter into WhatsApp or a newsletter instead.
2. **חברי ועדה (Members)**: name + e-mail for each member.
3. **פגישה חדשה (New meeting)**: date, time, place, draft agenda. The reminder time is shown right away.
4. Open the meeting page and click **תצוגה מקדימה של התזכורת** to preview exactly what members will receive.

An agent can add members from the shell instead:

```sh
bin/rails runner 'Member.create!(name: "Dana Cohen", email: "dana@example.com")'
```

### At the meeting

1. Open the meeting page on the device that records. Keep it charged and the tab in front; the page asks the browser to keep the screen on.
2. Press **Record**, then **Stop** at the end. Type how many people spoke (it helps diarization a lot) and press **תמלול**.
3. When it's done, open the transcript, name each speaker (click ▶ on a sample to hear it), then press **שימוש בתמלול כפרוטוקול ועיבוד**.
4. Review the protocol, tasks (assignees, due dates) and the letter. Edit anything, then send the tasks and the letter.

**Do a 10-second test recording on that device before the first real meeting.**

---

## How it works

```
Browser ──5 s audio chunks──▶ storage/recordings/<id>.webm
                                   │  TranscribeJob (queue "heavy", one at a time)
                                   ▼
            ffmpeg → 16 kHz wav ─┬─▶ sherpa-onnx: who spoke when (pyannote segmentation + CAM++ embeddings, CPU)
                                 └─▶ whisper.cpp: ivrit.ai large-v3, word timestamps (GPU, fallback 8-bit / CPU)
                                   ▼  each word → speaker active at its midpoint → speaker turns
                               Recording#segments ──▶ protocol text
                                   │  ProcessProtocolJob → `claude -p --json-schema` (Opus)
                                   ▼
                     summary · decisions · tasks per member · community letter
```

| Recurring job | Schedule | Does |
|---|---|---|
| `SendRemindersJob` | every 15 min | sends due reminders (skips Shabbat, see above) |
| `PollInboxJob` | every 10 min | IMAP search `SUBJECT "VC-"`, last 30 days; Claude (Haiku) reads RSVP + topics; each message processed once |

Code map:
- `app/services/transcriber.rb`: the speech pipeline;
- `inbox_poller.rb` + `topic_extractor.rb`: reading replies;
- `protocol_processor.rb`: the protocol prompt and JSON schema;
- `claude_client.rb`: the wrapper around `claude -p`;
- `app/mailers/committee_mailer.rb`: all outgoing mail (CSS is inlined by premailer so Gmail keeps RTL);
- `config/recurring.yml`: the job schedules.

Claude runs as `claude -p --tools "" --no-session-persistence --strict-mcp-config --setting-sources ""`, so it has no tools and no access to files. It only sees the text it is given. Its working directory is `storage/claude`.

---

## Configuration (environment variables)

| Variable | Default | |
|---|---|---|
| `SOLID_QUEUE_IN_PUMA` | unset | set to `1` to run jobs inside the server (**required** unless you run `bin/jobs`) |
| `PROTOCOOL_HOSTS` | | comma-separated hostnames the UI is reached by (Rails host authorization) |
| `PROTOCOOL_ML_DIR` | `~/.local/share/protocool` | where `bin/setup-ml` installs things |
| `PROTOCOOL_WHISPER`, `PROTOCOOL_WHISPER_MODEL`, `PROTOCOOL_WHISPER_MODEL_Q8` | under `PROTOCOOL_ML_DIR` | override binary / model paths |
| `PROTOCOOL_LANGUAGE` | `he` | whisper language code |
| `PROTOCOOL_VK_DEVICE` | unset | Vulkan device index; set it when an integrated GPU is listed first (`vulkaninfo --summary`), e.g. `1` |
| `PROTOCOOL_TIME_ZONE` | `Jerusalem` | Rails time-zone name, used for reminder times |
| `PROTOCOOL_OBSERVE_SHABBAT` | `true` | `false` to send reminders on Saturdays |
| `PROTOCOOL_MODEL_URL` | ivrit.ai ggml large-v3 | model used by `bin/setup-ml` |
| `PROTOCOOL_WHISPER_CMAKE_FLAGS` | | extra cmake flags, e.g. `-DGGML_CUDA=1` for a CUDA build |
| `CLAUDE_BIN` | `claude` | path to the Claude Code CLI |
| `ANTHROPIC_API_KEY` | | use the API instead of a logged-in subscription |

---

## Adapting to another language

1. Set `PROTOCOOL_LANGUAGE` (e.g. `en`) and `PROTOCOOL_MODEL_URL` to a ggml Whisper model for that language (e.g. `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin`), then re-run `bin/setup-ml`. Delete the old files in `$PROTOCOOL_ML_DIR/models` first.
2. Translate the UI strings in `app/views/**`, the e-mail templates in `app/views/committee_mailer/`, and the prompts in `app/services/protocol_processor.rb` and `topic_extractor.rb`. Claude writes in the language of the prompt.
3. Change `dir="rtl"` / `lang="he"` in `app/views/layouts/*.html.erb` and the mail CSS.
4. The reply-quote markers in `inbox_poller.rb` (`On … wrote:`) already cover English and Hebrew Gmail.

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Nothing is sent | jobs not running: is `SOLID_QUEUE_IN_PUMA=1` set? `log/development.log` and `log/jobs.log`; failed jobs: `sqlite3 storage/development_queue.sqlite3 'select error from solid_queue_failed_executions'` |
| Reminder didn't go out | Settings → Gmail configured? Members marked active? The meeting page shows the scheduled reminder time; there's also a *send now* button |
| Replies not picked up | the reply subject must still contain `[VC-<id>]`; Settings → *בדיקת תשובות בתיבה עכשיו* forces a poll |
| Transcription failed: `ErrorOutOfDeviceMemory` | another program holds the GPU; Protocool falls back to 8-bit / CPU automatically, so check that `ggml-ivrit-large-v3-q8_0.bin` exists |
| Transcription very slow | CPU build? `bin/setup-ml` prints which GPU backend it used; on dual-GPU machines set `PROTOCOOL_VK_DEVICE` |
| Too many / too few speakers | enter the number of speakers and press *תמלול מחדש* on the transcript page |
| Record button does nothing | the page must be HTTPS (or localhost) and the browser must be allowed to use the microphone |
| Claude step fails | run the `claude -p` check from Installation as the **same user and PATH** as the service |
| `Blocked hosts` error page | add the hostname to `PROTOCOOL_HOSTS` |

---

## Privacy

- Audio and transcripts stay on the machine (`storage/recordings`, `storage/*.sqlite3`).
- Protocol text, member names and e-mail replies are sent to Anthropic's API through Claude Code, to be summarised.
- E-mail goes through the committee's Gmail account.
- Tell committee members that meetings are recorded, and delete recordings when they're no longer needed (✕ on the meeting page).

## License

Public domain ([The Unlicense](LICENSE)): do whatever you want.

Third-party pieces keep their own licenses:
- whisper.cpp: MIT;
- sherpa-onnx: Apache-2.0;
- ivrit.ai models: see their Hugging Face page;
- pyannote segmentation: MIT;
- 3D-Speaker CAM++: Apache-2.0.
