# frozen_string_literal: true

RSpec.describe Serviced::Flow do
  # A step that records that it ran (by appending to the shared :store from the
  # context) and then either succeeds contributing a hash, or fails.
  def recording_step(marker, fail: false)
    should_fail = fail
    Class.new(Serviced::Service) do
      attribute :store, isolate: false # shared accumulator the test inspects
      define_singleton_method(:name) { "Step_#{marker}" }
      define_method(:call) do
        store << marker
        should_fail ? failure(:boom, "failed at #{marker}") : success(marker => true)
      end
    end
  end

  describe "sequencing and context" do
    it "runs steps in order and threads an accumulating context" do
      flow = Serviced::Flow.define do
        step(->(ctx) { Serviced::Success.new(ctx.merge(one: 1)) })
        step(->(ctx) { Serviced::Success.new(ctx.merge(two: ctx[:one] + 1)) })
      end

      result = flow.call(seed: 0)

      expect(result).to be_success
      expect(result.value).to eq(seed: 0, one: 1, two: 2)
    end

    it "passes data produced by an earlier step to a later one" do
      producer = Class.new(Serviced::Service) do
        def self.name = "Producer"
        def call = success(patient: "patient-record")
      end
      consumer = Class.new(Serviced::Service) do
        attribute :patient
        def self.name = "Consumer"
        def call = success(seen: patient)
      end

      flow = Serviced::Flow.define do
        step producer
        step consumer
      end

      expect(flow.call.value).to include(patient: "patient-record", seen: "patient-record")
    end

    it "halts on the first failing step and returns that failure" do
      store = []
      flow = Serviced::Flow.define.tap do |f|
        f.step recording_step(:a)
        f.step recording_step(:b, fail: true)
        f.step recording_step(:c)
      end

      result = flow.call(store: store)

      expect(result).to be_failure
      expect(result.reason).to eq(:boom)
      expect(store).to eq(%i[a b]) # :c never ran
    end

    it "raises when a step returns something other than a Result" do
      flow = Serviced::Flow.define do
        step(->(_ctx) { :nope })
      end

      expect { flow.call }.to raise_error(Serviced::ResultTypeError, /must return a Serviced::Result/)
    end
  end

  describe "class-based DSL" do
    it "supports subclassing with step and transactional" do
      flow = Class.new(described_class) do
        step(->(ctx) { Serviced::Success.new(ctx.merge(done: true)) })
      end

      expect(flow.transactional?).to be(false)
      expect(flow.call.value).to eq(done: true)
    end
  end

  describe "transactions" do
    let(:store) { [] }

    def install_handler
      Serviced.configure do |config|
        config.transaction_handler = lambda do |&block|
          snapshot = store.dup
          begin
            block.call
          rescue StandardError
            store.replace(snapshot) # simulate rollback of persisted writes
            raise
          end
        end
      end
    end

    it "commits every step when the flow succeeds" do
      install_handler
      flow = Serviced::Flow.define(transaction: true).tap do |f|
        f.step recording_step(:a)
        f.step recording_step(:b)
      end

      result = flow.call(store: store)

      expect(result).to be_success
      expect(store).to eq(%i[a b])
    end

    it "rolls back everything when a step fails" do
      install_handler
      flow = Serviced::Flow.define(transaction: true).tap do |f|
        f.step recording_step(:a)
        f.step recording_step(:b, fail: true)
        f.step recording_step(:c)
      end

      result = flow.call(store: store)

      expect(result).to be_failure
      expect(result.reason).to eq(:boom)
      expect(store).to eq([]) # rolled back
    end

    it "rolls back and propagates when a step raises" do
      install_handler
      raising = Class.new(Serviced::Service) do
        attribute :store, isolate: false
        def self.name = "Raising"

        def call
          store << :x
          raise "kaboom"
        end
      end
      flow = Serviced::Flow.define(transaction: true) { step raising }

      expect { flow.call(store: store) }.to raise_error("kaboom")
      expect(store).to eq([]) # rolled back before the exception surfaced
    end

    it "raises MissingTransactionHandler when none is configured" do
      Serviced.configure { |config| config.transaction_handler = nil }
      flow = Serviced::Flow.define(transaction: true) do
        step(->(ctx) { Serviced::Success.new(ctx) })
      end

      expect { flow.call }.to raise_error(Serviced::MissingTransactionHandler)
    end
  end
end
