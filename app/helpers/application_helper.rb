# frozen_string_literal: true

module ApplicationHelper
  def roll_range_label(row)
    min = row["min"]
    max = row["max"]

    return "any" if min.nil? && max.nil?
    return "#{min}+" if max.nil?
    return "≤#{max}" if min.nil?
    return min.to_s if min == max

    "#{min}–#{max}"
  end

  def roll_result_outcome(roll_result)
    parts = ["rolled #{roll_result.roll_result}"] + roll_result.modifier_descriptions
    total = roll_result.modifier_descriptions.any? ? " = #{roll_result.modified_roll_result}" : ""
    "→ #{parts.join(" ")}#{total} (#{roll_result.result})"
  end
end
