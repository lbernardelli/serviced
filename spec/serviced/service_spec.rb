# frozen_string_literal: true

RSpec.describe Serviced::Service do
  let(:create_patient) do
    Class.new(described_class) do
      attribute :name,   :string
      attribute :age,    :integer
      attribute :active, :boolean, default: true
      attribute :clinic # untyped pass-through

      validates :name, presence: true
      validates :age, numericality: { greater_than: 0 }

      def self.name = "CreatePatient"

      def call
        success({ name:, age:, active:, clinic: })
      end
    end
  end

  describe "typed attributes" do
    it "coerces inputs through ActiveModel types" do
      service = create_patient.new(name: "Ada", age: "36", active: "1")
      expect(service.name).to eq("Ada")
      expect(service.age).to eq(36)
      expect(service.active).to be(true)
    end

    it "applies declared defaults" do
      service = create_patient.new(name: "Ada", age: 1)
      expect(service.active).to be(true)
    end

    it "keeps untyped attributes as-is" do
      clinic = Object.new
      service = create_patient.new(name: "Ada", age: 1, clinic:)
      expect(service.clinic).to be(clinic)
    end

    it "ignores unknown keys so services compose in flows" do
      expect { create_patient.new(name: "Ada", age: 1, wat: "x") }.not_to raise_error
    end
  end

  describe "object attribute types (a class as the type)" do
    let(:account_class) { Class.new }
    let(:service) do
      klass = account_class
      Class.new(described_class) do
        attribute :account, klass
        def self.name = "NeedsAccount"
        def call = success(account)
      end
    end

    it "passes the object through when the type matches" do
      account = account_class.new
      result = service.call(account:)
      expect(result).to be_success
      expect(result.value).to be(account)
    end

    it "fails with :invalid when the object is the wrong type" do
      result = service.call(account: "nope")
      expect(result.reason).to eq(:invalid)
      expect(result.error.full_messages.join).to match(/Account must be a/)
    end
  end

  describe "immutability" do
    it "does not expose public writers" do
      service = create_patient.new(name: "Ada", age: 1)
      expect(service).not_to respond_to(:name=)
      expect { service.name = "Grace" }.to raise_error(NoMethodError)
    end
  end

  describe ".call" do
    it "returns the success result from #call" do
      result = create_patient.call(name: "Ada", age: 36)
      expect(result).to be_a(Serviced::Success)
      expect(result.value).to include(name: "Ada", age: 36, active: true)
    end

    it "short-circuits invalid inputs to a failure without running #call" do
      result = create_patient.call(name: "", age: -1)

      expect(result).to be_a(Serviced::Failure)
      expect(result.reason).to eq(:invalid)
      expect(result.error).to be_a(ActiveModel::Errors)
      expect(result.error.full_messages).to include("Name can't be blank", "Age must be greater than 0")
    end

    it "raises when #call returns something other than a Result" do
      broken = Class.new(described_class) do
        def self.name = "Broken"

        def call = :not_a_result
      end

      expect { broken.call }.to raise_error(Serviced::ResultTypeError, /must return a Serviced::Result/)
    end

    it "raises NotImplementedError when #call is not implemented" do
      bare = Class.new(described_class) do
        def self.name = "Bare"
      end
      expect { bare.call }.to raise_error(NotImplementedError)
    end

    it "produces the invalid failure even for an anonymous class (no model_name)" do
      service = Class.new(described_class) do
        attribute :name, :string
        validates :name, presence: true
        def call = success(name)
      end

      result = service.call(name: "")
      expect(result.reason).to eq(:invalid)
      expect(result.error).to be_a(ActiveModel::Errors)
    end
  end

  describe "result helpers" do
    it "builds failures with reason, message and error payload" do
      service = Class.new(described_class) do
        def self.name = "Failing"

        def call
          failure(:not_created, "nope", error: :details)
        end
      end

      result = service.call
      expect(result.reason).to eq(:not_created)
      expect(result.message).to eq("nope")
      expect(result.error).to eq(:details)
    end
  end
end
