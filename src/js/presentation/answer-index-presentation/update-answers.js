module.exports = function(answers, uniqAnswers, sparqlCount, sparql) {
  uniqAnswers
    .map(
      (answer) => (
        Object.assign({
          sparqls: [{
            name: `S${sparqlCount}`,
            sparql: sparql
          }]
        }, answer)))
    .reduce((map, answer) => {
      if (!map.has(answer.url)) {
        map.set(answer.url, answer)
      } else {
        const existAnswer = map.get(answer.url)
        existAnswer.sparqls = existAnswer.sparqls.concat(answer.sparqls)
      }

      return map
    }, answers)
}
