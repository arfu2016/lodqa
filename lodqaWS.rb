#!/usr/bin/env ruby
#encoding: UTF-8

## configuration file processing
require 'parseconfig'
config         = ParseConfig.new('./lodqa.cfg')
endpoint       = config['endpointURL']
apikey         = config['apikey']
enju_url       = config['enjuURL']
ontofinder_url = config['ontofinderURL']
query          = config['testQuery']


## initialize query parser
require './lodqa'
qp = QueryParser.new(enju_url, ontofinder_url)


## web service
require 'sinatra'
require 'erb'


get '/' do
	erb :index
end


post '/query' do
	query = params['query']
	qp.parse(query)

	vid   = params['vid']
	@oname = params['oname']	# ontology name (acronym)
	@endpoint = endpoint
	@apikey   = apikey
	@psparql  = qp.get_psparql
	@texps    = qp.get_texps
	@turis    = qp.find_term_uris(vid)
	@sparql   = qp.get_sparql(vid, @oname)
	@atext    = qp.get_query_with_bncs
	@terms    = qp.get_bncs
	#sparql.gsub!('<', '&lt;')
	erb :results
end