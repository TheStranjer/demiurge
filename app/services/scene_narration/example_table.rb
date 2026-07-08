# frozen_string_literal: true

module SceneNarration
  module ExampleTable
    TEXT = <<~TABLE
      {
        "description": "Degree of success on an uncertain attempt",
        "denomination": 6,
        "quantity": 2,
        "contested": true,
        "entity_modifiers": ["finesse"],
        "defender_modifiers": ["awareness"],
        "possible_results": [
          { "min": null, "max": 2, "result": "The attempt backfires and leaves things worse than before" },
          { "min": 3, "max": 6, "result": "It fails, though without lasting harm" },
          { "min": 7, "max": 9, "result": "A partial success, won at a real cost" },
          { "min": 10, "max": 11, "result": "A clean, unqualified success" },
          { "min": 12, "max": null, "result": "A triumph that surpasses what was hoped for" }
        ]
      }
    TABLE

    GUIDANCE = "No roll tables exist yet, so propose one in new_tables. A table rolls `quantity` dice of " \
               "`denomination` sides and sums them; each row's min and max bound a slice of that total — set " \
               "either to null to leave that end open, or make them equal to single out one total. Always set " \
               "`contested` (true when another character actively resists, like deceiving or grappling; false " \
               "for feats nobody opposes, like climbing a wall) and always give `entity_modifiers` and " \
               "`defender_modifiers` — the stats the acting character adds and the resisting one subtracts " \
               "(#{Character::STATS.join(", ")}); use empty arrays when none apply. new_tables takes an array " \
               "of objects shaped like this well-formed example:\n#{TEXT}".freeze
  end
end
