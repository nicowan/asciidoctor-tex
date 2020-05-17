require 'asciidoctor'
require 'asciidoctor/extensions'
require 'htmlentities'

# Map HTML entties to their unicode equivalents
# before running LaTeX
#
module Asciidoctor::Latex
  class EntToUni < Asciidoctor::Extensions::Postprocessor

    def process document, output

      #puts "========================================================================"
      #puts "BEFORE ================================================================="
      #puts output

      coder  = HTMLEntities.new
      result = coder.decode output

      #puts "========================================================================"
      #puts "AFTER ================================================================="
      #puts result

      result
    end

  end
end
