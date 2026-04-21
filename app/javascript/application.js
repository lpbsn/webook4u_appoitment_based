// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "admin_clients_wizard"

let shouldScrollPublicBookingFlow = false
const publicBookingScrollDuration = 520

function scrollToPublicBookingSection(targetTop) {
  const startTop = window.scrollY
  const distance = targetTop - startTop
  const startedAt = performance.now()

  function easeInOutCubic(progress) {
    return progress < 0.5
      ? 4 * progress * progress * progress
      : 1 - Math.pow(-2 * progress + 2, 3) / 2
  }

  function step(currentTime) {
    const elapsed = currentTime - startedAt
    const progress = Math.min(elapsed / publicBookingScrollDuration, 1)

    window.scrollTo(0, startTop + distance * easeInOutCubic(progress))

    if (progress < 1) {
      requestAnimationFrame(step)
    }
  }

  requestAnimationFrame(step)
}

document.addEventListener("turbo:submit-start", (event) => {
  const form = event.target

  if (!(form instanceof HTMLFormElement)) return
  if (!form.closest("#public_booking_flow")) return
  if (form.method.toLowerCase() !== "get") return

  shouldScrollPublicBookingFlow = true
})

document.addEventListener("turbo:frame-load", (event) => {
  const frame = event.target

  if (!(frame instanceof HTMLElement)) return
  if (frame.id !== "public_booking_flow") return
  if (!shouldScrollPublicBookingFlow) return

  shouldScrollPublicBookingFlow = false

  requestAnimationFrame(() => {
    const sections = frame.querySelectorAll(".booking-layout-steps > .booking-section")
    const target = sections[sections.length - 1]

    if (!target) return

    const targetTop = target.getBoundingClientRect().top + window.scrollY - 24

    scrollToPublicBookingSection(Math.max(targetTop, 0))
  })
})
