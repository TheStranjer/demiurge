# frozen_string_literal: true

module SceneNarration
  module ExampleTable
    TEXT = <<~TABLE
      {
        "description": "Degree of success on an uncertain attempt",
        "denomination": 6,
        "quantity": 2,
        "possible_results": [
          { "min": null, "max": 2, "result": "The attempt backfires and leaves things worse than before" },
          { "min": 3, "max": 6, "result": "It fails, though without lasting harm" },
          { "min": 7, "max": 9, "result": "A partial success, won at a real cost" },
          { "min": 10, "max": 11, "result": "A clean, unqualified success" },
          { "min": 12, "max": null, "result": "A triumph that surpasses what was hoped for" }
        ]
      }
    TABLE
  end
end
