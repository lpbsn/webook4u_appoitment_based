# frozen_string_literal: true

module Bookings
  class Resource
    RESOURCE_KIND_ENSEIGNE = 1
    RESOURCE_KIND_STAFF = 2

    def self.for_enseigne(client:, enseigne:)
      return nil if enseigne.blank?

      # Transition state:
      # - today the reservable resource is still the whole enseigne
      # - tomorrow the target reservable resource is a staff belonging to that enseigne
      #
      # Callers should depend on this Resource abstraction rather than hard-coding
      # booking availability or locking rules directly against enseigne ids.
      new(
        client: client,
        scope: enseigne.bookings,
        kind: :enseigne,
        identifier: enseigne.id
      )
    end

    attr_reader :client, :scope, :kind, :identifier

    def initialize(client:, scope:, kind:, identifier:)
      @client = client
      @scope = scope
      @kind = kind
      @identifier = identifier
    end

    def bookings_scope
      scope
    end

    def lock_key
      [ lock_namespace, identifier.to_i ]
    end

    private

    def lock_namespace
      case kind
      when :enseigne
        RESOURCE_KIND_ENSEIGNE
      when :staff
        RESOURCE_KIND_STAFF
      else
        raise ArgumentError, "Unsupported booking resource kind: #{kind.inspect}"
      end
    end
  end
end
