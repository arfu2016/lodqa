const {
  EventEmitter
} = require('events')
const SparqlCount = require('./sparql-count')
const getUniqAnswers = require('./get-uniq-answers')
const addAnswersOfSparql = require('./add-answers-of-sparql')
const filterVisibleAnswers = require('./filter-visible-answers')
const bindModelToLoader = require('./bind-model-to-loader')
const findLabelOfAnswers = require('./find-label-of-answers')

module.exports = class Model extends EventEmitter {
  constructor(loader, findLabelOptions) {
    super()

    bindModelToLoader(loader, this)

    this.findLabelOptions = findLabelOptions
    this._sparqls = []
    this._sparqlCount = new SparqlCount()
    this._anchoredPgp = null
    this._solution = new Map()

    // The answers is a map that has url as key and answer as value.
    // The answer is an object that has a url, a label and an array of sparql.
    this._mergedAnswers = new Map()

    // The set of hide sparqls. This has only spraqlCount
    this._hideSparqls = new Set()
  }

  // SPARQL
  get sparqlCount() {
    return this._sparqlCount.count
  }

  get sparqlsMax() {
    return this._sparqls.length
  }

  // Return current status of SPARQLs
  get currentStatusOfSparqls() {
    return Array.from(Array(this.sparqlsMax))
      .map((val, index) => {
        const sparqlNumber = `${index + 1}`

        // SPARQLs with solutions
        if (this._solution.has(sparqlNumber)) {
          const {
            solution
          } = this.getSolution(sparqlNumber)
          const uniqAnswersLength = getUniqAnswers(solution.solutions, this.focus)
            .length
          const sparql_timeout = solution.spaqrl_timeout

          return {
            sparqlNumber,
            hasSolution: true,
            uniqAnswersLength,
            sparql_timeout
          }
        }

        // The next SPARQL is progress
        if (sparqlNumber === `${this.sparqlCount + 1}`) {
          return {
            sparqlNumber,
            hasSolution: false,
            isProgress: true
          }
        }

        return {
          sparqlNumber,
          hasSolution: false,
        }
      })
  }

  getSparql(sparqlCount) {
    return this._sparqls[sparqlCount - 1]
  }

  set sparqls(sparqls) {
    this._sparqls = sparqls
    this._sparqlCount.reset()

    this.emit('sparql_reset_event')
  }

  // AnchoerdPGP
  get anchoredPgp() {
    return this._anchoredPgp
  }

  set anchoredPgp(anchoredPgp) {
    this._anchoredPgp = anchoredPgp
    this.emit('anchored_pgp_reset_event')
  }

  // Solution
  get currentSolution() {
    return this.getSolution(this.sparqlCount)
      .solution
  }

  get currentUniqAnswersLength () {
    return getUniqAnswers(this.currentSolution.solutions, this.focus).length
  }

  getSolution(sparqlCount) {
    // Return solutions with anchoredPgp to show sparql detail in the serach page.
    return this._solution.get(sparqlCount.toString())
  }

  addSolution(solution) {
    this._sparqlCount.increment()
    this._solution.set(`${this.sparqlCount}`, {
      solution,
      anchoredPgp: this.anchoredPgp
    })

    this.emit('solution_add_event')

    const uniqAnswers = getUniqAnswers(this.currentSolution.solutions, this.focus)

    addAnswersOfSparql(
      this._mergedAnswers,
      uniqAnswers,
      this.sparqlCount
    )

    this.emit('answer_index_add_event')

    findLabelOfAnswers(this, this.findLabelOptions, (url, label) => this.updateLabel(url, label))
  }

  // isVerbose
  // Show SPARQLS without answers for debugging.
  get isVerbose() {
    return this._isVerbose
  }
  set isVerbose(newValue) {
    this._isVerbose = newValue
  }

  // Others
  get focus() {
    return this._anchoredPgp.focus
  }

  get answerIndex() {
    return filterVisibleAnswers(this._mergedAnswers, this._hideSparqls)
  }

  get labelAndUrls() {
    return this.answerIndex.map((s) => ({
      label: s.label,
      url: s.url
    }))
  }

  updateSparqlHideStatus(sparqlCount, isHide) {
    if (isHide) {
      this._hideSparqls.add(sparqlCount)
    } else {
      this._hideSparqls.delete(sparqlCount)
    }

    this.emit('answer_index_update_event')
  }

  updateLabel(url, label) {
    const answer = this._mergedAnswers.get(url)

    if (answer.labelFound !== label) {
      answer.label = label
      this.emit('label_update_event')
    }
  }
}
