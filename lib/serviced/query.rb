# frozen_string_literal: true

module Serviced
  # Base class for query objects: a named home for a complex read.
  #
  # A query has the same typed, immutable inputs as a {Serviced::Service} (see
  # {Serviced::Typed}), but instead of a Result it returns whatever #call
  # returns, usually an +ActiveRecord::Relation+. Returning a relation keeps the
  # result composable: callers can still paginate, add includes, or chain more
  # scopes. A service then consumes the query and wraps its result in a Result.
  #
  #   class EnrolledPatientsQuery < Serviced::Query
  #     attribute :clinic
  #     attribute :program_external_id, :string
  #     attribute :sort_direction, :string, default: "asc"
  #
  #     validates :sort_direction, inclusion: { in: %w[asc desc] }
  #
  #     def call
  #       clinic.patients
  #             .where("enrolled_in(?)", program_external_id)
  #             .order("enrolled_at #{sort_direction}")
  #     end
  #   end
  #
  #   relation = EnrolledPatientsQuery.call(clinic:, program_external_id: "cardio")
  #   relation.page(params[:page]) # still a relation
  #
  # Invalid inputs raise {Serviced::InvalidQuery} (a query has no failure
  # channel, so bad input is treated as a programming error).
  #
  # The SQL helpers (#quote, #count_of, ...) require ActiveRecord at runtime.
  class Query
    include Typed

    class << self
      # Builds the query, validates it, and runs #call.
      # @param attributes [Hash] input values; unknown keys are ignored
      # @return [Object] whatever #call returns (typically an ActiveRecord::Relation)
      # @raise [Serviced::InvalidQuery] if inputs fail validation
      def call(attributes = {})
        query = new(attributes)
        raise InvalidQuery, query.errors if query.invalid?

        query.call
      end
    end

    # The query body. Subclasses must implement it and return a relation (to
    # stay composable) or a materialized value.
    # @return [ActiveRecord::Relation, Object]
    def call
      raise NotImplementedError, "#{self.class} must implement #call"
    end

    private

    def connection
      ActiveRecord::Base.connection
    end

    # Quotes a value for safe interpolation into raw SQL.
    def quote(value)
      connection.quote(value)
    end

    # Quotes a column or table name for safe interpolation into raw SQL.
    def quote_column(name)
      connection.quote_column_name(name)
    end

    # Builds a sanitized SQL fragment from a statement and bind values.
    #   sanitize("state = ? AND age > ?", "active", 18)
    def sanitize(statement, *binds)
      ActiveRecord::Base.sanitize_sql_array([statement, *binds])
    end

    # Counts the rows of a relation without loading them, wrapping it in a
    # subquery. Replaces a hand-rolled "SELECT COUNT(*) FROM (...)" idiom.
    # @param relation [ActiveRecord::Relation]
    # @param cte [String] optional leading CTE (e.g. "WITH foo AS (...)")
    # @return [Integer]
    def count_of(relation, cte: "")
      sql = "#{cte} SELECT COUNT(*) FROM (#{relation.to_sql}) serviced_count".strip
      connection.select_value(sql).to_i
    end
  end
end
