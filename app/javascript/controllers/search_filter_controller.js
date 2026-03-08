import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "spinner"]
  static values  = { delay: { type: Number, default: 400 } }

  connect() {
    this._timer = null
  }

  search() {
    clearTimeout(this._timer)
    this._showSpinner()
    this._timer = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  clear(event) {
    event.preventDefault()
    this.inputTarget.value = ""
    this.element.requestSubmit()
  }

  _showSpinner() {
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.remove("hidden")
  }

  hideSpinner() {
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.add("hidden")
  }
}
