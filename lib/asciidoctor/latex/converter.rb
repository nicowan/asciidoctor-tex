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

  class Converter
    include Asciidoctor::Converter

    register_for 'latex'

    # puts "HOLA!".red

    Asciidoctor::Extensions.register do
      postprocessor EntToUni if document.basebackend? 'tex' unless document.attributes['unicode'] == 'no'
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
      when 'document';            node.tex_process  # ok
      when 'section';             node.tex_process  # ok
      when 'dlist';               node.tex_process  # ok
      when 'olist';               node.tex_process  # ok
      when 'ulist';               node.tex_process  # ok
      when 'inline_anchor';       node.tex_process  # ok
      when 'inline_break';        node.tex_process  # ok
      when 'inline_footnote';     node.tex_process  # ok
      when 'inline_quoted';       node.tex_process  # ok
      when 'inline_callout';      node.tex_process  # ok
      when 'inline_indexterm';    node.tex_process  # ok
      when 'admonition';          node.tex_process  # ok
      when 'listing';             node.tex_process  # ok
      when 'literal';             node.tex_process  # ok
      when 'page_break';          node.tex_process  # ok
      when 'paragraph';           node.tex_process  # ok
      when 'stem';                node.tex_process  # ok
      when 'pass';                node.tex_process  # ok
      when 'open';                node.tex_process  # ok
      when 'quote';               node.tex_process  # ok
      when 'example';             node.tex_process  # ok
      when 'floating_title';      node.tex_process  # ok
      when 'image';               node.tex_process  # ok
      when 'preamble';            node.tex_process  # ok
      when 'sidebar';             node.tex_process  # ok
      when 'verse';               node.tex_process  # ok
      when 'toc';                 node.tex_process  # ok
      when 'table';               node.tex_process  # ok
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
