const Loader = require('./loader')
const Model = require('./model')
const beginSearch = require('./answer/begin-search')
const bindHandlerForKeyEvents = require('./answer/bind-handler-for-key-events')
const bindHandlerToShowSparql = require('./answer/bind-handler-to-show-sparql')
const createPresentations = require('./answer/create-presentations')
const bindModeButtonEventhandler = require('./controller/bind-mode-button-eventhandler')


for (const parent of document.querySelectorAll('.answers-for-dataset')) {
  const name = parent.getAttribute('data-dataset')
  const loader = new Loader()
  const model = new Model(loader, {
    endpointUrl: parent.querySelector('.answers-for-dataset__endpoint-url')
      .value,
    needProxy: parent.querySelector('.answers-for-dataset__need-proxy')
      .value === 'true'
  })

  bindHandlerForKeyEvents(loader)

  bindHandlerToShowSparql(parent, ['.answers-for-dataset__progress-bar', '.answers-for-dataset__answer-index'], 'lightbox', model, loader)

  createPresentations(model, parent, {
    answerIndexDomSelector: '.answers-for-dataset__answer-index',
    downloadJsonButtonSelector: '.answers-for-dataset__download-json-button',
    downloadTsvButtonSelector: '.answers-for-dataset__download-tsv-button',
    progressBarSelector: '.answers-for-dataset__progress-bar'
  }, name)

  loader.on('error', (data) => console.error(data))

  beginSearch(loader, 'pgp', parent, '.answers-for-dataset__mappings', name, 'read_timeout')

  bindModeButtonEventhandler('grapheditor')
}
