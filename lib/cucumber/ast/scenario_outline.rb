module Cucumber
  module Ast
    class ScenarioOutline < Scenario
      # The +example_sections+ argument must be an Array where each element is another array representing
      # an Examples section. This array has 3 elements:
      #
      # * Examples keyword
      # * Examples section name
      # * Raw matrix
      def initialize(comment, tags, line, keyword, name, steps, example_sections)
        super(comment, tags, line, keyword, name, steps)
        steps.each {|step| step.status = :outline}

        @examples_array = example_sections.map do |example_section|
          examples_keyword    = example_section[0]
          examples_name       = example_section[1]
          examples_matrix     = example_section[2]

          examples_table = OutlineTable.new(examples_matrix, self)
          Examples.new(examples_keyword, examples_name, examples_table)
        end
      end

      def accept(visitor)
        visitor.visit_comment(@comment)
        visitor.visit_tags(@tags)
        visitor.visit_scenario_name(@keyword, @name, file_line(@line), source_indent(text_length))
        @steps.each do |step|
          visitor.visit_step(step)
        end
        @examples_array.each do |examples|
          visitor.visit_examples(examples)
        end
      end

      def execute_row(cells, visitor, &proc)
        visitor.world(self) do |world|
          previous = :passed
          argument_hash = cells.to_hash
          cell_index = 0
          @steps.each do |step|
            previous, matched_args = step.execute_with_arguments(argument_hash, world, previous, visitor, cells[0].line)
            # There might be steps that don't have any arguments
            # If there are no matched args, we'll still iterate once
            matched_args = [nil] if matched_args.empty?

            matched_args.each do
              cell = cells[cell_index]
              if cell
                proc.call(cell, previous)
                cell_index += 1
              end
            end
          end
        end
        @feature.scenario_executed(self) if @feature
      end

      def pending? ; false ; end

      def to_sexp
        sexp = [:scenario_outline, @keyword, @name]
        comment = @comment.to_sexp
        sexp += [comment] if comment
        tags = @tags.to_sexp
        sexp += tags if tags.any?
        steps = @steps.map{|step| step.to_sexp}
        sexp += steps if steps.any?
        sexp += @examples_array.map{|e| e.to_sexp}
        sexp
      end
    end
  end
end
