# frozen_string_literal: true

RSpec.describe Serviced::Result do
  describe Serviced::Success do
    subject(:result) { described_class.new(:payload) }

    it "reports success" do
      expect(result).to be_success
      expect(result).not_to be_failure
    end

    it "exposes its value" do
      expect(result.value).to eq(:payload)
      expect(result.value!).to eq(:payload)
    end

    it "is frozen and immutable" do
      expect(result).to be_frozen
    end

    it "runs the on_success callback with the value and returns self" do
      yielded = nil
      returned = result.on_success { |value| yielded = value }
      expect(yielded).to eq(:payload)
      expect(returned).to be(result)
    end

    it "ignores the on_failure callback" do
      expect { |b| result.on_failure(&b) }.not_to yield_control
    end

    it "chains with and_then, passing the value through" do
      final = result.and_then { |value| Serviced::Success.new("#{value}!") }
      expect(final.value).to eq("payload!")
    end

    it "raises when and_then does not return a Result" do
      expect { result.and_then { :nope } }.to raise_error(Serviced::ResultTypeError)
    end

    it "maps the value into a new success" do
      mapped = result.map { |value| value.to_s.upcase }
      expect(mapped).to be_a(Serviced::Success)
      expect(mapped.value).to eq("PAYLOAD")
    end

    it "supports array and hash pattern matching" do
      case result
      in Serviced::Success(value:)
        expect(value).to eq(:payload)
      end

      case result
      in Serviced::Success(payload_value)
        expect(payload_value).to eq(:payload)
      end
    end
  end

  describe Serviced::Failure do
    subject(:result) { described_class.new(:not_found, "Missing", error: :boom) }

    it "reports failure" do
      expect(result).to be_failure
      expect(result).not_to be_success
    end

    it "exposes reason, message and error" do
      expect(result.reason).to eq(:not_found)
      expect(result.message).to eq("Missing")
      expect(result.error).to eq(:boom)
    end

    it "has no value" do
      expect(result.value).to be_nil
    end

    it "raises when unwrapped with value!" do
      expect { result.value! }.to raise_error(Serviced::InvalidResultAccess)
    end

    it "defaults reason to :error" do
      expect(described_class.new.reason).to eq(:error)
    end

    it "is frozen and immutable" do
      expect(result).to be_frozen
    end

    it "runs the on_failure callback with itself and returns self" do
      yielded = nil
      returned = result.on_failure { |failure| yielded = failure }
      expect(yielded).to be(result)
      expect(returned).to be(result)
    end

    it "ignores the on_success callback" do
      expect { |b| result.on_success(&b) }.not_to yield_control
    end

    it "short-circuits and_then and map" do
      expect(result.and_then { Serviced::Success.new(:x) }).to be(result)
      expect(result.map { :x }).to be(result)
    end

    it "supports pattern matching on reason" do
      case result
      in Serviced::Failure(reason: :not_found, message:)
        expect(message).to eq("Missing")
      end
    end
  end
end
