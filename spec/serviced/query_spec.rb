# frozen_string_literal: true

require "active_record"

RSpec.describe Serviced::Query do
  describe "typed inputs (shared with Service via Typed)" do
    let(:limit_query) do
      Class.new(described_class) do
        attribute :limit, :integer
        def self.name = "LimitQuery"
        def call = limit
      end
    end

    it "coerces inputs through ActiveModel types" do
      expect(limit_query.call(limit: "5")).to eq(5)
    end

    it "keeps inputs immutable" do
      query = limit_query.new(limit: 5)
      expect(query).not_to respond_to(:limit=)
      expect { query.limit = 9 }.to raise_error(NoMethodError)
    end

    it "ignores unknown keys" do
      expect { limit_query.new(limit: 1, nope: 2) }.not_to raise_error
    end
  end

  describe ".call" do
    it "returns whatever #call returns, with no Result requirement" do
      query = Class.new(described_class) do
        def self.name = "PlainQuery"
        def call = [1, 2, 3]
      end

      expect(query.call).to eq([1, 2, 3])
    end

    it "raises NotImplementedError when #call is not implemented" do
      bare = Class.new(described_class) do
        def self.name = "Bare"
      end
      expect { bare.call }.to raise_error(NotImplementedError)
    end

    it "raises InvalidQuery when inputs fail validation" do
      query = Class.new(described_class) do
        attribute :sort_direction, :string, default: "asc"
        validates :sort_direction, inclusion: { in: %w[asc desc] }
        def self.name = "SortedQuery"
        def call = sort_direction
      end

      expect { query.call(sort_direction: "sideways") }.to raise_error(Serviced::InvalidQuery) do |error|
        expect(error.errors).to be_a(ActiveModel::Errors)
        expect(error.message).to include("Sort direction is not included in the list")
      end
    end

    it "runs #call when inputs are valid" do
      query = Class.new(described_class) do
        attribute :sort_direction, :string, default: "asc"
        validates :sort_direction, inclusion: { in: %w[asc desc] }
        def self.name = "SortedQuery"
        def call = sort_direction
      end

      expect(query.call(sort_direction: "desc")).to eq("desc")
    end

    it "builds the InvalidQuery message even for an anonymous class (no model_name)" do
      query = Class.new(described_class) do
        attribute :sort_direction, :string
        validates :sort_direction, presence: true
        def call = sort_direction
      end

      expect { query.call }.to raise_error(Serviced::InvalidQuery)
    end
  end

  describe "SQL helpers" do
    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

    before { allow(ActiveRecord::Base).to receive(:connection).and_return(connection) }

    it "quotes values through the connection" do
      allow(connection).to receive(:quote).with("O'Hara").and_return("'O''Hara'")
      query = Class.new(described_class) do
        def self.name = "QuoteQuery"
        def call = quote("O'Hara")
      end

      expect(query.call).to eq("'O''Hara'")
    end

    it "delegates sanitize to ActiveRecord::Base.sanitize_sql_array" do
      allow(ActiveRecord::Base).to receive(:sanitize_sql_array)
        .with(["state = ? AND age > ?", "active", 18])
        .and_return("state = 'active' AND age > 18")
      query = Class.new(described_class) do
        def self.name = "SanitizeQuery"
        def call = sanitize("state = ? AND age > ?", "active", 18)
      end

      expect(query.call).to eq("state = 'active' AND age > 18")
    end

    it "counts a relation by wrapping it in a subquery" do
      relation = instance_double(ActiveRecord::Relation, to_sql: "SELECT * FROM patients")
      expect(connection).to receive(:select_value)
        .with(a_string_including("SELECT COUNT(*) FROM (SELECT * FROM patients) serviced_count"))
        .and_return("42")
      query = Class.new(described_class) do
        attribute :relation
        def self.name = "CountingQuery"
        def call = count_of(relation)
      end

      expect(query.call(relation: relation)).to eq(42)
    end
  end
end
