#!/usr/bin/env ruby
require 'zip'
require 'nokogiri'
require 'fileutils'

# Fix the conditional template by converting plain text conditionals to MERGEFIELDs

template_path = 'test/Letterhead - Conditional.docx'
temp_xml = 'temp_document.xml'

puts "Fixing template: #{template_path}"

# Extract document.xml
Zip::File.open(template_path) do |zip_file|
  entry = zip_file.find_entry('word/document.xml')
  File.open(temp_xml, 'wb') { |f| f.write(entry.get_input_stream.read) }
end

# Read and parse the XML
doc = File.read(temp_xml, encoding: 'UTF-8')

# Function to create a MERGEFIELD structure
def create_mergefield(field_instruction, display_text)
  <<-XML.strip
<w:fldSimple w:instr=" MERGEFIELD #{field_instruction} \\* MERGEFORMAT ">
    <w:r>
      <w:rPr><w:noProof/><w:color w:val="auto"/></w:rPr>
      <w:t>#{display_text}</w:t>
    </w:r>
  </w:fldSimple>
XML
end

# Pattern 1: Find plain text conditional start with surrounding tags
# Look for the pattern with multiple <w:r> and <w:t> tags
start_pattern = /<w:r[^>]*><w:rPr[^>]*><w:color[^>]*\/><\/w:rPr><w:t>«<\/w:t><\/w:r><w:proofErr[^>]*\/><w:r[^>]*><w:rPr[^>]*><w:color[^>]*\/><\/w:rPr><w:t>client\.name:if<\/w:t><\/w:r><w:proofErr[^>]*\/><w:r[^>]*><w:rPr[^>]*><w:color[^>]*\/><\/w:rPr><w:t>\(client\.name == 'Fraser Mayfield'\)»<\/w:t><\/w:r>/

start_replacement = create_mergefield(
  "client.name:if(client.name == 'Fraser Mayfield')",
  "«client.name:if(client.name == 'Fraser Mayfield')»"
)

doc.gsub!(start_pattern, start_replacement)

# Pattern 2: Find plain text conditional end
end_pattern = /<w:r[^>]*><w:rPr[^>]*><w:color[^>]*\/><\/w:rPr><w:t>«<\/w:t><\/w:r><w:proofErr[^>]*\/><w:r[^>]*><w:rPr[^>]*><w:color[^>]*\/><\/w:rPr><w:t>client\.name:endIf<\/w:t><\/w:r><w:proofErr[^>]*\/><w:r[^>]*><w:rPr[^>]*><w:color[^>]*\/><\/w:rPr><w:t>»<\/w:t><\/w:r>/

end_replacement = create_mergefield(
  "client.name:endIf",
  "«client.name:endIf»"
)

doc.gsub!(end_pattern, end_replacement)

# Write back the modified XML
File.write(temp_xml, doc)

# Update the docx file with the modified document.xml
# First, copy the original file to preserve other content
temp_docx = 'temp_template.docx'
FileUtils.cp(template_path, temp_docx)

# Update only the document.xml in the archive
Zip::File.open(temp_docx) do |zip_file|
  zip_file.get_output_stream('word/document.xml') do |f|
    f.write(File.read(temp_xml))
  end
end

# Replace the original with the modified version
FileUtils.mv(temp_docx, template_path)

# Clean up
File.delete(temp_xml)

puts "✓ Template fixed successfully!"
puts "  - Converted plain text conditional markers to MERGEFIELDs"
puts "  - client.name:if(client.name == 'Fraser Mayfield') → MERGEFIELD"
puts "  - client.name:endIf → MERGEFIELD"
