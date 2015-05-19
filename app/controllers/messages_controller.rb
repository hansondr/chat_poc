require 'streamer/sse'

class MessagesController < ApplicationController
  include ActionController::Live

  def index
    @messages = Message.all
  end

  def new
    @message = Message.new
  end

  def create
    @message = Message.new(message_params)
    if @message.save
      redis.publish('messages.create', @message.to_json)
      redirect_to messages_path
    else
      render :new
    end
  end

  def events
    response.headers['Content-Type'] = 'text/event-stream'
    sse = Streamer::SSE.new(response.stream)
    redis.subscribe('messages.create') do |on|
      on.message do |event, data|
        sse.write(data, event: 'messages.create')
      end
    end
    render nothing: true
  rescue IOError
  ensure
    redis.quit
    sse.close
  end

  private

  def message_params
    params.require(:message).permit(:name, :content)
  end

  def redis
    @redis ||= Redis.new
  end
end