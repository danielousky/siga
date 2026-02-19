import { Controller } from "@hotwired/stimulus"

// Controlador para el carrusel de beneficios en la landing page
export default class extends Controller {
  static targets = ["slide", "dot"]

  connect() {
    this.currentIndex = 0
    this.showSlide(0)
    this.startAutoplay()
  }

  disconnect() {
    this.stopAutoplay()
  }

  startAutoplay() {
    this.autoplayInterval = setInterval(() => {
      this.next()
    }, 5000) // Cambia cada 5 segundos
  }

  stopAutoplay() {
    if (this.autoplayInterval) {
      clearInterval(this.autoplayInterval)
    }
  }

  next() {
    this.currentIndex = (this.currentIndex + 1) % this.slideTargets.length
    this.showSlide(this.currentIndex)
  }

  goToSlide(event) {
    const index = parseInt(event.currentTarget.dataset.slide)
    this.currentIndex = index
    this.showSlide(index)

    // Reiniciar autoplay cuando el usuario interactúa
    this.stopAutoplay()
    this.startAutoplay()
  }

  showSlide(index) {
    // Ocultar todos los slides
    this.slideTargets.forEach(slide => {
      slide.classList.remove("active")
    })

    // Desactivar todos los dots
    this.dotTargets.forEach(dot => {
      dot.classList.remove("active")
    })

    // Mostrar el slide actual
    this.slideTargets[index].classList.add("active")
    this.dotTargets[index].classList.add("active")
  }
}
