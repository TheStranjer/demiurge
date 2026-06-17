import { Controller } from "@hotwired/stimulus"

// Periodically pulls the scene's latest state over AJAX and swaps just the
// live region into the DOM — no full-page reload. While an event is pending
// the server renders a countdown; the controller fetches the scene, replaces
// this element's contents with the fresh live region, and keeps polling. Once
// nothing is pending the countdown is gone, so polling stops on its own.
export default class extends Controller {
  static values = { seconds: { type: Number, default: 10 } }

  connect() {
    this.start()
  }

  disconnect() {
    this.clear()
  }

  // Begin a countdown only while the server says we are still waiting, which
  // it signals by rendering the countdown element inside the live region.
  start() {
    this.countdown = this.element.querySelector(".scene-refresh-countdown")
    if (!this.countdown) return

    this.remaining = this.secondsValue
    this.render()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  tick() {
    this.remaining -= 1

    if (this.remaining <= 0) {
      this.clear()
      this.refresh()
      return
    }

    this.render()
  }

  render() {
    if (this.countdown) {
      this.countdown.textContent = this.remaining
    }
  }

  async refresh() {
    try {
      const response = await fetch(window.location.href, {
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" }
      })

      if (response.ok) {
        const html = await response.text()
        const doc = new DOMParser().parseFromString(html, "text/html")
        const fresh = doc.getElementById(this.element.id)
        if (fresh) {
          this.element.innerHTML = fresh.innerHTML
        }
      }
    } finally {
      this.start()
    }
  }

  clear() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }
}
