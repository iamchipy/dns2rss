import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form"]

  toggleEdit(event) {
    event.preventDefault()
    this.switchState()
  }

  cancel(event) {
    event.preventDefault()

    if (this.hasFormTarget) {
      const form = this.formTarget.querySelector("form")
      if (form) form.reset()
    }

    this.switchState()
  }

  switchState() {
    if (!this.hasFormTarget) return

    this.displayTarget.classList.toggle("hidden")
    this.formTarget.classList.toggle("hidden")
  }
}
