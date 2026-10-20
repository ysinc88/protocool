import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }
  async copy() {
    const field = document.querySelector("#letter textarea")
    await navigator.clipboard.writeText(field?.value || this.textValue)
    const old = this.element.textContent
    this.element.textContent = "✓ הועתק"
    setTimeout(() => (this.element.textContent = old), 1500)
  }
}
