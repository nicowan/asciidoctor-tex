require 'asciidoctor'
require 'asciidoctor/extensions' unless RUBY_ENGINE == 'opal'
require 'asciidoctor/latex/core_ext/colored_string'
require 'asciidoctor/latex/ent_to_uni'
require 'asciidoctor/latex/environment_block'
require 'asciidoctor/latex/node_processors'
require 'asciidoctor/latex/prepend_processor'
require 'asciidoctor/latex/macro_insert'
require 'asciidoctor/latex/tex_block'
require 'asciidoctor/latex/tex_preprocessor'
require 'asciidoctor/latex/macro_preprocessor'
require 'asciidoctor/latex/dollar'
require 'asciidoctor/latex/tex_postprocessor'
require 'asciidoctor/latex/sectnumoffset-treeprocessor'

$VERBOSE = true

module Asciidoctor::LaTeX

  class LatexEscape < Asciidoctor::Extensions::Preprocessor 
    def process document, reader
      return reader if reader.eof?
      replacement_lines = reader.read_lines.map do |line|
        #line = line.gsub('{', 'LATEXOPENBRACE')                #    "\\\\{")
        #line = line.gsub('}', 'LATEXCLOSEBRACE')               #    "\\\\}")
        #line = line.gsub("&", 'LATEXAMPERSAND')                #    "\\\\&")
        #line = line.gsub("#", 'LATEXSHARP')                    #    "\\\\#")
        #line = line.gsub("%", 'LATEXPERCENT')                  #    "\\%")
        #line = line.gsub("$", 'LATEXDOLLAR')                   #    "\\$")
        #line = line.gsub("_", 'LATEXUNDERSCORE')               #    "\\_")
        #line = line.gsub("|", 'LATEXVERTICALPIPE')             #    "\\textbar{}")
        #line = line.gsub("~", 'LATEXTILDE')                    #    "\\textasciitilde{}")
        #line = line.gsub("^", 'LATEXCIRCONFLEXE')              #    "\\textasciicircum{}")
        line
      end
      reader.unshift_lines replacement_lines
      reader
    end
  end

  class LatexUnescape < Asciidoctor::Extensions::Postprocessor 
    def process document, output
      # When writing latex commands in the target document,
      # I use some improbable UNICODE chars for curly and square braces
      # And just before giving back the converted document I convert it 
      # to the right LaTeX characters
      output = output.gsub('《', "{")
      output = output.gsub('》', "}")
      output = output.gsub('〈', "[")
      output = output.gsub('〉', "]")
    end
  end

  class Converter
    include Asciidoctor::Converter
    register_for 'latex'


    # puts "HOLA!".red

    Asciidoctor::Extensions.register do
      postprocessor EntToUni if document.basebackend? 'tex' unless document.attributes['unicode'] == 'no'
      preprocessor  LatexEscape
      postprocessor LatexUnescape

    end

    def initialize backend, opts
      super
      basebackend    'tex'
      outfilesuffix '.tex'
    end

    # FIXME: find a solution without a global variable
    $latex_environment_names = []

    def convert node, transform = nil
      case node.node_name
      when 'document';            node.tex_process  # OK
      when 'section';             node.tex_process  # OK
      when 'dlist';               node.tex_process  # OK
      when 'olist';               node.tex_process  # OK
      when 'ulist';               node.tex_process  # OK
      when 'inline_anchor';       node.tex_process  # 
      when 'inline_break';        node.tex_process  # 
      when 'inline_footnote';     node.tex_process  # 
      when 'inline_quoted';       node.tex_process  # 
      when 'inline_callout';      node.tex_process  # 
      when 'inline_indexterm';    node.tex_process  # 
      when 'admonition';          node.tex_process  # OK
      when 'listing';             node.tex_process  # 
      when 'literal';             node.tex_process  # 
      when 'page_break';          node.tex_process  # 
      when 'paragraph';           node.tex_process  # 
      when 'stem';                node.tex_process  # 
      when 'pass';                node.tex_process  # 
      when 'open';                node.tex_process  # 
      when 'quote';               node.tex_process  # 
      when 'example';             node.tex_process  # 
      when 'floating_title';      node.tex_process  # 
      when 'image';               node.tex_process  # 
      when 'preamble';            node.tex_process  # 
      when 'sidebar';             node.tex_process  # 
      when 'verse';               node.tex_process  # 
      when 'toc';                 node.tex_process  # 
      when 'table';               node.tex_process  # 
      when 'thematic_break';      warn "#{node.node_name} is not implemented"
      when 'colist';              warn "#{node.node_name} is not implemented"
      when 'embedded';            warn "#{node.node_name} is not implemented"
      when 'inline_button';       warn "#{node.node_name} is not implemented"
      when 'inline_image';        node.tex_process
      when 'inline_kbd';          warn "#{node.node_name} is not implemented"
      when 'inline_menu';         warn "#{node.node_name} is not implemented"
      when 'video';               warn "#{node.node_name} is not implemented"
      when 'audio';               warn "#{node.node_name} is not implemented"
      else
        warn %(Node to implement: #{node.node_name}, class = #{node.class}).magenta #if $VERBOSE
      end
    end
  end # class Converter
end # module Asciidoctor::LaTeX
