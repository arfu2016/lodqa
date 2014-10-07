#!/usr/bin/env ruby
require 'net/http'
require 'sparql/client'
require 'json'
require 'enju_access/enju_access'
require 'graph_finder/graph_finder'
require 'lodqa/dictionary'

module Lodqa; end unless defined? Lodqa

class Lodqa::Lodqa
  attr_reader :parse
  attr_reader :pgp
  attr_reader :terms

  def initialize(query, parser_url, dictionary_url, ep_url, options = {})
    @options = options || {}
    @debug = @options[:debug] || false

    parser = EnjuAccess::CGIAccessor.new(parser_url)
    parse  = parser.parse(query)
    @pgp   = graphicate(parse)

    @endpoint = SPARQL::Client.new(ep_url, @options[:endpoint_options] || {})

    dictionary = Lodqa::Dictionary.new(dictionary_url, @endpoint)
    mappings   = dictionary.lookup(@pgp[:nodes].values.collect{|n| n[:text]})
    terms      = @pgp[:nodes].values.map{|n| mappings[n[:text]]}

    @anchored_pgps = terms.first.product(*terms.drop(1)).collect do |ts|
      anchored_pgp = pgp.dup
      anchored_pgp[:nodes] = pgp[:nodes].dup
      anchored_pgp[:nodes].each_key{|k| anchored_pgp[:nodes][k] = pgp[:nodes][k].dup}
      anchored_pgp[:nodes].each_value.with_index{|n, i| n[:term] = ts[i]}
      anchored_pgp
    end

    if @debug
      puts "[query] #{query}"
      p @pgp
      puts "-----"
      p mappings
      puts "====="
    end
  end

  def get_anchored_pgps
    @anchored_pgps
  end

  def get_focus
    @pgp[:focus]
  end

  def find_answer
    @anchored_pgps.each do |anchored_pgp|
      graphfinder = GraphFinder.new(anchored_pgp, @endpoint, @options)
      graphfinder.each_solution do |s|
        p s
      end
    end
  end

  def each_anchored_pgp_and_solution(proc_anchored_pgp = nil, proc_solution = nil)
    @anchored_pgps.each do |anchored_pgp|
      proc_anchored_pgp.call(anchored_pgp) unless proc_anchored_pgp.nil?
      GraphFinder.new(anchored_pgp, @endpoint, @options).each_solution do |s|
        proc_solution.call(s)
      end
    end
  end

  private

  def graphicate (parse)
    nodes = get_nodes(parse)

    node_index = {}
    nodes.each_key{|k| node_index[nodes[k][:head]] = k}

    focus = node_index[parse[:focus]]
    focus = node_index.values.first if focus.nil?

    edges = get_edges(parse, node_index)
    graph = {
      :nodes => nodes,
      :edges => edges,
      :focus => focus
    }
  end

  def get_nodes (parse)
    nodes = {}

    variable = 't0'
    parse[:base_noun_chunks].each do |c|
      variable = variable.next;
      nodes[variable] = {
        :head => c[:head],
        :text => parse[:tokens][c[:beg] .. c[:end]].collect{|t| t[:lex]}.join(' ')
      }
    end

    nodes
  end

  def get_edges (parse, node_index)
    edges = parse[:relations].collect do |s, p, o|
      {
        :subject => node_index[s],
        :object => node_index[o],
        :text => p.collect{|i| parse[:tokens][i][:lex]}.join(' ')
      }
    end
  end

end

if __FILE__ == $0
  # default values
  config_file = 'config/bio2rdf-omim.yml'
  maxhop = 2
  query = nil
  debug = false

  ## command line option processing
  require 'optparse'
  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: lodqa.rb [options]"

    opts.on('-c', '--configuration filename', "specifies configuration file (default = '#{config_file}')") do |f|
      config_file = f
    end

    opts.on('-m', '--maxhop number', "specifies the number of maximum hops to investigate (default = '#{maxhop}')") do |n|
      maxhop = n.to_i
    end

    opts.on('-q', '--query query', "gives the query to process.") do |q|
      query = q.chomp
    end

    opts.on('-d', '--debug', "tells it to be verbose.") do |q|
      debug = true
    end

    opts.on('-h', '--help', 'displays this screen') do
      puts opts
      exit
    end
  end

  optparse.parse!

  ## configuration
  require 'app_config'
  AppConfig.setup!(yaml: config_file)
  endpoint_url      = AppConfig.endpoint_url
  ignore_predicates = AppConfig.ignore_predicates
  sortal_predicates = AppConfig.sortal_predicates
  parser_url        = AppConfig.parser_url
  dictionary_url    = AppConfig.dictionary_url
  query             = AppConfig.query if query.nil?
  
  ## query from the command line
  query = ARGV[0] unless ARGV[0].nil?

  # puts "[SPARQL Endpoint] #{endpoint_url}"
  # puts "[dictionary URL] #{dictionary_url}"
  # puts "[Maximum number of hops] #{maxhop}"

  # lodqa = Lodqa::Lodqa.new(query, parser_url, dictionary_url, endpoint_url, {:debug => false, :ignore_predicates => ignore_predicates, :sortal_predicates => sortal_predicates})
  lodqa = Lodqa::Lodqa.new(query, parser_url, dictionary_url, endpoint_url, {:debug => debug, :ignore_predicates => ignore_predicates, :sortal_predicates => sortal_predicates})
  # lodqa.find_answer

  proc_anchored_pgp = Proc.new do |anchored_pgp|
    puts "================="
    p anchored_pgp
  end

  focus = lodqa.get_focus

  proc_solution = Proc.new do |solution|
    # target = if solution[('i' + focus).to_sym].nil?
    #   focus.to_sym
    # else
    #   ('i' + focus).to_sym
    # end
    # puts solution[target]
    # puts '-----'
    # p solution.keys
    p solution
  end

  lodqa.each_anchored_pgp_and_solution(proc_anchored_pgp, proc_solution)
  # lodqa.each_anchored_pgp_and_solution(nil, proc_solution)
end