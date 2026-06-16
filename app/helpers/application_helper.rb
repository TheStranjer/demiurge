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
end
