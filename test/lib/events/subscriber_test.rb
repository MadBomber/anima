# frozen_string_literal: true

require "test_helper"

class Events::SubscriberTest < ActiveSupport::TestCase
  class BrokenSubscriber
    include Events::Subscriber
    # deliberately does not override #emit
  end

  test "emit raises NotImplementedError when not implemented by subclass" do
    subscriber = BrokenSubscriber.new
    assert_raises(NotImplementedError) { subscriber.emit({name: "test", payload: {}, timestamp: 0}) }
  end
end
