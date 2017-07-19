require "nokogiri"

class Validate_XML

def initialize(ea_xml)
@ea_xml = Nokogiri::XML(ea_xml)
end

def check_syntax_error
	@syntax_error = []
	if @ea_xml.errors.any?
		@ea_xml.errors.each do |error|
			if error.fatal?
				@syntax_error << error.message
			end
		end
	end
	@syntax_error
end


def get_syntax_error_message
check_syntax_error.join("\n")
end


def check_warnings
	@warnings = []
	if @ea_xml.errors.any?
		@ea_xml.errors.each do |error|
			if error.warning?
				@warnings << error.message
			end
		end
	end
	@warnings
end


def validate
	puts check_syntax_error.join("\n")
    puts check_warnings.join("\n")
end


end


# x = File.read("/Users/venumadhavdondapati/workspace/arbitrage_requirements/ea_core_testcases/ea_original.xml")
# Validate_EA.new(x).validate



# def validate(document_path, schema_path, root_element)
#   schema = Nokogiri::XML::Schema(File.read(schema_path))
#   document = Nokogiri::XML(File.read(document_path))
#   schema.validate(document.xpath("//#{root_element}").to_s)
# end

# validate('input.xml', 'schema.xdf', 'container').each do |error|
#   puts error.message
# end