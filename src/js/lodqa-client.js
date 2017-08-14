const Loader = require('./loader/load-solution')
const BindResult = require('./controller/bind-result')
const bindSearchButton = require('./controller/bind-search-button')
const bindStopSearchButton = require('./controller/bind-stop-search-button')
const anchoredPgpTablePresentation = require('./presentation/anchored-pgp-table-presentation')
const answersPresentation = require('./presentation/answers-presentation')
const sparqlPresentation = require('./presentation/sparql-presentation')
const SparqlCount = require('./sparql-count')
const ProgressPresentation = require('./presentation/progress-presentation')

document.addEventListener('DOMContentLoaded', () => setTimeout(init, 150))

function init() {
  const loader = new Loader()
  const bindResult = new BindResult(loader.eventEmitter)
  const sparqlCount = new SparqlCount()
  const domId = 'lodqa-results'
  const progressPresentation = ProgressPresentation('lodqa-messages')

  bindResult({
    ws_open: [
      progressPresentation.show
    ],
    ws_close: [
      progressPresentation.hide
    ],
    sparql_count: [
      () => sparqlCount.reset(),
      progressPresentation.setTotal
    ],
    anchored_pgp: [
      (data) => anchoredPgpTablePresentation.showAnchoredPgp(domId, data),
      (data) => answersPresentation.setAnchoredPgp(domId, data)
    ],
    solution: [
      () => sparqlCount.increment(),
      (data) => sparqlPresentation.show(domId, data, sparqlCount.count),
      (data) => answersPresentation.showSolution(domId, data),
      progressPresentation.updateProgress
    ]
  })

  bindSearchButton(loader)
  bindStopSearchButton(loader)

  const checkbox = document.querySelector('#verbose')
  checkbox.addEventListener('change', (event) => sparqlPresentation.setVerbose(event.target.checked))
}
