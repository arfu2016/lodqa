const updateDisplay = require('./update-display')
const Pagenation = require('./Pagenation')

module.exports = class {
  constructor(dom, model) {
    this._dom = dom
    this._pagination = new Pagenation(16)

    this._dom
      .addEventListener('click', (e) => {
        if (e.target.name === 'prev') {
          this.prev()
        }
        if (e.target.name === 'next') {
          this.next()
        }
      })

    model.on('answer_index_add_event', () => this.updateDisplay(model.answerIndex))
    model.on('answer_index_update_event', () => this.updateDisplay(model.answerIndex))
    model.on('label_update_event', () => this.updateDisplay(model.answerIndex))
  }

  updateDisplay(answers) {
    this.answers = answers
    this._pagination.items = answers

    updateDisplay(this._dom, this._pagination.dump)
  }

  prev() {
    if (this._pagination.goPrev()) {
      updateDisplay(this._dom, this._pagination.dump)
    }
  }

  next() {
    if (this._pagination.goNext()) {
      updateDisplay(this._dom, this._pagination.dump)
    }
  }
}
