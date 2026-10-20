import { Controller } from "@hotwired/stimulus"

// Records the meeting in the browser and streams it to the server in 5-second
// chunks, so a closed tab or dead battery loses at most a few seconds.
export default class extends Controller {
  static targets = ["button", "label", "time", "meter", "status", "finishBox", "speakers"]
  static values = { createUrl: String }

  disconnect() { if (this.recorder?.state === "recording") this.stop() }

  toggle() { this.recorder?.state === "recording" ? this.stop() : this.start() }

  async start() {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: false, noiseSuppression: true, autoGainControl: true, channelCount: 1 } })
    } catch (e) {
      this.say("אין גישה למיקרופון: " + e.message)
      return
    }
    const mimeType = ["audio/webm;codecs=opus", "audio/webm", "audio/mp4", "audio/ogg;codecs=opus"].find((t) => MediaRecorder.isTypeSupported(t)) || ""
    const res = await this.post(this.createUrlValue, { mime_type: mimeType })
    if (!res.ok) { this.say("שגיאה ביצירת ההקלטה"); this.stream.getTracks().forEach((t) => t.stop()); return }
    const { chunk_url, finish_url } = await res.json()
    this.chunkUrl = chunk_url; this.finishUrl = finish_url
    this.queue = []; this.seq = 0; this.uploading = false; this.failed = 0

    this.recorder = new MediaRecorder(this.stream, mimeType ? { mimeType, audioBitsPerSecond: 64000 } : undefined)
    this.recorder.ondataavailable = (e) => { if (e.data.size) { this.queue.push(e.data); this.pump() } }
    this.recorder.onstop = () => this.pump()
    this.recorder.start(5000)

    window.protocoolRecording = true
    this.startedAt = Date.now()
    this.element.classList.add("on")
    this.labelTarget.textContent = "Stop"
    this.finishBoxTarget.hidden = true
    this.say("מקליט… השאירי את המסך פתוח. אפשר לעצור בכל רגע.")
    this.tick = setInterval(() => this.renderTime(), 500)
    this.meter()
    this.lockScreen()
    this.beforeUnload = (e) => { e.preventDefault(); e.returnValue = "" }
    window.addEventListener("beforeunload", this.beforeUnload)
  }

  async stop() {
    this.recorder.stop()
    this.stream.getTracks().forEach((t) => t.stop())
    clearInterval(this.tick)
    cancelAnimationFrame(this.raf)
    this.audioCtx?.close()
    this.wakeLock?.release().catch(() => {})
    this.element.classList.remove("on")
    this.labelTarget.textContent = "Record"
    this.meterTarget.style.width = "0"
    this.say("שומר את סוף ההקלטה…")
    await new Promise((r) => setTimeout(r, 300))
    while (this.queue.length || this.uploading) await new Promise((r) => setTimeout(r, 300))
    window.protocoolRecording = false
    window.removeEventListener("beforeunload", this.beforeUnload)
    this.say("ההקלטה נשמרה. לחצי \"תמלול\" כדי לתמלל ולהפריד בין הדוברים.")
    this.finishBoxTarget.hidden = false
  }

  async finish() {
    const res = await this.post(this.finishUrl, { num_speakers: this.speakersTarget.value }, "application/json")
    const { url } = await res.json()
    window.Turbo ? Turbo.visit(url, { action: "replace" }) : (location.href = url)
  }

  async pump() {
    if (this.uploading) return
    this.uploading = true
    while (this.queue.length) {
      const blob = this.queue[0]
      try {
        const res = await fetch(`${this.chunkUrl}?seq=${this.seq}`, { method: "POST", body: blob, headers: { "Content-Type": "application/octet-stream" } })
        if (!res.ok) throw new Error(res.status)
        this.queue.shift(); this.seq++; this.failed = 0
      } catch (e) {
        this.failed++
        this.say(`בעיית רשת – ממשיך להקליט ומנסה שוב (${this.queue.length} קטעים ממתינים)`)
        await new Promise((r) => setTimeout(r, Math.min(10000, 1000 * this.failed)))
      }
    }
    this.uploading = false
  }

  renderTime() {
    const s = Math.floor((Date.now() - this.startedAt) / 1000)
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = String(s % 60).padStart(2, "0")
    this.timeTarget.textContent = h ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`
  }

  meter() {
    this.audioCtx = new AudioContext()
    const analyser = this.audioCtx.createAnalyser()
    analyser.fftSize = 512
    this.audioCtx.createMediaStreamSource(this.stream).connect(analyser)
    const data = new Uint8Array(analyser.fftSize)
    const loop = () => {
      analyser.getByteTimeDomainData(data)
      let peak = 0
      for (const v of data) peak = Math.max(peak, Math.abs(v - 128))
      this.meterTarget.style.width = Math.min(100, (peak / 128) * 160) + "%"
      this.raf = requestAnimationFrame(loop)
    }
    loop()
  }

  async lockScreen() {
    try { this.wakeLock = await navigator.wakeLock?.request("screen") } catch {}
  }

  say(text) { this.statusTarget.textContent = text }

  post(url, data, accept = "application/json") {
    const body = new FormData()
    Object.entries(data).forEach(([k, v]) => body.append(k, v ?? ""))
    return fetch(url, { method: "POST", body, headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content, Accept: accept } })
  }
}
