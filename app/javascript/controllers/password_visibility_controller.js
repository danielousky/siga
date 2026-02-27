import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "icon"]

  toggle() {
    const shouldShow = this.inputTarget.type === "password"

    this.inputTarget.type = shouldShow ? "text" : "password"

    this.iconTarget.classList.toggle("fa-eye", !shouldShow)
    this.iconTarget.classList.toggle("fa-eye-slash", shouldShow)

    this.buttonTarget.setAttribute("aria-label", shouldShow ? "Ocultar contraseña" : "Mostrar contraseña")
    this.buttonTarget.setAttribute("aria-pressed", shouldShow ? "true" : "false")
  }
}
