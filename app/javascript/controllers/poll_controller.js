import { Controller } from "@hotwired/stimulus"

// Refreshes the page (morphing, keeps scroll) while background work is running.
export default class extends Controller {
  connect() {
    this.timer = setInterval(() => {
      if (window.protocoolRecording || document.activeElement?.matches("textarea, input[type=text]")) return
      Turbo.visit(location.href, { action: "replace" })
    }, 5000)
  }
  disconnect() { clearInterval(this.timer) }
}
