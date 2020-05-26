require 'asciidoctor'
require 'asciidoctor/latex/core_ext/colored_string'
require 'asciidoctor/latex/core_ext/utility'
require 'htmlentities'

module TexUtilities
  def self.braces(*args)
    args.map{|arg| "《#{arg}》"}.join("")
  end

  def self.macro(name, *args)
    "\\#{name}#{braces *args}"
  end

  def self.macro_opt(name, opt, *args)
    "\\#{name}〈#{opt}〉#{braces *args}"
  end

  # tex.region('bf', 'foo bar') => {\bf foo bar}
  def self.region(name, *args)
    "《\\#{name} #{args.join(" ")}》"
  end

  def self.apply_macros(macro_list, arg)
    val = arg
    macro_list.reverse.each do |macro_name|
      val = self.macro(macro_name, val)
    end
    val
  end

  def self.begin(arg)
    macro('begin', arg)
  end

  def self.end(arg)
    macro('end', arg)
  end

  def self.env(env, *args)
    body = args.pop
    "\n#{self.begin(env)}#{braces *args}\n#{body}\n#{self.end(env)}\n"
  end

  def self.env_opt(env, opt, *args)
    body = args.pop
    "\n#{self.begin(env)}〈#{opt}〉#{braces *args}\n#{body}\n#{self.end(env)}\n"
  end

  # normalize the name because it is an id
  # and so frequently contains underscores
  def self.hypertarget(name, text)
    if text
     # text = text.rstrip.chomp
    end
    if name
      self.macro("hypertarget", name.tex_normalize, text)
      #"\\hypertarget《#{name.tex_normalize}》《#{text}》"
    else
      self.macro("hypertarget", "no-id".tex_normalize, text)
      #"\\hypertarget《'NO-ID'》《#{text}》"
      # FIXME: why do we need this branch?
    end
  end

  def self.escape(str)
    coder  = HTMLEntities.new
    str = coder.decode str
    str = str.gsub("{",     "\\{")
    str = str.gsub("}",     "\\}")
    str = str.gsub("&",     "\\\\&")
    str = str.gsub("#",     "\\\\#")
    str = str.gsub("%",     "\\%")
    str = str.gsub("$",     "\\$")
    str = str.gsub("_",     "\\_")
    #str = str.gsub("\\", "\\\\\\")  # Do not work, it duplicates \ in latex commands
    str = str.gsub("|",     "\\textbar{}")
    str = str.gsub("~",     "\\textasciitilde{}")
    str = str.gsub("^",     "\\textasciicircum{}")
  end

  def self.mathEscape(str)
    coder  = HTMLEntities.new
    result = coder.decode(str)
    result = result.gsub("{", '《')
    result = result.gsub("}", '》')
    result = result.gsub("[", '〈')
    result = result.gsub("]", '〉')
  end
end

module Process
  include Asciidoctor::Latex
  include TexUtilities
  $tex = TexUtilities

  # ---------------------------------------------------------------------------
  # Public block processing methods

  def self.document(node)
    doc = ''

    unless node.embedded? or node.document.attributes['header'] == 'no'
      doc << "% ======================================================================\n"
      doc << "% Generated by asciidoctor-latex\n"

      filePreamble = File.join(Asciidoctor::Latex::DATA_DIR, "preamble_#{node.document.doctype}.tex")
      doc << self.insertFile( filePreamble )
      doc << "\n"

      doc << "% ======================================================================\n"
      doc << "% Macros and environments for asciidoc constructs\n"

      fileCommands = File.join(Asciidoctor::Latex::DATA_DIR, 'asciidoc_tex_macros.tex')
      doc << self.insertFile( fileCommands )
      doc << "\n"

      doc << "% ======================================================================\n"
      doc << "% Front matter\n"

      doc << $tex.macro( "title",  node.doctitle) + "\n"
      doc << $tex.macro( "author", node.author)   + "\n"
      doc << $tex.macro( "date",   node.revdate)  + "\n"

      doc << "\n\n\n"
      doc << $tex.begin( "document") + "\n"

      doc << self.insertTitle(node)
      doc << self.insertTableOfContents(node)
    end

    doc << node.content
    doc << "\n"

    unless node.embedded? or node.document.attributes['header'] == 'no'
      doc << $tex.end("document") + "\n"
    end

    return doc
  end

  def self.section(node)
    # The section levels are different in book and article
    tags = {
      'article' => [ 'part', 'section', 'subsection', 'subsubsection', 'paragraph' ],
      'book'    => [ 'part', 'chapter', 'section', 'subsection', 'subsubsection', 'paragraph' ]
    }

    # Choose the section's level
    section = tags[node.document.doctype][node.level]

    # Fallback when the requested heading level does not exist
    if section == nil
      section = tags[node.document.doctype][-1];
      warn "Latex #{node.document.doctype} does not support " +
           "heading level #{node.level}, uses #{section} instead".magenta
    end

    # Add a star at the end when not numbered
    section << (node.numbered ? '' : '*')

    # Generate the section's begin, content and end
    result  = $tex.macro(section, $tex.escape(node.title)) + "\n"
    result << node.content
    #result << "% end #{section}\n"

    return result
  end

  def self.paragraph(node)
    # Paragraph title
    title   = ""
    if node.title?
      title = $tex.macro("adocMacroTitle", $tex.escape(node.title)) + "\n"
    end

    # Paragraph content with colorization
    color   = getColor(node.role)
    content = $tex.escape(node.content)
    content.strip!
    if color != ""
      content = $tex.macro($colors[color], content)
    end

    # Text alignment (left, right, center, justify)
    alignement = getAlignment(node.role)
    if alignement != ""
      content = $tex.env($alignments[alignement], content)
    end

    # Add an anchor if an id is given
    anchor = ""
    anchor = $tex.macro('hypertarget', node.id, "") if node.id

    return "#{anchor}#{title}#{content}\n\n"
  end

  def self.ulist(node)
    return $tex.env("itemize", self.listItems(node))
  end

  def self.olist(node)
    return $tex.env("itemize", self.listItems(node))
  end

  def self.dlist(node)
    result = ""
    node.items.each do |terms, item|
      content = ""
      content << $tex.escape(item.text)    if item.text?
      content << $tex.escape(item.content) if item.blocks?
      result  << $tex.macro_opt("item", terms.map { |one| one.text }.join("")) + "\n#{content}\n"
    end
    result.strip!
    return $tex.env("description", result)
  end

  def self.pageBreak(node)
    return "\n#{$tex.macro('newpage')}\n"
  end

  def self.stem(node)
    return "\n\\[#{node.content}\\]\n"
  end

  def self.admonition(node)
    # Block contents are already escaped, inline contents not
    content = node.blocks? ? node.content : $tex.escape(node.content)
    content.strip!
    return $tex.env("adocEnvAdmonition", node.style, content)
  end

  def self.blockImage(node)
    # TODO: Manage alignment left, right, center
    # TODO: Manage text flow (WrapFigure)
    result = ""

    if node.title
      result  = $tex.macro("centering")
      result << "#{self.includeGraphics(node)}\n"
      result << "#{$tex.macro("caption", node.title)}"
      result =  $tex.env_opt("figure", "ht", result)
    else
      result =  $tex.env("center", self.includeGraphics(node))
    end

    return result
  end

  def self.listing(node)
    # TODO: linenos, linenumbers
    # TODO: only include the needed converter
    # TODO: translate language names between converters
    result = ""
    language = node.attributes['language']
    language = "text" if language == nil or language == ""

    case node.document.attributes['source-highlighter']
      when "pygment"
        result << $tex.env("minted", language, node.content)
  
      when "lstlisting"
        options = "frame = single, language=#{language}"
        result << $tex.env_opt("lstlisting", options, node.content)

      else
        result << $tex.env("verbatim", node.content)
    end

    return result
  end

  def self.literal(node)
    if node.title
      result = $tex.macro("adocMacroTitle", node.title)
      if node.id
        result = $tex.hypertarget(node.id, result)
      end
    else
      result = ""
    end
    result << $tex.env("verbatim", node.content)
  end

  def self.quote(node)
    # TODO: Split attribution using coma
    content = node.content
    content.strip!
    return $tex.env('adocEnvQuote', node.attr('title'), node.attr('attribution'), content)
  end

  def self.verse(node)
    # TODO: Split attribution using coma
    content = node.content
    content.strip!
    content = content.gsub("\n", "\n\n")
    return $tex.env('adocEnvVerse', node.attr('title'), node.attr('attribution'), content)
  end



  def self.pass(node)
    puts "pass block"
    node.content
  end



  # ---------------------------------------------------------------------------
  # Public inline processing methods

  def self.inlineQuoted(node)
    result = ""

    case node.type
      when :monospaced
        if node.text.include? Asciidoctor::Substitutors::PASS_START
          # This is a passthrough text, use verbatim in latex
          # TODO: The braces are still escaped how to unescape them
          # TODO: Analyze the passtrough text to find an appropriate delimiter for the verb command
          #       where can I get a copy of the referenced text?
          result = "\\verb€#{node.text}€"
        else
          # This is a simple monotype text
          result = $tex.macro("texttt", node.text)
        end

      when :emphasis
        result = $tex.macro("textit", node.text)

      when :strong
        result = $tex.macro("textbf", node.text)

      when :double
        result = "``#{node.text}''"

      when :single
        result = "`#{node.text}'"

      when :mark
        result = $tex.macro("colorbox", "yellow", node.text)

      when :superscript
        result = $tex.macro("textsuperscript", node.text)

      when :subscript
        result = $tex.macro("textsubscript", node.text)

      when :asciimath
        warn "#{node.type} not suported in LaTeX backend".red
        result = "\\verb€#{node.text}€"

      when :latexmath
        # TODO: Is it possible to add the node.text to the passthrough 
        result = $tex.mathEscape(node.text)
        result = "\\( #{result} \\)"

      when :unquoted
        # TODO: look in the original asciidoctor for inline roles
        # TODO: Generate macros for each unknown role in the document
        color  = getColor(node.role)
        result = node.text
        result = $tex.macro($colors[color], result) if color != ""

        # In Asciidoctor, :literal type seems to be used only in block node
      #when :literal
      #  result = $tex.macro("texttt", node.text)

      # In Asciidoctor, :verse type seems to be used only in block node
      #when :verse
      #  result = $tex.macro("texttt", node.text)

    else
        warn "Unknown node type #{node.type}".magenta
        result = node.text
    end

    return result
  end

  def self.inlineImage(node)
    return self.includeGraphics(node)
  end
  
  def self.inlineAnchor(node)
    case node.type
      when :xref
        # Not sure I will implement this in the LaTeX backend because for me
        # it is useless to link to title with the title content what hapens when 
        # the title text changes???
        $tex.macro('hyperlink', node.target.tex_normalize, node.text || node.attributes['path'] || "")

      when :link
        target = node.target
        # TODO Improve the external URL detection
        if target.include? "http:" or target.include? "https:"
          $tex.macro('href', target, node.text)
        else
          $tex.macro('hyperlink', node.target.tex_normalize, node.text)
        end

      when :ref
        $tex.hypertarget(node.id, "")

      when :bibref
        $tex.hypertarget(node.id, (node.reftext || node.id))

      else
        warn %(unknown anchor type: #{node.type.inspect})
        nil
    end
  end

  def self.inlineBreak(node)
    # Forces line break in a paragraph
    "#{node.text} \\\\"
  end

  def self.inlineFootNote(node)
    $tex.macro('footnote', self.text)
  end

  def self.inlineIndexTerm(node)
    case self.type
      when :visible
        return "#{$tex.macro('index', node.text)}#{node.text}"
      else
        return "#{$tex.macro('index', self.attributes['terms'].join('!'))}"
      end
  end

  def self.inlineButton(node)
    return $tex.macro("adocMacroBtn", $tex.escape(node.text))
  end

  def self.inlineKeyboard(node)
    separator = " + "
    items = []
    node.attr('keys').each { |one|
      items.push($tex.macro("adocMacroKbd", $tex.escape(one)))
    }
    return items.join(" #{separator} ")
  end

  def self.inlineMenu(node)
    # Needs to define the macro adocMacroNextItem with the 
    # symbol that is used to show the next item in the menu
    separator = $tex.macro("adocMacroNextItem")
    items = []

    items.push($tex.macro("adocMacroMenu", node.attr('menu')))
    node.attr('submenus').each { |one|
      items.push($tex.macro("adocMacroMenu", one))
    }
    items.push($tex.macro("adocMacroMenu", node.attr('menuitem')))

    return items.join(" #{separator} ")
  end






  # ---------------------------------------------------------------------------
  # Private variables and methods
  private

  $colors = {
    'red'    => "colorRed",
    'blue'   => "colorBlue",
    'green'  => "colorGreen",
    'yellow' => "colorYellow"
  }

  $alignments = {
    "text-left"   => "flushright",
    "text-right"  => "flushright",
    "text-center" => "center"
  }

  def self.getColor(role)
    result = ""
    if role != nil
      role.split.each { |item| result = item if $colors.include?(item) }
    end
    return result
  end

  def self.getAlignment(role)
    result = ""
    if role != nil
      role.split.each { |item| result = item if $alignments.include?(item) }
    end
    return result
  end

  def self.insertTitle(node)
    result = ""
    result << $tex.macro("maketitle") if node.attributes['notitle'] == nil
    return "#{result}\n"
  end

  def self.insertTableOfContents(node)
    result = ""
    result << $tex.macro("tableofcontents") if node.attributes['toc'] != nil
    return "#{result}\n"
  end

  def self.insertFile(fileName)
    result = ""
    result << File.open(fileName, 'r') { |f| f.read }
  end

  def self.listItems(node)
    result = ""
    node.content.each do |item|
      content =  $tex.escape(item.text)    if item.text?
      content << $tex.escape(item.content) if item.blocks?
      content.strip!
      result  << "#{$tex.macro("item")} #{content} \n"
    end
    result.strip!
    return result
  end

  def self.getImageWidth(node)
    if node.attributes['width']
      width = node.attributes['width']
      if width.include?("mm")
        width = "#{width.to_f}mm"
      elsif width.include?("cm")
        width = "#{width.to_f}cm"
      elsif width.include?("in")
        width = "#{width.to_f}in"
      elsif width.include?("%")
        width = "#{width.to_f/100}\\textwidth"
      else
        width = '\textwidth'
      end
    else
      width = '\textwidth'
    end
    return width
  end

  def self.getImageFile(node)
    filename = node.attributes['target']
    filename = node.target if filename == nil
    return node.image_uri(filename)
  end

  def self.includeGraphics(node)
    width = getImageWidth(node)
    filename = getImageFile(node)
    return $tex.macro_opt("includegraphics", "width=#{width}", filename)
  end
end # module Process


# Yuuk!, The classes in node_processor implement the
# latex backend for Asciidoctor-latex.  This
# module is far from complete.
module Asciidoctor

  include TexUtilities
  $tex = TexUtilities

  # Proces block elements of varios kinds
  class Block

    # STANDARD_ENVIRONMENT_NAMES = %w(theorem proposition lemma definition example problem equation)
    STANDARD_ENVIRONMENT_NAMES = %w(equation)

    def tex_process
      case self.blockname


      when :open
        self.open_process
      when :example
        self.example_process
      when :floating_title
        self.floating_title_process
      when :preamble
        self.preamble_process
      when :sidebar
        self.sidebar_process
      when :toc
        self.toc_process
      else
        # warn "This is Asciidoctor::Block, tex_process.  I don't know how to do that (#{self.blockname})" if $VERBOSE if $VERBOSE
        ""
      end
    end




    ####################################################################

    def label
      if self.id
        label = $tex.macro 'label', self.id
        # label = $tex.macro 'label', $tex.hypertarget(self.id, self.id)
      else
        label = ""
      end
      label
    end

    def options
      self.attributes['options']
    end

    def env_title
      if self.attributes['original_title']
        "《\\rm (#{self.attributes['original_title']}) 》"
      else
        ''
      end
    end

    ####################################################################

    def label_line
      if label == ""
        ""
      else
        label + "\n"
      end
    end

    ####################################################################

    def toc_process
      if document.attributes['toc-placement'] == 'macro'
        $tex.macro 'tableofcontents'
      end
      # warn "Please implement me! (toc_process)".red if $VERBOSE
    end

    # Process open blocks.  Map a block of the form
    #
    # .Foo
    # [[hocus_pocus]]
    # --
    # La di dah
    # --
    #
    # to
    #
    # \begin{Foo}
    # \label{hocus_pocus}
    # La di dah
    # \end{Foo}
    #
    # This scheme enables one to map Asciidoc blocks to
    # LaTeX environments with essentally no knoweldge
    # of either other than their form.
    #
    def open_process

      attr = self.attributes

      # Get title !- nil or make a dummy one
      title = self.title? ? self.title : 'Dummy'

      # strip constructs like {counter:theorem} from the title
      title = title.gsub /\{.*?\}/, ""
      title = title.strip

      if attr['role'] == 'text-center'
        $tex.env 'center', self.content
      else
        self.content
      end

    end

    def example_process
      id = self.attributes['id']
      if self.title
        heading = $tex.region 'bf', self.title
        content  = "-- #{heading}.\n#{self.content}"
      else
        content = self.content
      end
      if id
        hypertarget = $tex.hypertarget id, self.content.split("\n")[0]
        content = "#{hypertarget}\n#{content}" if id
      end
      $tex.env 'example', content
    end


    def floating_title_process
      doctype = self.document.doctype

      tags = { 'article' => [ 'part',  'section', 'subsection', 'subsubsection', 'paragraph' ],
               'book' => [ 'part', 'chapter', 'section', 'subsection', 'subsubsection', 'paragraph' ] }

      tagname = tags[doctype][self.level]

      "\\#{tagname}*《#{self.title}》\n\n#{self.content}\n\n"
    end

    def preamble_process
      # "\\begin《preamble》\n%% HO HO HO!\n#{self.content}\n\\end《preamble》\n"
      self.content
    end


    def sidebar_process
      title = self.title
      attr = self.attributes
      id = attr['id']
      if id
        content = "\\hypertarget《#{id}》《#{self.content.rstrip}》"
      else
        content = self.content
      end
      if title
        title  = $tex.env 'bf', title
        $tex.env 'sidebar', "#{title}\n#{content.rstrip}"
      else
        $tex.env 'sidebar', content
      end
    end

  end # class Block

  class Table
    def get_cell_content(the_cell)
      
      if Array === the_cell.content
        # The content has not been "parsed", must escape special chars
        result = $tex.escape the_cell.content.join("\n")
      else
        # The content is already parsed, just copy it
        result = the_cell.content
      end
    end

    def multicol(width, fmt, content)
      if width.nil? || (width == 1)
        content
      else
        "\\multicolumn《#{width}》《#{fmt}》《#{content}》"
      end
    end

    def multirow(height, width, content)
      if height.nil? || (height == 1)
        content
      else
        "\\multirow《#{height}》《#{width}》《#{content}》"
      end
    end

    def debug_cell(cell)
      output = ""
      if cell.rowspan.nil?
        output << "rowspan = 1 "
      else
        output << "rowspan = #{cell.rowspan} "
      end

      if cell.colspan.nil?
        output << "colspan = 1 "
      else
        output << "colspan = #{cell.colspan} "
      end
  
      puts "#{output} " + self.get_cell_content(cell)
    end

    def get_table_width()
      table_width = 0
      self.columns.each do |onecol|
        table_width += onecol.attributes['width']
      end
      table_width
    end

    def get_columns_header(table_width)
      # DANGER HACK BY Nico
      # My LaTeX installation adds 0.4cm for each column which is 
      # about 2.5% of the page width (17cm in my template) so I
      # reduce the column width by 2.5cm each
      reduction = 0.025
      alignment = []
      self.columns.each do |onecol|
        width = onecol.attributes['width'].to_f / table_width - reduction
        width = width.round(3)
        alignment << "m{#{width}\\textwidth}"
      end
      alignment
    end

    def fill_array(the_array, x, y, dx, dy)
      maxY = y + dy
      maxX = x + dx
      sy   = y
      while y < maxY do
        tx = x
        while tx < maxX do
          # put 0 on the 1st line and put 1 on other lines
          if (y == sy)
            the_array[y][tx] = 0
          else
            the_array[y][tx] = ((x == tx) ? dx : 0)
          end
          tx = tx + 1
        end
        y = y + 1
      end
    end

    def tex_process_buggy_borders
      #-------------------------------------------------------------------------
      # NICOLAS TABLE LATEX
      # self.columns[0].attributes[] colnumber, width, halign, valign
      table_width = self.get_table_width()
      alignment = self.get_columns_header(table_width.to_f)
      alignment = alignment.join('|')

      output  = "\\begin《center》\n"
      output << "\\begin《tabular》《|#{alignment}|》\n"
      output << "\\hline\n"

      cols_nb = self.columns.count
      rows_nb = self.rows.body.count
      output_array = Array.new(rows_nb) { Array.new(cols_nb, 0)}

      # For each line in the table
      self.rows.body.each_with_index do |row, rowIdx|
        # Start in cell 0
        idx = 0

        row.each do |cell|
          while output_array[rowIdx][idx] != 0 do
            idx = idx + 1
          end

          rs = (cell.rowspan.nil? ? 1 : cell.rowspan);
          cs = (cell.colspan.nil? ? 1 : cell.colspan);
          self.fill_array(output_array, idx, rowIdx, cs, rs)
          output_array[rowIdx][idx] = cell
          idx += cs
        end # each cell in row

      end # each row in table

      output_array.each_with_index do |row, y|
        row_array = []
        rules = ""
        row.each_with_index do |cell, idx|
          if cell.is_a? Integer
            if cell == 0
              # skip the cell, because au colspan
            else
              # Empty cell because of rowspan
              row_array << self.multicol(cell, "|c|", " ")
            end
          else
            content = self.get_cell_content(cell)
            content = self.multirow(cell.rowspan, "*", content)
            row_array << self.multicol(cell.colspan, "|c|", content)
          end

          if output_array[y+1].nil?
            rules << "\\cline《#{idx+1}-#{idx+1}》 "
          else
            if output_array[y+1][idx].is_a? Integer
              if output_array[y+1][idx] == 0
                # skip the cell, because au colspan
                rules << "\\cline《#{idx+1}-#{idx+1}》 "
              end
            else
              rules << "\\cline《#{idx+1}-#{idx+1}》 "
            end
          end
        end

        output << row_array.join(" & \n")
        output << "\\\\"
        output << rules            #output << "\\hline"
        output << "\n\n"
      end

      output << "\\hline\n"
      output << "\\end{tabular}\n"
      output << "\\end{center}\n"
      "#{output}"
      #-------------------------------------------------------------------------
    end

    def tex_process
      #-------------------------------------------------------------------------
      # self.columns[0].attributes[] colnumber, width, halign, valign
      table_width = self.get_table_width()
      alignment = self.get_columns_header(table_width.to_f)
      alignment = alignment.join('|')

      output  = "\\begin《center》\n"
      output << "\\begin《tabular》《|#{alignment}|》\n"
      output << "\\hline\n"

      cols_nb  = self.columns.count
      rows_nb  = self.rows.body.count
      rowsinfo = Array.new(cols_nb) { "1/1"}   # RowSpan/ColSpan

      # For each line in the table
      self.rows.body.each_with_index do |row, y|
        row_array = []
        borders = ""
        x = 0

        # Foreach Cells in Row
        row.each do |cell|
          # Extract info from previous row
          old = rowsinfo[x].split('/')
          ors = old[0].to_i
          ocs = old[1].to_i

          # Previous row spans down
          if ors > 1
            ors -= 1
            rowsinfo[x] = "#{ors}/#{ocs}"
            row_array << self.multicol(ocs, "|c|", ' ') # Empty cell
            if ors == 1
              borders << "\\cline《#{x+1}-#{x+ocs}》 "
            end
            x += ocs   # Compute next cell x position (skip spanned columns)
          end

          # Current cell's span information
          rs = (cell.rowspan.nil? ? 1 : cell.rowspan);
          cs = (cell.colspan.nil? ? 1 : cell.colspan);

          # Add content to latex result
          content = self.get_cell_content(cell)
          content = self.multirow(rs, "*", content)
          row_array << self.multicol(cs, "|c|", content)

          # Save current cell info for the next row
          rowsinfo[x] = "#{rs}/#{cs}"
          if rs == 1
            borders << "\\cline《#{x+1}-#{x+cs}》 "
          end
          x += cs
        end # Foreach Cells in Row

        output << row_array.join(" & \n")
        output << " \\\\"
        output << " #{borders}"            #output << "\\hline"
        output << "\n\n"

      end # Foreach Rows in Table

      output << "\\hline\n"
      output << "\\end{tabular}\n"
      output << "\\end{center}\n"
      "#{output}"
      #-------------------------------------------------------------------------
    end
  end
end
