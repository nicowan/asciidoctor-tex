require 'asciidoctor'
require 'htmlentities'

module TexUtilities
  @definitions = {}

  def self.braces(*args)
    args.map{|arg| "《#{arg}》"}.join("")
  end

  def self.macro(name, *args)
    pushMacro(name, args.length)
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
    # args array contains the environment's body which is not an argument -> decrement
    pushEnv(env, args.length - 1)
    body = args.pop
    "\n#{self.begin(env)}#{braces *args}\n#{body}\n#{self.end(env)}\n"
  end

  def self.env_opt(env, opt, *args)
    # Do not support custom environment with optional args
    body = args.pop
    "\n#{self.begin(env)}〈#{opt}〉#{braces *args}\n#{body}\n#{self.end(env)}\n"
  end

  # map '_' to '-' and prefix by 'x' if the leading character is '-'
  def self.normalize(str)
    str = str.gsub('#', '')
    str = str.gsub('_', '-')
    if str[0] == '-'
      'x'+str
    else
      str
    end
  end

  # normalize the name because it is an id
  # and so frequently contains underscores
  def self.hypertarget(name, text)
    if name
      self.macro("adocTarget", $tex.normalize(name), text)
    else
      # FIXME: why do we need this branch?
      self.macro("adocTarget", "no-id", text)
    end
  end

  def self.escape(str)
    coder  = HTMLEntities.new
    str = coder.decode str
    # TODO: Use a special char for \ in latex commands
    #str = str.gsub("\\",    macro("adocMacroBackslash",  ""))  # Does not work, it escapes the latex commands
    str = str.gsub("{",     macro("adocMacroOpenBrace",  ""))
    str = str.gsub("}",     macro("adocMacroCloseBrace", ""))
    str = str.gsub("&",     macro("adocMacroAmperAnd",   ""))
    str = str.gsub("#",     macro("adocMacroSharp",      ""))
    str = str.gsub("%",     macro("adocMacroPercent",    ""))
    str = str.gsub("$",     macro("adocMacroDollar",     ""))
    str = str.gsub("_",     macro("adocMacroUnderscore", ""))
    str = str.gsub("|",     macro("textbar",              ""))
    str = str.gsub("~",     macro("textasciitilde",       ""))
    str = str.gsub("^",     macro("textasciicircum",      ""))
  end

  def self.mathEscape(str)
    coder  = HTMLEntities.new
    result = coder.decode(str)
    result = result.gsub("{", '《')
    result = result.gsub("}", '》')
    result = result.gsub("[", '〈')
    result = result.gsub("]", '〉')
  end

  def self.definedMacro(name)
    if name.start_with?("adocMacro") || name.start_with?("adocEnv")
      if @definitions[name] != nil
        @definitions[name]['defined'] = true
      end
    end
  end

  def self.pushMacro(envName, argCount)
    # only push custom macros (starting with adocMacro)
    if envName.start_with?("adocMacro")
      @definitions[envName] = {
        'type'     => 'macro',
        'defined'  => false,
        'argCount' => argCount,
        'optCount' => 0
      }
    end
  end

  def self.pushEnv(envName, argCount)
    # only push custom environments (starting with adocEnv)
    if envName.start_with?("adocEnv")
      @definitions[envName] = {
        'type'     => 'environment',
        'defined'  => false,
        'argCount' => argCount,
        'optCount' => 0
      }
    end
  end

  # Write the LaTeX code to define a custom environment with several parameters
  def self.writeNewEnvironment(envName, paramCount)
    paramValue = "% latex macros before env content\n"
    (1..paramCount).each { |idx| paramValue += "##{idx}\n\n"}

    result =  "% Dummy environment for #{envName} should be overridden in template\n"
    result << "\\ifdefined \\#{envName} \\else \n"
    result << "\\newenvironment#{self.braces(envName)}"
    result << "〈#{paramCount}〉" if paramCount > 0
    result << "\n"
    result << "#{self.braces(paramValue)}\n"
    result << "#{self.braces("% latex macros after  env content\n")}\n"

    result << "\\fi \n\n"
    return result
  end

  # Write the LaTeX code to define a custom command with several parameters
  def self.writeNewCommand(envName, paramCount)
    paramValue = ""
    (1..paramCount).each { |idx| paramValue += "##{idx} "}

    result =  "% Dummy environment for #{envName} should be overridden in template\n"
    result << "\\ifdefined \\#{envName} \\else \n"
    result << "\\newcommand#{self.braces("\\" + envName)}"
    result << "〈#{paramCount}〉" if paramCount > 0
    result << "#{self.braces(paramValue)}\n"

    result << "\\fi \n\n"
    return result
  end

  # Generate the liste of dummy definition for each environments use in the document
  def self.writeEnvironmentDefinition()
    result =  "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n"
    result << "% Automatic generation of environments definition \n"
    result << "% These environments should be defined in your template \n"
    result << "% To get the better typesetting results\n\n"

    @definitions.each do |key, value|
      # TODO: Scan the command.tex file from the template to detect undefined macros / env

      unless value['defined']
        if value['type'] == 'macro'
          result << writeNewCommand(key, value['argCount'])
        else
          result << writeNewEnvironment(key, value['argCount'])
        end

        result << "\n"
      end
    end

    return result
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

    # Convert the content before processing the latex structure because we need
    # a list of the used environments 
    content = node.content

    unless node.embedded? or node.document.attributes['header'] == 'no'
      doc << "% ======================================================================\n"
      doc << "% Generated by asciidoctor-latex\n"

      # Select the template directory (custom or default)
      templateDir = node.document.attributes['latextemplate']
      templateDir = Asciidoctor::Latex::DATA_DIR if templateDir.nil?

      # Select the imagesdir (document's dir or the specified one)
      imagesDir = node.document.attributes['imagesdir']
      imagesDir = "." if imagesDir.nil?

      # Include the latex preamble (all the stuff before \begin{document})      
      filePreamble = File.join(templateDir, "#{node.document.doctype}.tex")
      doc << self.insertFile( filePreamble )
      doc << "\n"

      fileCommands = File.join(templateDir, 'commands.tex')
      doc << self.insertFile( fileCommands )
      doc << "\n"

      doc << "% ======================================================================\n"
      doc << "% Document's informations \n"

      doc << $tex.macro( "title",  node.doctitle) + "\n"
      doc << $tex.macro( "author", node.author)   + "\n"
      doc << $tex.macro( "date",   node.revdate)  + "\n"

      self.extractDefinedCommands(doc)

      doc << "\n"
      doc << $tex.writeEnvironmentDefinition()

      # Add the search path for the images for the document and for the template
      doc << "% ======================================================================\n"
      doc << "% Use template directory as image sources\n"
      doc << "#{$tex.macro("makeatletter")}\n"
      doc << "#{$tex.macro("g@addto@macro")}#{$tex.macro("Ginput@path", $tex.braces("#{imagesDir}/"))}\n"
      doc << "#{$tex.macro("g@addto@macro")}#{$tex.macro("Ginput@path", $tex.braces("#{templateDir}/"))}\n"
      doc << "#{$tex.macro("g@addto@macro")}#{$tex.macro("Ginput@path", $tex.braces("#{templateDir}/images/"))}\n"
      doc << "#{$tex.macro("makeatother")}\n"
      doc << "\n"

      doc << "\n\n\n"
      doc << $tex.begin( "document") + "\n"

      doc << self.insertTitle(node)
      doc << self.insertTableOfContents(node)
    end

    doc << content
    doc << "\n"

    unless node.embedded? or node.document.attributes['header'] == 'no'
      doc << $tex.end("document") + "\n"
    end

    return doc
  end

  def self.extractDefinedCommands(doc)
    pattern = /\\newcommand\{\\(.*?)\}/
    doc.scan(pattern) do |match|
      $tex.definedMacro(match[0])
    end

    pattern = /\\newenvironment\{(.*?)\}/
    doc.scan(pattern) do |match|
      $tex.definedMacro(match[0])
    end
  end

  def self.section(node)
    tocentry = "";

    # Choose the section's level
    section = $headings[node.document.doctype][node.level].dup

    # Fallback when the requested heading level does not exist
    if section == nil
      section = $headings[node.document.doctype][-1].dup;
      warn "Latex #{node.document.doctype} does not support " +
          "heading level #{node.level}, uses #{section} instead"
    end

    if section == 'frame'
      # Generate the section's begin, content and end
      result  = $tex.env_opt(section, "fragile", $tex.escape(node.title), node.content)
    else
      unless node.document.attributes["sectnums"]
        # Add the entry in the table of content 
        tocentry = $tex.macro("addcontentsline", "toc", section, $tex.escape(node.title)) + "\n"
        # Add a star at the end when not numbered
        section << "*" 
      end

      # Add an anchor if an id is given
      anchor = ""
      anchor = $tex.hypertarget($tex.normalize(node.id), "") if node.id

      # Generate the section's begin, content and end
      result  = anchor
      result << $tex.macro(section, $tex.escape(node.title)) + "\n"
      result << tocentry
      result << node.content
      #result << "% end #{section}\n"
    end

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
    anchor = $tex.hypertarget(node.id, "") if node.id

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
      when "pygments"
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

  def self.floatingTitle(node)
    # Choose the section's level
    section = $headings[node.document.doctype][node.level].dup

    # Fallback when the requested heading level does not exist
    if section == nil
      section = $headings[node.document.doctype][-1].dup;
      warn "Latex #{node.document.doctype} does not support " +
           "heading level #{node.level}, uses #{section} instead"
    end
    section << "*" 
    result  = $tex.macro(section, $tex.escape(node.title)) + "\n"
    return result
  end

  def self.open(node)
    # An open block is a generic block in asciidoctor.
    # Asciidoctor detect known block type and calls directly the right "converter"
    # It is mapped to a custom latex environment that must be defined in the template

    # TODO: Should we interprets the role attribute here? center, blue, red, ... ???

    # The block title
    title = ""
    title = $tex.escape(node.title) if node.title?

    # BlockType
    blockType = ""
    blockType = node.attributes['style'] if node.attributes['style'] != nil
    blockType = "adocEnv#{blockType.capitalize()}"

    # Stripped content
    content = node.content
    content.strip!

    return $tex.env( blockType, title, content)
  end

  def self.sidebar(node)
    # Works the same way as openblocks but with fixed environment name
    # TODO: Should we interprets the role attribute here? center, blue, red, ... ???

    # The block title
    title = ""
    title = $tex.escape(node.title) if node.title?

    # Stripped content
    content = node.content
    content.strip!

    return $tex.env( "adocEnvSidebar", title, content)
  end

  def self.example(node)
    # Works the same way as openblocks but with fixed environment name
    # TODO: Should we interprets the role attribute here? center, blue, red, ... ???

    # The block title
    title = ""
    title = $tex.escape(node.title) if node.title?

    # Stripped content
    content = node.content
    content.strip!

    return $tex.env( "adocEnvExample", title, content)
  end

  def self.preamble(node)
    # The preamble is the text between the title and the first heading

    # Stripped content
    content = node.content
    content.strip!

    return $tex.env( "adocEnvPreamble", content)
  end

  def self.toc(node)
    # Should be called when asciidoc file contains "toc::[]" somewhere in the document
    # and the :toc: variable is set to 'macro'
    if node.document.attributes['toc-placement'] == 'macro'
      $tex.macro('tableofcontents')
    end
  end





  # ---------------------------------------------------------------------------
  # Table export

  def self.table(node)
    result = ""

    # Manage stripes
    striped = (node.attributes['stripes'] == 'odd') || (node.attributes['stripes'] == 'even')

    grid  = !(node.attributes['grid']  == "none")
    # TODO: Manage frame = topbot, sides
    frame = !(node.attributes['frame'] == "none")

    #  Create an array with the columns width in ratio
    columns = self.createColumns(node)

    # Create a 2D array wit all cells
    table = self.tableCreateData(node, columns)
    debugTable(table)

    result  = ""
    oddLine = true

    table.each_with_index do |row, y|
        txtCell   = []
        txtBorder = []

        row.each_with_index do |cell, x|
          txtCell   << cell.getContent(grid, frame)
          txtBorder << cell.getBorder(grid, frame)
        end # each cell

        # Remove nil cells
        txtCell   = txtCell.filter_map{   |cell| cell unless cell.nil?}
        txtBorder = txtBorder.filter_map{ |cell| cell unless cell.nil?}

        if row[0].heading == :head
          background = "#{$tex.macro('adocMacroTableHeadBack')}\n"
        elsif row[0].heading == :foot
          background = "#{$tex.macro('adocMacroTableFootBack')}\n"
        else
          if striped
            background = "#{$tex.macro('adocMacroTableOddBack')}\n"  if oddLine
            background = "#{$tex.macro('adocMacroTableEvenBack')}\n" unless oddLine
            oddLine = !oddLine
          end
        end

        # Prints the result
        result << "#{background}#{txtCell.join(" &\n")} \\\\ \n#{txtBorder.join(" ")} \n"
    end # each row

    result = "\\hline\n#{result}\\hline\n" if frame
    result = $tex.env("tabular", self.tableColumnsSpec(node), result)
    result = $tex.env("center", result)
    return result
  end

  def self.createColumns(table)
    # The table width as specified in the markup
    sumOfWidth = 0.0
    table.columns.each{ |col| sumOfWidth += col.attributes['width'].to_f }

    # The table width as in the width attribute (in percent)
    tableWidth = table.attributes['width']
    if tableWidth != nil and tableWidth.include?("%")
      tableWidth = tableWidth.to_f
    else
      tableWidth = 100
    end

    # The variable colSpacing represents the spacing between columns that LaTeX introduces
    # The main problem is that the exact value is not known and is an absolute value
    # For MY basic template it is about 2.5% of a A4 portrait paper
    colSpacing = 0.025

    # The columns array represents the column width in percent of the textwidth
    result = []
    table.columns.each{ |col|
      colWidth = col.attributes['width'].to_f / sumOfWidth - colSpacing
      colWidth = 0.05 if colWidth < 0
      colWidth = colWidth * tableWidth / 100
      result << colWidth.round(5)
    }

    return result
  end

  def self.tableCreateData(node, columns)
    totalLines = node.rows.head.count + node.rows.body.count + node.rows.foot.count

    tabular = Array.new(totalLines) {
      Array.new(node.columns.count, nil)
    }

    y = 0

    # For each section in table do
    node.rows.to_h.each do |tsec, rows|
      next if rows.empty?

      # For each rows in the section do ...
      rows.each do |row|
        trueX = 0

        # For each cell in the row do ...
        row.each do |cell|
          # Skip rowspanned cells
          while tabular[y][trueX] != nil
            trueX += 1
          end

          data = LatexCell.new(cell, tsec)
          trueX = data.fillArray(tabular, trueX, y, columns)
        end # for each cells
        # Count the rows in the table
        y += 1
      end # for each rows

    end # for each section
    return tabular
  end

  def self.tableColumnsSpec(table)
    result = ""
    table.columns.each{ |col| result << "c" }
    return result
  end

  def self.tableAlignH(column)
    case column.attributes['halign']
      when 'right';  return "<{\\raggedleft}"
      when 'center'; return "<{\\centering}"
      else           return ""
    end
  end

  class LatexCell
    attr_accessor :rowspan, :colspan, :repeated, :content, :x, :y, :width, :halign, :valign, :maxX, :maxY, :heading

    def initialize(node, heading)
      self.rowspan  = node.rowspan.nil? ? 1 : node.rowspan;
      self.colspan  = node.colspan.nil? ? 1 : node.colspan;
      self.content  = node.content
      self.content  = self.content.join(" ") if self.content.kind_of?(Array)
      self.content  = $tex.escape(self.content)
      self.halign   = node.attributes['halign']
      self.valign   = node.attributes['valign']
      self.repeated = false
      self.width = 0
      self.x = 0
      self.y = 0
      self.maxY = node.parent.parent.rows.head.count + 
                  node.parent.parent.rows.body.count + 
                  node.parent.parent.rows.foot.count - 1

      self.maxX = node.parent.parent.columns.count - 1
      self.heading = heading
    end

    def write(tabular, x, y)
      self.x = x
      self.y = y
      tabular[y][x] = self
    end

    def fillArray(tabular, x, y, columns)
      # Compute the cell width
      (x..x + self.colspan - 1).each { |lx|
        self.width += columns[lx]
      }

      # Add the column spacing when colspan si bigger than 1 to avoid background colors problems 
      # TODO: Use the same constant as in the rest of table converter
      self.width += (self.colspan - 1) * 0.025

      # Fill the tabular with the cells
      (x..x + self.colspan - 1).each do |lx|
        # Fill the column
        (y..y + self.rowspan - 1).each do |ly|
          if    lx == x and ly == y
            # The real cell
            self.write(tabular, lx, ly)
          elsif lx == x and ly != y
            # Empty colspan, it is the continuation of a rowspan
            copy = self.dup
            copy.rowspan -= ly - y
            copy.content  = ""
            copy.repeated = true
            copy.write(tabular, lx, ly)
          else
            # Empty cell because it is covered by a colspan
            copy = self.dup
            copy.content  = nil
            copy.repeated = true
            copy.width = 0
            copy.write(tabular, lx, ly)
          end
        end # for rowspan
      end # for colspan
      return x + self.colspan
    end

    def getContent(grid, frame)
      result = self.content.strip
      if result != nil
        # Manage headings
        result = $tex.macro("adocMacroTableHead", result) if self.heading == :head
        result = $tex.macro("adocMacroTableFoot", result) if self.heading == :foot

        # Manage the horizontal alignement (insert raggedleft or centering)
        if    self.halign == 'right';  result = "#{$tex.macro('raggedleft')} #{result}"
        elsif self.halign == 'center'; result = "#{$tex.macro('centering')} #{result}"
        end

        # Use the real cell width
        colWidth = "#{self.width}#{$tex.macro('textwidth')}"

        # Manage the rowspan 
        result = $tex.macro("multirow",   self.rowspan,  colWidth,   result) if (self.rowspan > 1) and (!self.repeated)

        # Use m (middle), p (top), b (bottom) column type for the vertical alignement in \multicolumn
        if    self.valign == 'middle'; colType = 'm'
        elsif self.valign == 'bottom'; colType = 'b'
        else                           colType = 'p'
        end

        # Manage cell width
        colType = "#{colType}#{$tex.braces(colWidth)}"

        # Draw the left border of a cell
        left = ' '
        left = '|' if ((frame and (self.x == 0)) or (grid  and (self.x != 0)))

        # Draw the right border of a cell
        isLastCell = ((self.x == self.maxX) || (self.x + self.colspan - 1 == self.maxX && self.colspan > 1))
        right = (frame and isLastCell) ? '|' : ' '

        # The column specifier with left and right border
        colType = "#{left}#{colType}#{right}"

        result = $tex.macro("multicolumn", self.colspan, colType, result)
      end
      return result
    end

    def getBorder(grid, frame)
      result = nil
      if (self.content != nil) and (self.rowspan == 1)
        if (self.y != self.maxY) and grid
          result = $tex.macro("cline", "#{self.x + 1}-#{self.x + self.colspan}") + " "
        end
      end
      return result
    end
  end

  def self.debugTableSimple(table)
    puts ""
    puts "---------------------------------------------------------"
    table.each_with_index do |row, y|
      text = row.map{ |cell|
        if cell.nil?
          "XX"
        else
          if cell.content.nil?
            "--"
          else
            cell.content
          end
        end
      }
      puts text.join(" | ")
    end
    puts "---------------------------------------------------------"
  end

  def self.debugTable(table)
    puts ""
    puts "---------------------------------------------------------"
    table.each_with_index do |row, y|
      row.each_with_index do |cell, x|
        puts "rowspan = #{cell.rowspan} colspan = #{cell.colspan} content = #{cell.content}"
      end
      puts "next line"
    end
    puts "---------------------------------------------------------"
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
        warn "#{node.type} not suported in LaTeX backend"
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
        warn "Unknown node type #{node.type}"
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
        #$tex.macro('hyperlink', node.target.tex_normalize, node.text || node.attributes['path'] || "")
        reference =  $tex.normalize(node.target)
        text = "page #{$tex.macro("pageref", reference)}"
        #text = node.text if node.text != ""
        $tex.macro('hyperlink', reference, text)

      when :link
        target = node.target
        # TODO Improve the external URL detection
        if target.include? "http:" or target.include? "https:"
          $tex.macro('href', target, node.text)
        else
          reference =  $tex.normalize(node.target)
          text = "page #{$tex.macro("pageref", reference)}"
          #text = node.text if node.text != ""
          $tex.macro('hyperlink', reference, text)
        end

      when :ref
        reference =  $tex.normalize(node.id)
        text = "page #{$tex.macro("pageref", reference)}"
        $tex.hypertarget(node.id, text)

      when :bibref
        reference =  $tex.normalize(node.id)
        text = "page #{$tex.macro("pageref", reference)}"
        $tex.hypertarget(node.id, text)

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
    case node.type
      when :visible
        return "#{$tex.macro('index', node.text)}#{node.text}"
      else
        return "#{$tex.macro('index', node.attributes['terms'].join('!'))}"
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
    'red'    => "adocMacroRed",
    'blue'   => "adocMacroBlue",
    'green'  => "adocMacroGreen",
    'yellow' => "adocMacroYellow"
  }

  $alignments = {
    "text-left"   => "flushright",
    "text-right"  => "flushright",
    "text-center" => "center"
  }

  $headings = {
    'article' => [ 'part', 'section', 'subsection', 'subsubsection', 'paragraph' ],
    'beamer'  => [ 'part', 'section', 'frame', 'textbf' ],
    'book'    => [ 'part', 'chapter', 'section', 'subsection', 'subsubsection', 'paragraph' ]
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
    if node.attributes['toc'] != nil and node.attributes['toc-placement'] != 'macro'
      result = "#{$tex.macro("tableofcontents")}\n"
    end
    return result
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
