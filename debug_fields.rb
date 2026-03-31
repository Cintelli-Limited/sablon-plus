#!/usr/bin/env ruby
require 'bundler/setup'
require_relative 'lib/sablon'
require 'pp'

# Debug: Check what fields are being parsed
class DebugParser
  def self.check_template
    template_path = 'test/Letterhead - Conditional.docx'
    
    # Load the template
    zip = Zip::File.open(template_path)
    entry = zip.find_entry('word/document.xml')
    xml_content = entry.get_input_stream.read
    doc = Nokogiri::XML(xml_content)
    
    # Find all MERGEFIELDs
    puts "=" * 60
    puts "All MERGEFIELD instructions in template:"
    puts "=" * 60
    
    # Look for SimpleFields (w:fldSimple)
    doc.xpath('//w:fldSimple', 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main').each do |field|
      instr = field['w:instr']
      puts "  #{instr}"
    end
    
    # Look for ComplexFields (w:instrText)
    doc.xpath('//w:instrText', 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main').each do |field|
      puts "  #{field.text}"
    end
    
    zip.close
  end
end

DebugParser.check_template
