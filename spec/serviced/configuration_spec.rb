# frozen_string_literal: true

RSpec.describe Serviced::Configuration do
  describe "Serviced.configure" do
    it "persists changes to the configuration" do
      handler = ->(&block) { block.call }
      Serviced.configure { |config| config.transaction_handler = handler }
      expect(Serviced.configuration.transaction_handler).to be(handler)
    end
  end

  describe "Serviced.reset_configuration!" do
    it "replaces the configuration with a fresh instance" do
      Serviced.configure { |config| config.transaction_handler = ->(&block) { block.call } }
      previous = Serviced.configuration
      Serviced.reset_configuration!
      expect(Serviced.configuration).to be_a(described_class)
      expect(Serviced.configuration).not_to be(previous)
    end
  end

  describe "default transaction handler" do
    it "delegates to ActiveRecord::Base.transaction when ActiveRecord is available" do
      require "active_record"
      config = described_class.new

      expect(config.transaction_handler).to respond_to(:call)

      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      ran = false
      config.transaction_handler.call { ran = true }

      expect(ActiveRecord::Base).to have_received(:transaction)
      expect(ran).to be(true)
    end
  end
end
