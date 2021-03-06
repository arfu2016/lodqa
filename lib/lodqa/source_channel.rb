require 'lodqa/source_channel_data'

module Lodqa
  class SourceChannel
    def initialize(socket, source)
      @socket = socket
      @data = SourceChannelData.new source
    end

    def start
      @socket.send 'start'
    end

    def send(data)
      @socket.send @data.format data
    end

    def error(error)
      @socket.send({error: error}.to_json)
    end

    def close
      @socket.close_connection(true)
    end
  end
end
