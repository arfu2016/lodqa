require 'rest_client'
require 'lodqa/termfinder'
require 'lodqa/async'

module Lodqa
  module Sources
    class << self
      def select_db_for(pgp, targets_url, read_timeout)
        Logger.request_id = Logger.generate_request_id

        applicants = begin
          RestClient.get targets_url do |response, request, result|
            case response.code
            when 200 then JSON.parse(response, symbolize_names: true)
              else raise IOError, "invalid url #{targets_url}"
            end
          end
        rescue
          raise IOError, "invalid url #{targets_url}"
        end

        searchable?(pgp, applicants, read_timeout) { |dbs| yield dbs }
      end

      def searchable?(pgp, applicants, read_timeout)
        Logger.request_id = Logger.generate_request_id

        applicants = select_db_that_can_answer_terms_of_all_nodes(applicants, pgp)
        return  yield [] if applicants.empty?

        select_db_that_can_generate_at_least_one_sparql(applicants, pgp, read_timeout) { |dbs| yield dbs }
      end

      private

      def select_db_that_can_answer_terms_of_all_nodes(applicants, pgp)
        keywords = pgp[:nodes].values.map{|n| n[:text]}
        applicants
          .map do |applicant|
            begin
              applicant[:terms] = TermFinder
                .new(applicant[:dictionary_url])
                .find(keywords)
              applicant
            rescue GatewayError
              p "dictionary_url error for #{applicant[:name]}"
              applicant
            end
          end
          .select {|applicant| applicant[:terms] && applicant[:terms].all?{|t| t[1].length > 0 } }
      end

      def select_db_that_can_generate_at_least_one_sparql(applicants, pgp, read_timeout)
        do_applicants_have_sparql = applicants.map { |a| [a[:name], false] }.to_h
        applicants
          .each do |applicant|
            begin
              # Can an applicant create at least one sparql.
              options = {
                max_hop: applicant[:max_hop],
                ignore_predicates: applicant[:ignore_predicates],
                sortal_predicates: applicant[:sortal_predicates],
                debug: false,
                endpoint_options: {read_timeout: read_timeout || 60}
              }

              lodqa = Lodqa.new(applicant[:endpoint_url], applicant[:graph_uri], options)
              lodqa.pgp = pgp

              keywords = pgp[:nodes].values.map{|n| n[:text]}.concat(pgp[:edges].map{|e| e[:text]})
              lodqa.mappings = TermFinder
                .new(applicant[:dictionary_url])
                .find(keywords)

              # Generating an instance of GraphFinder may spend time due to queries to some SPARQL endpoints is too slow.
              # So we send SPARQL requests in parallel per endpoint.
              Async.defer do
                begin
                  applicant[:sparqls] = lodqa.sparqls.first
                  do_applicants_have_sparql[applicant[:name]] = true

                  yield applicants.select { |a| a[:sparqls] } if do_applicants_have_sparql.values.all?{ |has_sparql| has_sparql }
                rescue SocketError, Net::HTTP::Persistent::Error, Errno::ECONNREFUSED => e
                  # Output error information and resume the next applicant.
                  Logger.debug "Cannot get SPARQLs for #{applicant[:name]}", error_messsage: e.message, trace: e.backtrace
                rescue => e
                  puts "Error at #{__method__} !!!!!! #{e.class}"
                  raise e
                end
              end
            rescue SocketError, Net::HTTP::Persistent::Error, Errno::ECONNREFUSED => e
              # Output error information and resume the next applicant.
              Logger.debug "Cannot get terms for #{applicant[:name]}", error_messsage: e.message, trace: e.backtrace
            end
          end
      end
    end
  end
end
