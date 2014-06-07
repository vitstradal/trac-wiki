# encoding: utf-8
require 'cgi'
require 'uri'
require 'yaml'
require 'unicode_utils/compatibility_decomposition'

# :main: TracWiki

# The TracWiki parses and translates Trac formatted text into
# XHTML. TracWiki is a lightweight markup syntax similar to what many
# WikiWikiWebs use. Example syntax:
#
# = Heading 1 =
# == Heading 2 ==
# === Heading 3 ===
# **Bold text**
# ''Italic text''
# [[Links]]
# ||=Table=||=Heading=||
# || Table || Cells   ||
# [[Image(image.png)]]
# [[Image(image.png, options)]]
#
# for more see http://trac.edgewall.org/wiki/WikiFormatting
#
# You can customize the created image markup by overriding
# make_image.

# Main TracWiki parser class. Call TracWikiParser#parse to parse
# TracWiki formatted text.
#
# This class is not reentrant. A separate instance is needed for
# each thread that needs to convert Creole to HTML.
#
# Inherit this to provide custom handling of links. The overrideable
# methods are: make_local_link
module TracWiki
  class TooLongException < Exception
  end

  class Parser

    # Allowed url schemes
    # Examples: http https ftp ftps
    attr_accessor :allowed_schemes

    # structure where headings are stroed
    # list of hasheses with `level` and `title`, `sline`
    # [ { leven: 1, # <h1>
    #     sline: 3, # line where head starts
    #     eline: 4, # line before next heading starts
    #     aname: 'anchor-to-this-heading',
    #     title: 'heading title'
    #   },
    #   ...
    # ]
    attr_accessor :headings

    # url base for links
    attr_writer :base

    # Disable url escaping for local links
    # Escaping: [[/Test]] --> %2FTest
    # No escaping: [[/Test]] --> Test
    attr_writer :no_escape
    def no_escape?; @no_escape; end

    # Disable url escaping for local links
    # [[whatwerver]] stays [[whatwerver]]
    attr_writer :no_link
    def no_link?; @no_link; end

    # math syntax extension:
    # $e^x$ for inline math
    # $$ e^x $$ for display math
    attr_writer :math
    def math?; @math; end

    # allow some <b> <form> <html> 
    # html will be sanitized
    attr_writer :allow_html
    def allow_html?; @allow_html; end

    # add '<a class='editheading' href="?edit=N>edit</a>'
    # to each heading
    attr_writer :edit_heading
    def edit_heading?; @edit_heading; end

    # understand merge tags  (see diff3(1))
    # >>>>>>> mine
    # ||||||| orig
    # =======
    # <<<<<<< yours
    # convert to <div class="merge merge-mine">mine</div>
    attr_writer :merge
    def merge?; @merge; end

    # every heading had id, generated from heading text
    attr_writer :id_from_heading
    def id_from_heading?; @id_from_heading; end

    # use macros? defalut yes
    attr_writer :macros
    def macros?; @macros; end

    # when id_from_heading, non ascii char are transliterated to ascii
    attr_writer :id_translit
    def id_translit?; @id_translit; end

    # like template but more powerfull
    # do no use.
    attr_accessor :macro_commands
    @macro_commands = {}

    # template_handler(macroname) -> template_text
    # when macros enabled and {{myCoolMacro}} ocured,
    # result fo `template_handler('myCoolMacro') inserted
    attr_accessor :template_handler


    # macro {{$var}} | {{#comment}} | {{!cmd}} |  {{template}} | {{/template}}
    # string begins with macro
    MACRO_BEG_REX =  /\A\{\{ ( \$[\$\.\w]+ | [\#!\/]\w* |\w+ ) /x
    MACRO_BEG_INSIDE_REX =  /\A(.*?)(?<!\{)\{\{ ( \$[\$\.\w]+ | [\#!\/]\w* | \w+ ) /xm
    # find end of marcro or begin of inner macro
    MACRO_END_REX =  /\A(.*?) ( \}\} | \{\{ ( \$[\$\.\w]+ | [\#!\/]\w* | \w+)  )/mx

    # Create a new Parser instance.
    def initialize(options = nil)
      init_macros
      @macros = true
      @allowed_schemes = %w(http https ftp ftps)
      macro_commands = options.delete :macro_commands
      @macro_commands.merge! macro_commands if ! macro_commands.nil?
      @no_escape = nil
      @base = ''
      options.each_pair {|k,v| send("#{k}=", v) }
      @base += '/' if !@base.empty? && @base[-1] != '/'
    end

    def text(text)
      @text = text
      return self
    end

    def was_math?; @was_math; end

    def to_html(text = nil)
      text(text) if ! text.nil?
      @was_math = false
      @anames = {}
      @count_lines_level = 0
      @text = text if !text.nil?
      @tree = TracWiki::Tree.new
      @edit_heading_class = 'editheading'
      @headings = [ {level: 0, sline: 1 } ]
      @p = false
      @stack = []
      @stacki = []
      @was_math = false
      @line_no = 1
      parse_block(@text)
      @tree.to_html
    end

    def make_toc_html
      @tree = TracWiki::Tree.new
      parse_block(make_toc)
      @tree.to_html
    end

    def add_macro_command(name, &block)
        @macro_commands[name] = block
    end

    protected

    def add_line_no(count)
      @line_no += count if @count_lines_level == 0
    end

    def init_macros
      @macro_commands = {
        '!ifeq'  => proc { |env| env.expand_arg(0) == env.expand_arg(1) ? env.expand_arg(2) : env.expand_arg(3) },
        '!ifdef' => proc { |env| env.at(env.expand_arg(0), nil, false).nil? ? env.expand_arg(2) : env.expand_arg(1) },
        '!set'   => proc { |env| env[env.expand_arg(0)] = env.expand_arg(1); '' },
        '!yset'  => proc { |env| env[env.expand_arg(0)] = YAML.load(env.arg(1)); '' },
        '!sub'   => proc { |env| pat = env.expand_arg(1)
                                 pat = Regexp.new(pat[1..-2]) if pat =~ /\A\/.*\/\Z/
                                 env.expand_arg(0).gsub(pat, env.expand_arg(2))
                         },
        '!for'   => proc { |env| i_name = env.arg(0)
                               top = env.arg(1)
                               tmpl = env.arg(2)
                               #print "top#{top}\n"
                               if top =~ /^\d+/
                                 set = (0..(top.to_i-1))
                               else
                                 set = env.at(top, nil, false)
                                 if set.is_a?(Hash)
                                   set = set.keys.sort
                                 elsif set.is_a?(Array)
                                   set = (0 .. set.size-1)
                                 elsif set.nil?
                                   set = []
                                 else
                                   print "error top(#{top}), set#{set} #{set.class}\n"
                                   raise "Error in {{!for #{i_name}|#{top}|#{tmpl}}} $#{top}.class=#{set.class}(#{set.to_s})"
                                 end
                               end
                               set.map do |i|
                                 env[i_name] = i.to_s
                                 env.expand(tmpl)
                               end.join('')
                       },
      }

    end

    # Escape any characters with special meaning in HTML using HTML
    # entities. (&<>" not ')
    def escape_html(string)
      Parser.escapeHTML(string)
    end

    def self.escapeHTML(string)
      string.gsub(/&/, '&amp;').gsub(/\"/, '&quot;').gsub(/>/, '&gt;').gsub(/</, '&lt;')
    end

    # Escape any characters with special meaning in URLs using URL
    # encoding.
    def escape_url(string)
      CGI::escape(string)
    end

    def start_tag(tag, args = {}, lindent = nil)
      lindent = @stacki.last || -1  if lindent.nil?

      @stack.push(tag)
      @stacki.push(lindent)

      if tag == 'strongem'
        @tree.tag_beg(:strong).tag_beg(:em)
      else
        @tree.tag_beg(tag, args)
      end
    end

    def end_tag
      tag = @stack.pop
      tagi = @stacki.pop
      if tag == 'strongem'
        @tree.tag_end(:em).tag_end(:strong);
      elsif tag == 'p'
        @tree.tag_end(:p)
      else
        @tree.tag_end(tag)
      end
    end

    def toggle_tag(tag, match)
      if @stack.include?(tag)
        if @stack.last == tag
          end_tag
        else
          @tree.add(match)
        end
      else
        start_tag(tag)
      end
    end

    def end_paragraph
      end_tag while !@stack.empty?
      @p = false
    end

    def start_paragraph(add_spc = true)
      if @p
        #FIXME: multiple space s
        @tree.add_spc if add_spc
      else
        end_paragraph
        start_tag('p')
        @p = true
      end
    end

    # Translate an explicit local link to a desired URL that is
    # properly URL-escaped. The default behaviour is to convert local
    # links directly, escaping any characters that have special
    # meaning in URLs. Relative URLs in local links are not handled.
    #
    # Examples:
    #
    # make_local_link("LocalLink") #=> "LocalLink"
    # make_local_link("/Foo/Bar") #=> "%2FFoo%2FBar"
    #
    # Must ensure that the result is properly URL-escaped. The caller
    # will handle HTML escaping as necessary. HTML links will not be
    # inserted if the function returns nil.
    #
    # Example custom behaviour:
    #
    # make_local_link("LocalLink") #=> "/LocalLink"
    # make_local_link("Wikipedia:Bread") #=> "http://en.wikipedia.org/wiki/Bread"
    def make_local_link(link) #:doc:
      # FIXME: xss when no_escape
      link, anch = link.split(/#/, 2)
      if no_escape?
        return "#{@base}#{link}" if ! anch
        return "##{anch}" if  link == ''
        return "#{@base}#{link}##{anch}"
      end
      return "#{@base}#{escape_url(link)}" if ! anch
      return "##{escape_url(anch)}" if  link == ''
      "#{@base}#{escape_url(link)}##{escape_url(anch)}"
    end

    # Create image markup. This
    # method can be overridden to generate custom
    # markup, for example to add html additional attributes or
    # to put divs around the imgs.
    def make_image(uri, attrs='')
      @tree.tag(:img, make_image_attrs(@base + uri, attrs))
    end

    def make_image_attrs(uri, attrs)
       a = {src: make_explicit_link(uri)}
       style = []
       attrs ||= ''
       attrs.strip.split(/\s*,\s*/).each do |opt|
         case opt
           when /^\d+[^\d]*$/
             a['width'] = escape_url(opt)
           when /^(right|left|center)/i
             a['align'] = escape_url(opt)
           when  /^(top|bottom|middle)$/i
             a['valign'] = escape_url(opt)
           when  /^link=(.*)$/i
             # pass
           when  /^nolink$/i
             # pass
           when /^(align|valign|border|width|height|alt|title|longdesc|class|id|usemap)=(.*)$/i
            a[$1]= escape_url($2)
           when /^(margin|margin-(left|right|top|bottom))=(\d+)$/
            style.push($1 + ':' + escape_url($3))
         end
       end
       a[:style] = style.join(';') if ! style.empty?
       return {}  if a.empty?
       return a;
    end

    def make_headline(level, title, aname, title_offset)

      hN = "h#{level}".to_sym

      @tree.tag_beg(hN, { id: aname } )
      parse_inline(title, title_offset)
      if edit_heading?
        edit_heading_link(@headings.size - 1)
      end
      @tree.tag_end(hN)
    end

    def edit_heading_link(section)
        @tree.tag(:a, { class:  @edit_heading_class, href: "?edit=#{section}"}, "edit")
    end

    def make_explicit_link(link)
      begin
        uri = URI.parse(link)
        return uri.to_s if uri.scheme && @allowed_schemes.include?(uri.scheme)
      rescue URI::InvalidURIError
      end
      make_local_link(link)
    end


    def make_toc
        @headings.map do |h|
           if h[:level] < 1
             ''
           else
             ind = "  " * (h[:level] - 1)
             "#{ind}* [[##{h[:aname]}|#{h[:title]}]]\n"
           end
        end.join
    end

    def parse_inline(str, offset)
      raise "offset is nil" if offset.nil?
      until str.empty?
        case
        # raw url http://example.com/
        when str =~ /\A(!)?((https?|ftps?):\/\/\S+?)(?=([\]\,.?!:;"'\)]+)?(\s|$))/
          notlink, link = $1, $2
          make_link(link, nil, link, 0, !!notlink)
        # [[Image(pic.jpg|tag)]]
        when str =~ /\A\[\[Image\(([^,]*?)(,(.*?))?\)\]\]/   # image 
          make_image($1, $3)
        # [[link]]
        #          [     link2          | text5          ]
        when str =~ /\A (\[ \s* ([^\[|]*?) \s*) ((\|\s*)(.*?))? \s* \] /mx
          link, content, content_offset, whole  = $2, $5, $1.size + ($4||'').size, $&
          make_link(link, content, "[#{whole}]",offset + content_offset)
        #          [[     link2          | text5          ]]
        when  str =~ /\A (\[\[ \s* ([^|]*?) \s*) ((\|\s*)(.*?))? \s* \]\] /mx
          link, content, content_offset, whole= $2, $5, $1.size + ($4||'').size, $&
          #print "link: #{content_offset} of:#{offset}, '#{$1}', '#{$4||''}'\n"
          make_link(link, content, whole, offset + content_offset)
        when allow_html? && str =~ /\A<(\/)?(\w+)(?:([^>]*?))?(\/\s*)?>/     # single inline <html> tag
          eot, tag, args, closed = $1, $2, $3, $4
          do_raw_tag(eot, tag, args, closed, $'.size)
        when str =~ /\A\{\{\{(.*?\}*)\}\}\}/     # inline {{{ }}} pre (tt)
          @tree.tag(:tt, $1)
        when macros? && str =~ MACRO_BEG_REX                # macro  {{
          mac, str, lines, offset = parse_macro($1, $', offset, $&.size)
          parse_inline(mac.gsub(/\n/,  ' '),0);
          #print "MACRO.inline(#{$1}), next:#{str}"
          #return str, offset
          next
        when str =~ /\A`(.*?)`/                  # inline pre (tt)
          @tree.tag(:tt, $1)
        when math? && str =~ /\A\$(.+?)\$/       # inline math  (tt)
          @tree.tag(:span, {:class => 'math'},  $1)
          @was_math = true
        when str =~ /\A(\&\w*;)/       # html entity 
          #print "add html ent: #{$1}\n"
          @tree.add_raw($1)
        when str =~ /\A([:alpha:]|[:digit:])+/
          @tree.add($&)                      # word
        when str =~ /\A\s+/
          @tree.add_spc
        when str =~ /\A'''''/
          toggle_tag 'strongem', $&       # bolditallic
        when str =~ /\A\*\*/ || str =~ /\A'''/
          toggle_tag 'strong', $&         # bold
        when str =~ /\A''/ || str =~ /\A\/\//
          toggle_tag 'em', $&             # italic
        when str =~ /\A\\\\/ || str =~ /\A\[\[br\]\]/i
          @tree.tag(:br)                  # newline
        when str =~ /\A__/
          toggle_tag 'u', $&              # underline
        when str =~ /\A~~/
          toggle_tag 'del', $&            # delete
        when str =~ /\A~/
          @tree.add_raw('&nbsp;')         # tilde
#       when /\A\+\+/
#         toggle_tag 'ins', $&           # insert
        when str =~ /\A\^/
          toggle_tag 'sup', $&            # ^{}
        when str =~ /\A,,/
          toggle_tag 'sub', $&            # _{}
        when str =~ /\A!(\{\{|[^\s])/
          @tree.add($1)                   # !neco !{{
        when str =~ /\A./
          @tree.add($&)                   # ordinal char
        end
        str = $'
        offset += $&.size
      end
      return offset
    end

    #################################################################
    # macro {{ }}
    #  convetntion {{!cmd}} {{template}} {{$var}} {{# comment}} {{!}} (pipe)

    # r: expanded macro , rest of str, count lines taken from str
    # sideefect: parse result of macro
    def parse_macro(macro_name, str, offset, macro_name_size)
      raise "offset is nil" if offset.nil?
      raise "offset is nil" if macro_name_size.nil?
      @env = Env.new(self) if @env.nil?
      @env.atput('offset',  offset)
      @env.atput('lineno',  @line_no)
      begin
        mac_out, rest, lines, rest_offset = @env.parse_macro_all(macro_name, str, macro_name_size)
        raise "lines is nil" if lines.nil?
        #print "mac: '#{mac_out}' rest: '#{rest}'\n"
        #print  "mac: ro #{rest_offset}, of#{offset}, lines: #{lines} ms: #{macro_name_size} strlen#{str.size}, str'#{str}' rest:'#{rest}'\n"
        rest_offset += offset + macro_name_size if lines == 0
        #print "ro#{rest_offset}\n"
        return mac_out, rest, lines, rest_offset
      rescue  TooLongException => e
        return '', "TOO_LONG_EXPANSION_OF_MACRO(#{macro_name})QUIT", 0, 0
      rescue  Exception => e
        #@tree.tag(:span, {:title => "#{e}\", :class=>'parse-error'}, "!!!")
        @tree.tag(:span, {:title => "#{e}\n#{e.backtrace}", :class=>'parse-error'}, "!!!")
        print "tace#{e.backtrace.to_s}\n"
        return '', '', 0, 0
      end
    end

    #################################################################

    def make_link(link, content, whole, offset, not_make_link = false )
      # was '!' before url?
      return @tree.add(whole) if not_make_link

      # specail "link" [[BR]]:
      return @tree.tag(:br) if link =~ /^br$/i

      uri = make_explicit_link(link)
      return @tree.add(whole) if not uri
      return @tree.add(whole) if no_link? && uri !~ /^(ftp|https?):/

      @tree.tag_beg(:a, {href:uri})
      if content
         parse_inline(content, offset)
      else
          @tree.add(link)
      end
      @tree.tag_end(:a)
    end

    #################################################################

    def parse_table_row(str)
      offset = 0;
      start_tag('tr') if !@stack.include?('tr')
      str.sub!(/\r/, '')
      colspan = 1
      print_tr = true
      last_tail  = ''
      last_txt  = ''
      str.scan(/(=?)(\s*)(.*?)\1?($ | \|\|\\\s*$ | \|\| )/x) do
        tdth = $1.empty? ? 'td' : 'th'
        tdth_size = $1.size
        le, txt, tail, cell_size  = $2.size, $3, $4, $&.size

        # do not end row, continue on next line
        print_tr = false if tail =~ /^\|\|\\/

        if txt.empty? && le == 0
          colspan += 1
          next
        end

        style = nil
        if  txt =~ /\S(\s*)$/
              ri = $1.size
              ri += 100 if tail.empty? # do not right when last || omnited
              style = 'text-align:right'  if ri == 0 && le >= 1
              style = 'text-align:center' if le >= 2 && ri >= 2
              #print "le#{le} ri#{ri} st:#{style}\n"
        end

        colspan =  colspan > 1 ? colspan : nil;
        start_tag(tdth, { style:style, colspan: colspan});
        colspan = 1

        parse_inline(txt.strip, offset + tdth_size + le + 2) if txt
        end_tag while @stack.last != 'tr'
        offset += cell_size
      end
      if print_tr
        end_tag
      end
      return offset
    end

    def make_nowikiblock(input)
      input.gsub(/^ (?=\}\}\})/, '')
    end

    def parse_li_line(spc_size, bullet)

      while !@stacki.empty? && @stacki.last >  spc_size
        end_tag
      end

      if @stack.include?('li')
        while @stack.last != 'li'
          end_tag
        end

        # end list if type differ
        # @stack.last is now ul or li
        if @stacki.last == spc_size
          end_tag # li
          ulol_last = @stack.last
          ulol_now =  bullet =~ /[*-]/ ? 'ul' : 'ol'
          if ulol_last != ulol_now
            end_tag # ol | ul
          end
        end
      else
        end_paragraph
      end

      if @stacki.empty? || @stacki.last <  spc_size
        bullet.gsub!(/\.$/,'')
        ulol = bullet =~ /[-*]/ ? 'ul' : 'ol';

        type = nil
        type = 'i' if bullet =~ /i/i;
        type = 'a' if bullet =~ /a/i;

        start = nil
        start = bullet if bullet =~ /^\d+$/ && bullet != '1'

        start_tag(ulol, {type: type, start: start}, spc_size)
      end

      start_tag('li')

    end

    def blockquote_level_to(level)
      cur_level = @stack.count('blockquote')
      if cur_level ==  level
        @tree.add(' ')
        return
      end
      while cur_level < level
        cur_level += 1
        start_tag('blockquote')
      end
      while cur_level > level
        cur_level -= 1 if @stack.last == 'blockquote'
        end_tag
      end
    end

    def do_math(text)
      end_paragraph
      #@tree.add("$$#{text}$$\n")
      @tree.tag(:div, {class:'math'}, text)
      @was_math = true
    end
    def do_merge(merge_type, who)
      merge_class = case merge_type[0]
                      when '<' ; 'merge-mine'
                      when '=' ; 'merge-split'
                      when '|' ; 'merge-orig'
                      when '>' ; 'merge-your'
                    end
      end_paragraph
      @tree.tag(:div, { class: "merge #{merge_class}" }, who)
    end
    def do_pre(text)
      end_paragraph
      nowikiblock = make_nowikiblock(text)
      @tree.tag(:pre, nowikiblock)
    end

    def do_raw_tag(eot, tag, attrs, closed, tail_size)
      if !eot
        end_paragraph if tag == 'p' || tag == 'div'
        #print "open tag #{tag},'#{attrs}'\n"
        attrs_h = _parse_attrs_to_hash(attrs)
        @tree.tag_beg(tag, attrs_h)
        @tree.tag_end(tag) if closed
      else
        #print "close tag #{tag}\n"
        @tree.tag_end(tag)
        if tag == 'p' || tag == 'div'
          end_paragraph
          start_paragraph if tail_size > 0
        end
      end
    end

    def _parse_attrs_to_hash(str)
      ret = {}
      while str =~ /\A\s*(\w+)\s*=\s*'([^>']*)'/ ||
            str =~ /\A\s*(\w+)\s*=\s*"([^>"]*)"/ ||
            str =~ /\A\s*(\w+)\s*=\s*(\S*)/
       ret[$1] = $2
       str = $'
      end
      ret
    end

    def do_hr
      end_paragraph
      @tree.tag(:hr)
    end

    def do_heading(level, title, aname, title_offset)
      aname= aname_nice(aname, title)
      @headings.last[:eline] = @line_no - 1
      @headings.push({ :title =>  title, :sline => @line_no, :aname => aname, :level => level, })
      end_paragraph
      make_headline(level, title, aname, title_offset)
    end
    def do_table_row(text)
      if !@stack.include?('table')
        end_paragraph
        start_tag('table')
      end
      parse_table_row(text)
    end
    def do_term(term)
      start_tag('dl')
      start_tag('dt')
      @tree.add(term)
      end_tag
      start_tag('dd')
    end

    def do_citation(level)
      start_paragraph if !@stack.include? 'p'
      blockquote_level_to(level)
    end

    def do_ord_line(spc_size)

      if @stack.include?('li') || @stack.include?('dl')

        # dl, li continuation
        parse_inline(' ', 0)

      elsif spc_size > 0
        # quote continuation
        start_paragraph if !@stack.include? 'p'
        blockquote_level_to(1)

      else
        # real ordinary line
        start_paragraph
      end
    end

    def parse_block(str, want_end_paragraph = true)
      #print "BLOCK.str(#{str})\n"
      until str.empty?
        case
        # macro
        when macros? && str =~ MACRO_BEG_REX
          mac, str, lines, offset = parse_macro($1, $', 0, $&.size)
          raise 'lines is nil' if lines.nil?
          raise 'offset is nil' if offset.nil?
          #print "MACRO.lines(#{$1})lines:#{lines}, str:'#{str}'\n"
          add_line_no(lines)
          @count_lines_level +=1
          parse_block(mac, false)
          @count_lines_level -=1
          if mac.size > 0 && str =~ /^(.*)(\r?\n)?/
            line, str = $1 , $'
            add_line_no($&.count("\n"))
            parse_inline(line, offset)
          end
          next
        # display math $$
        when math? && str =~ /\A\$\$(.*?)\$\$/m
          do_math($1)
        # merge
        when merge? && str =~ /\A(<{7}|={7}|>{7}|\|{7}) *(\S*).*$(\r?\n)?/
          do_merge($1, $2)
        # pre {{{ ... }}}
        when str =~ /\A\{\{\{\r?\n(.*?)\r?\n\}\}\}/m
          do_pre($1)
        # horizontal rule
        when str =~ /\A\s*-{4,}\s*$/
          do_hr()
        # heading == Wiki Ruless ==
        # heading == Wiki Ruless ==  #tag
        when str =~ /\A([[:blank:]]*(={1,6})\s*)(.*?)\s*=*\s*(#(\S*))?\s*$(\r?\n)?/
          do_heading($2.size, $3, $5, $1.size)
        # table row ||
        when str =~ /\A[ \t]*\|\|(.*)$(\r?\n)?/
          do_table_row($1)
        # empty line
        when str =~ /\A\s*$(\r?\n)?/
          end_paragraph
        when str =~ /\A([:\w\s]+)::(\s+|\r?\n)/
          do_term($1)
        # li
        when str =~ /\A((\s*)([*-]|[aAIi\d]\.)\s+)(.*?)$(\r?\n)?/
          parse_li_line($2.size, $3)
          parse_inline($4, $1.size)
        # citation
        when str =~ /\A(>[>\s]*)(.*?)$(\r?\n)?/
          do_citation($1.count('>'))
          parse_inline($2, $1.size)
        # ordinary line
        when str =~ /\A(\s*)(\S+.*?)$(\r?\n)?/
          text = $2
          do_ord_line($1.size)
          parse_inline(text.rstrip, $1.size)
        else # case str
          raise "Parse error at #{str[0,30].inspect}"
        end
        add_line_no(($`).count("\n")+($&).count("\n"))
        str = $'
      end
      end_paragraph if want_end_paragraph
      @headings.last[:eline] = @line_no - 1
    end
    def aname_nice(aname, title)

      if aname.nil? && id_from_heading?
        aname = title.gsub /\s+/, '_'
        aname = _translit(aname) if id_translit?
      end
      return nil if aname.nil?
      aname_ori = aname
      count = 2
      while @anames[aname]
        aname = aname_ori + ".#{count}"
        count+=1
      end
      @anames[aname] = true
      aname
    end
    def _translit(text)
       # iconv is obsolete, but translit funcionality was not replaced
       # see http://stackoverflow.com/questions/20224915/iconv-will-be-deprecated-in-the-future-transliterate
       # return Iconv.iconv('ascii//translit', 'utf-8', text).join

       # http://unicode-utils.rubyforge.org/UnicodeUtils.html#method-c-compatibility_decomposition
       return UnicodeUtils.compatibility_decomposition(text).chars.grep(/\p{^Mn}/).join('')
    end
  end
end
