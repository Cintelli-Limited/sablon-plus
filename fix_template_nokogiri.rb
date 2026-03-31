#!/usr/bin/env ruby
require 'zip'
require 'nokogiri'
require 'fileutils'

# Extract and clean up the template
template_path = 'test/Letterhead - Conditional.docx'
temp_xml = 'temp_document.xml'

# Extract document.xml
Zip::File.open(template_path) do |zip_file|
  entry = zip_file.find_entry('word/document.xml')
  File.open(temp_xml, 'wb') { |f| f.write(entry.get_input_stream.read) }
end

# Parse as Nokogiri document for easier manipulation
xml_doc = Nokogiri::XML(File.read(temp_xml))
ns = {'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

# Find and remove the old broken conditional structure
# Look for paragraphs containing client.name:if
paragraphs = xml_doc.xpath('//w:p', ns)

paragraphs.each do |para|
  text_content = para.text
  
  # If this paragraph contains the plain text conditional marker
  if text_content =~ /client\.name:if.*Fraser Mayfield/
    puts "Found conditional start paragraph"
    
    # Build a proper w:fldSimple structure
    field_instr = ' MERGEFIELD client.name:if(client.name == \'Fraser Mayfield\') \* MERGEFORMAT '
    display_text = '«client.name:if(client.name == \'Fraser Mayfield\')»'
    
    # Clear the paragraph
    para.xpath('.//w:r | .//w:fldSimple | .//w:proofErr', ns).each(&:remove)
    
    # Create new field structure
    fld_simple = Nokogiri::XML::Node.new('w:fldSimple', xml_doc)
    fld_simple['w:instr'] = field_instr
    
    run = Nokogiri::XML::Node.new('w:r', xml_doc)
    run_props = Nokogiri::XML::Node.new('w:rPr', xml_doc)
    no_proof = Nokogiri::XML::Node.new('w:noProof', xml_doc)
    color = Nokogiri::XML::Node.new('w:color', xml_doc)
    color['w:val'] = 'auto'
    
    run_props << no_proof
    run_props << color
    run << run_props
    
    text_node = Nokogiri::XML::Node.new('w:t', xml_doc)
    text_node.content = display_text
    run << text_node
    
    fld_simple << run
    para << fld_simple
    
    puts "  → Fixed conditional start"
  elsif text_content =~ /client\.name:endIf/
    puts "Found conditional end paragraph"
    
    # Build a proper w:fldSimple structure
    field_instr = ' MERGEFIELD client.name:endIf \* MERGEFORMAT '
    display_text = '«client.name:endIf»'
    
    # Clear the paragraph
    para.xpath('.//w:r | .//w:fldSimple | .//w:proofErr', ns).each(&:remove)
    
    # Create new field structure  
    fld_simple = Nokogiri::XML::Node.new('w:fldSimple', xml_doc)
    fld_simple['w:instr'] = field_instr
    
    run = Nokogiri::XML::Node.new('w:r', xml_doc)
    run_props = Nokogiri::XML::Node.new('w:rPr', xml_doc)
    no_proof = Nokogiri::XML::Node.new('w:noProof', xml_doc)
    color = Nokogiri::XML::Node.new('w:color', xml_doc)
    color['w:val'] = 'auto'
    
    run_props << no_proof
    run_props << color
    run << run_props
    
    text_node = Nokogiri::XML::Node.new('w:t', xml_doc)
    text_node.content = display_text
    run << text_node
    
    fld_simple << run
    para << fld_simple
    
    puts "  → Fixed conditional end"
  end
end

# Write back the modified XML
File.write(temp_xml, xml_doc.to_xml)

# Update the docx file
temp_docx = 'temp_template.docx'
FileUtils.cp(template_path, temp_docx)

Zip::File.open(temp_docx) do |zip_file|
  zip_file.get_output_stream('word/document.xml') do |f|
    f.write(File.read(temp_xml))
  end
end

FileUtils.mv(temp_docx, template_path)
File.delete(temp_xml)

puts "✓ Template fixed with Nokogiri!"
