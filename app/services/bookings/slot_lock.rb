# frozen_string_literal: true

module Bookings
  class SlotLock
    # Verrou PostgreSQL transactionnel au niveau de la ressource réservable.
    #
    # Etape 1: la ressource logique est mappée à l'enseigne entière.
    # Ce choix est volontairement plus grossier que l'invariant métier
    # d'overlap par intervalle: il sérialise toutes les créations et
    # confirmations d'une même enseigne, même sur des créneaux indépendants.
    #
    # Ce compromis limite la concurrence intra-enseigne sous charge, mais
    # garde une clé de verrou stable tant que le produit n'a pas encore une
    # ressource plus fine (staff / resource) à verrouiller.
    #
    # Ce verrou ne doit donc pas être lu comme une granularité définitive
    # du domaine. Si le throughput d'une même enseigne devient un sujet,
    # l'évolution attendue est un verrou au niveau d'une ressource plus fine.
    def self.with_lock(resource:)
      lock_key_1, lock_key_2 = resource.lock_key

      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute(
          "SELECT pg_advisory_xact_lock(#{lock_key_1}, #{lock_key_2})"
        )

        yield
      end
    end
  end
end
