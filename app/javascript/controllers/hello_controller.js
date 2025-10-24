import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]

  connect() {
    if (this.hasOutputTarget) {
      this.outputTarget.textContent = "Ready to monitor DNS changes."
    }
  }
}
