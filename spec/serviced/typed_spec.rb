# frozen_string_literal: true

RSpec.describe Serviced::Typed do
  let(:klass) do
    Class.new do
      include Serviced::Typed

      attribute :filters              # isolated by default
      attribute :tags                 # isolated by default
      attribute :label, :string
      attribute :sink, isolate: false # shared by reference

      def self.name = "TypedThing"
    end
  end

  describe "typed, immutable inputs" do
    it "coerces values and exposes readers but not writers" do
      obj = klass.new(label: 123)
      expect(obj.label).to eq("123")
      expect(obj).not_to respond_to(:label=)
    end
  end

  describe "isolation by default" do
    it "stores a deeply frozen snapshot of value-like data" do
      obj = klass.new(filters: { "a" => [1, 2] })
      expect(obj.filters).to be_frozen
      expect(obj.filters["a"]).to be_frozen
    end

    it "does not freeze the caller's object" do
      caller_hash = { "a" => 1 }
      klass.new(filters: caller_hash)
      expect(caller_hash).not_to be_frozen
    end

    it "isolates the value from the caller's later mutations" do
      caller_array = ["x"]
      obj = klass.new(tags: caller_array)
      caller_array << "y"
      expect(obj.tags).to eq(["x"])
    end

    it "rejects mutation of the snapshot" do
      obj = klass.new(tags: ["x"])
      expect { obj.tags << "y" }.to raise_error(FrozenError)
    end

    it "memoizes the snapshot so reads are stable" do
      obj = klass.new(tags: ["x"])
      expect(obj.tags).to be(obj.tags)
    end

    it "handles a nil value" do
      expect(klass.new.filters).to be_nil
    end
  end

  describe "objects with identity are shared, not copied (record safety)" do
    it "returns the same object by reference, unfrozen" do
      record = Object.new # stands in for an ActiveRecord record
      obj = klass.new(filters: record)
      expect(obj.filters).to be(record)    # same object, not a copy
      expect(obj.filters).not_to be_frozen # not frozen: freezing would corrupt the caller
    end

    it "shares an object nested inside an isolated collection" do
      record = Object.new
      obj = klass.new(filters: { patient: record })
      expect(obj.filters).to be_frozen            # the container is frozen
      expect(obj.filters[:patient]).to be(record) # the leaf object is shared
    end
  end

  describe "isolate: false opts out" do
    it "shares the reference for a deliberately mutable input" do
      caller_array = ["x"]
      obj = klass.new(sink: caller_array)
      caller_array << "y"
      expect(obj.sink).to eq(%w[x y]) # same object, shared by reference
      expect(obj.sink).not_to be_frozen
    end
  end

  describe "a class as the type (instance-of enforcement)" do
    let(:animal) { Class.new }
    let(:typed_class) do
      pet_class = animal
      Class.new do
        include Serviced::Typed

        attribute :pet, pet_class
        def self.name = "PetOwner"
      end
    end

    it "accepts an instance of the class" do
      expect(typed_class.new(pet: animal.new)).to be_valid
    end

    it "accepts a subclass instance" do
      subclass = Class.new(animal)
      expect(typed_class.new(pet: subclass.new)).to be_valid
    end

    it "allows nil (make it required with presence: true)" do
      expect(typed_class.new).to be_valid
    end

    it "rejects a value of the wrong type" do
      obj = typed_class.new(pet: "not an animal")
      expect(obj).not_to be_valid
      expect(obj.errors.full_messages.join).to match(/Pet must be a/)
    end

    it "shares the object by reference, without coercing it" do
      pet = animal.new
      expect(typed_class.new(pet: pet).pet).to be(pet)
    end
  end
end
