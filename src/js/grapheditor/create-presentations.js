const LoadingPresentation = require('../presentation/loading-presentation')
const AnchoredPgpTablePresentation = require('../presentation/anchored-pgp-table-presentation')
const AnswersPresentation = require('../presentation/answers-presentation')
const SparqlPresentation = require('../presentation/sparql-presentation')
const ProgressBarPresentation = require('../presentation/progress-bar-presentation')

module.exports = function(resultDomId, progressDomId, model) {
  new AnchoredPgpTablePresentation(resultDomId, model)
  new SparqlPresentation(resultDomId, model)
  new AnswersPresentation(resultDomId, model)
  new LoadingPresentation(progressDomId, model)
  new ProgressBarPresentation(document.querySelector('#progress-bar'), model)
}
