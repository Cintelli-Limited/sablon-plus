#!/usr/bin/env ruby
require_relative 'lib/sablon'

# Add debug logging
module Sablon
  module Processor
    class Document
      module FieldHandlers
        class ConditionalHandler
          alias_method :orig_build_statement, :build_statement
          
          def build_statement(constructor, field, options = {})
            puts "DEBUG: ConditionalHandler.build_statement called!"
            puts "  Field expression: #{field.expression}"
            result = orig_build_statement(constructor, field, options)
            puts "  Created statement: #{result.class}"
            result
          end
        end
      end
    end
  end
end

# Test
template = Sablon.template('test/Letterhead - Conditional.docx')
context = {
  client: { name: "Fraser Mayfield" },
  entity: { address_1: "123 Law St", address_city: "Sydney", address_postcode: "2000" },
  addressee: { first_name: "Fraser" },
  document: { date: "24 Feb 2026" },
  matter: { owner_name: "John Smith" }
}

puts "\n" + "=" * 60
puts "Processing template..."
puts "=" * 60
template.render_to_file('test/debug_output.docx', context)
puts "\nDone!"
