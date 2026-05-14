#!/usr/bin/env ruby
require 'bundler/setup'
require_relative 'lib/sablon'

# Check what the parser extracts from fields
class FieldInspector
  def self.inspect_template
    template_path = 'test/Letterhead - Conditional.docx'
    doc = SablonPlus::Template.new(template_path)
    
    # Access internal processor
    processor = doc.instance_variable_get(:@processor)
    
    # Monkey patch to see fields
    parser_class = SablonPlus::Parser::MailMerge
    orig_parse = parser_class.method(:parse)
    
    parser_class.define_singleton_method(:parse) do |document|
      fields = orig_parse.call(document)
      puts "=" * 60
      puts "Parsed #{fields.length} fields:"
      puts "=" * 60
      fields.each_with_index do |field, i|
        puts "#{i+1}. Expression: '#{field.expression}'"
      end
      puts "=" * 60
      fields
    end
    
    # Trigger parsing
    doc.render_to_string({
      client: { name: "Test" },
      entity: { address_1: "x", address_city: "y", address_postcode: "z" },
      addressee: { first_name: "Test" },
      document: { date: "Test" },
      matter: { owner_name: "Test" }
    })
  end
end

FieldInspector.inspect_template
