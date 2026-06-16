import { Controller } from "@hotwired/stimulus"

// Drives the Game Master's adjudication form: add roll tables from scratch, fork an
// existing table into an editable copy, and add/remove individual result rows. Server-
// rendered blocks use real indices; new blocks substitute the __INDEX__/__ROW__ placeholders
// so each input name stays unique.
export default class extends Controller {
  static targets = ["list", "template"]
  static values = { nextIndex: Number }

  addBlank() {
    const index = this.nextIndexValue
    this.nextIndexValue = index + 1
    const html = this.templateTarget.innerHTML.replaceAll("__INDEX__", index)
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  removeBlock(event) {
    event.target.closest(".table-block").remove()
  }

  addRow(event) {
    const block = event.target.closest(".table-block")
    const template = block.querySelector("template.row-template")
    const row = parseInt(block.dataset.rowNext || "0", 10)
    const html = template.innerHTML.replaceAll("__ROW__", row)
    block.querySelector(".result-rows").insertAdjacentHTML("beforeend", html)
    block.dataset.rowNext = row + 1
  }

  removeRow(event) {
    event.target.closest(".result-row").remove()
  }

  customize(event) {
    const wrapper = event.target.closest(".table-existing")
    wrapper.querySelector(".table-existing-include").checked = false
    wrapper.querySelector(".table-existing-head").hidden = true
    const fork = wrapper.querySelector(".table-fork")
    fork.hidden = false
    fork.querySelector(".table-block-include").checked = true
  }
}
