import { Controller } from "@hotwired/stimulus"

// Dropdown of member checkboxes: keeps the summary in sync and closes on an outside click.
export default class extends Controller {
  static targets = ["label"]
  static values = { placeholder: String }

  connect() {
    this.close = (e) => { if (!this.element.contains(e.target)) this.element.open = false }
    document.addEventListener("click", this.close)
  }
  disconnect() { document.removeEventListener("click", this.close) }

  update() {
    const names = [...this.element.querySelectorAll("input[type=checkbox]:checked")].map(c => c.nextElementSibling.textContent.trim())
    this.labelTarget.textContent = names.join(", ") || this.placeholderValue
  }
}
