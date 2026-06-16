# frozen_string_literal: true

module RuboCop
  module Cop
    module Comments
      class NoComments < Base
        include RangeHelp
        extend AutoCorrector

        MSG = "Avoid comments; let the code speak for itself."

        MAGIC = /\A#\s*(?:frozen_string_literal|encoding|coding|warn_indent|shareable_constant_value|-\*-)/
        SHEBANG = /\A#!/
        DIRECTIVE = /\A#\s*rubocop:(?:disable|enable|todo)\b/

        def on_new_investigation
          processed_source.comments.each do |comment|
            next if functional?(comment)

            add_offense(comment) do |corrector|
              corrector.remove(removal_range(comment))
            end
          end
        end

        private

        def functional?(comment)
          text = comment.text
          MAGIC.match?(text) || SHEBANG.match?(text) || DIRECTIVE.match?(text)
        end

        def removal_range(comment)
          if comment_only_line?(comment)
            range_by_whole_lines(comment.source_range, include_final_newline: true)
          else
            range_with_surrounding_space(range: comment.source_range, side: :left, newlines: false)
          end
        end

        def comment_only_line?(comment)
          processed_source.lines[comment.loc.line - 1].lstrip.start_with?("#")
        end
      end
    end
  end
end
