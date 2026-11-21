require "nokogiri"
require "rexml/document"

# Use native XPath for ordinary worksheets. Retain the original reader for
# DTD/entity documents and inputs the native parser rejects, so parser limits,
# error types and legacy XML acceptance do not change the upload contract.
class XlsxXmlDocument
  def self.parse(xml)
    document = Nokogiri::XML(xml) { |config| config.strict.nonet }
    return document unless document.internal_subset

    LegacyNode.new(REXML::Document.new(xml))
  rescue Nokogiri::XML::SyntaxError
    LegacyNode.new(REXML::Document.new(xml))
  end

  class LegacyNode
    def initialize(node)
      @node = node
    end

    def xpath(path)
      REXML::XPath.match(@node, path).map { |node| self.class.new(node) }
    end

    def at_xpath(path)
      node = REXML::XPath.first(@node, path)
      self.class.new(node) if node
    end

    def [](name)
      @node.attributes[name]
    end

    def text
      @node.is_a?(REXML::Text) ? @node.value : @node.text
    end
  end
end
