require 'zip'
require 'nokogiri'

require "sablon_plus/version"
require "sablon_plus/configuration/configuration"

require "sablon_plus/context"
require "sablon_plus/environment"
require "sablon_plus/template"
require "sablon_plus/processor/document"
require "sablon_plus/processor/section_properties"
require "sablon_plus/parser/mail_merge"
require "sablon_plus/operations"
require "sablon_plus/html/converter"
require "sablon_plus/content"

module SablonPlus
  class TemplateError < ArgumentError; end
  class ContextError < ArgumentError; end

  def self.configure
    yield(Configuration.instance) if block_given?
  end

  def self.template(path)
    Template.new(path)
  end

  def self.content(type, *args)
    Content.make(type, *args)
  end
end
