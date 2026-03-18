# frozen_string_literal: true

require "test_helper"

class Events::BusTest < ActiveSupport::TestCase
  # A minimal real subscriber — no mocks.
  class RecordingSubscriber
    include Events::Subscriber

    attr_reader :received

    def initialize
      @received = []
      @mutex = Mutex.new
    end

    def emit(event)
      @mutex.synchronize { @received << event }
    end

    def last = @mutex.synchronize { @received.last }
    def count = @mutex.synchronize { @received.size }
  end

  def setup
    @subscriber = RecordingSubscriber.new
    Events::Bus.subscribe(@subscriber)
  end

  def teardown
    Events::Bus.unsubscribe(@subscriber)
  end

  test "emit notifies subscriber with event name and payload" do
    event = Events::UserMessage.new(content: "hello")
    Events::Bus.emit(event)

    received = @subscriber.last
    assert_not_nil received
    assert_equal "anima.user_message", received[:name]
    assert_equal "user_message", received.dig(:payload, :type)
    assert_equal "hello", received.dig(:payload, :content)
  end

  test "emit uses the event's event_name as notification name" do
    Events::Bus.emit(Events::AgentMessage.new(content: "reply"))

    assert_equal "anima.agent_message", @subscriber.last[:name]
  end

  test "subscriber receives each emitted event" do
    Events::Bus.emit(Events::UserMessage.new(content: "one"))
    Events::Bus.emit(Events::AgentMessage.new(content: "two"))
    Events::Bus.emit(Events::SystemMessage.new(content: "three"))

    assert_equal 3, @subscriber.count
  end

  test "unsubscribed subscriber no longer receives events" do
    Events::Bus.unsubscribe(@subscriber)
    Events::Bus.emit(Events::UserMessage.new(content: "ignored"))

    assert_equal 0, @subscriber.count
  end

  test "multiple subscribers each receive the event" do
    second = RecordingSubscriber.new
    Events::Bus.subscribe(second)

    Events::Bus.emit(Events::UserMessage.new(content: "broadcast"))

    assert_equal 1, @subscriber.count
    assert_equal 1, second.count
  ensure
    Events::Bus.unsubscribe(second)
  end

  test "payload includes session_id when provided" do
    Events::Bus.emit(Events::UserMessage.new(content: "hi", session_id: 99))

    assert_equal 99, @subscriber.last.dig(:payload, :session_id)
  end
end
