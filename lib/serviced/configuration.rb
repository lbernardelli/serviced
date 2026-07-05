# frozen_string_literal: true

module Serviced
  # Global configuration for Serviced.
  #
  #   Serviced.configure do |config|
  #     config.transaction_handler = ->(&block) { MyDB.transaction(&block) }
  #   end
  class Configuration
    # A callable that runs the given block inside a database transaction. It
    # must execute the block and roll back when the block raises (Serviced
    # relies on this to undo a transactional flow whose step failed).
    #
    # Defaults to +ActiveRecord::Base.transaction+ when ActiveRecord is loaded,
    # otherwise nil.
    # @return [#call, nil]
    attr_accessor :transaction_handler

    def initialize
      @transaction_handler = default_transaction_handler
    end

    private

    def default_transaction_handler
      return unless defined?(ActiveRecord::Base)

      ->(&block) { ActiveRecord::Base.transaction(&block) }
    end
  end
end
