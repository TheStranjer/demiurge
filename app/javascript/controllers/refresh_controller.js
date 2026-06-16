import { Controller } from "@hotwired/stimulus"

// Counts down from `seconds` to zero, updating the countdown target each
// second, then reloads the scene so a pending event's latest status shows.
// The cycle repeats after each reload until nothing is pending.
export default class extends Controller {
  static targets = ["countdown"]
  static values = { seconds: { type: Number, default: 10 } }

  connect() {
    this.remaining = this.secondsValue
    this.render()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    this.clear()
  }

  tick() {
    this.remaining -= 1

    if (this.remaining <= 0) {
      this.clear()
      this.reload()
      return
    }

    this.render()
  }

  render() {
    if (this.hasCountdownTarget) {
      this.countdownTarget.textContent = this.remaining
    }
  }

  reload() {
    if (window.Turbo) {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  }

  clear() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }
}
