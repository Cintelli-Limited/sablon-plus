#!/usr/bin/env ruby
require_relative 'lib/sablon'

# Test with Fraser Mayfield (should show conditional content)
puts "=" * 60
puts "Test 1: Client name = 'Fraser Mayfield'"
puts "=" * 60

template = Sablon.template(File.expand_path("test/Letterhead - Conditional.docx"))
context = {
  entity: {
    address_1: "123 Law Street",
    address_city: "Sydney",
    address_postcode: "2000"
  },
  client: {
    name: "Fraser Mayfield",
    address_1: "456 Client Ave",
    address_city: "Melbourne",
    address_postcode: "3000"
  },
  addressee: {
    first_name: "Fraser"
  },
  document: {
    date: "24 February 2026"
  },
  matter: {
    owner_name: "John Smith"
  }
}

begin
  output_path = File.expand_path("test/output_fraser.docx")
  template.render_to_file(output_path, context)
  puts "✓ Generated: #{output_path}"
  puts ""
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
  puts ""
end

# Test with different client name (should NOT show conditional content)
puts "=" * 60
puts "Test 2: Client name = 'John Doe'"
puts "=" * 60

context2 = context.dup
context2[:client] = {
  name: "John Doe",
  address_1: "789 Other St",
  address_city: "Brisbane",
  address_postcode: "4000"
}
context2[:addressee] = { first_name: "John" }

begin
  output_path2 = File.expand_path("test/output_john.docx")
  template.render_to_file(output_path2, context2)
  puts "✓ Generated: #{output_path2}"
  puts ""
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
  puts ""
end

puts "=" * 60
puts "Test complete!"
puts "=" * 60
