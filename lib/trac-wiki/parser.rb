require 'cgi'
require 'uri'

# :main: TracWiki

# The TracWiki parses and translates Trac formatted text into
# XHTML. Creole is a lightweight markup syntax similar to what many
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
# The simplest interface is TracWiki.render. The default handling of
# links allow explicit local links using the [[link]] syntax. External
# links will only be allowed if specified using http(s) and ftp(s)
# schemes. If special link handling is needed, such as inter-wiki or
# hierachical local links, you must inherit Creole::CreoleParser and
# override make_local_link.
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
  class Parser

    # Allowed url schemes
    # Examples: http https ftp ftps
    attr_accessor :allowed_schemes


    # Disable url escaping for local links
    # Escaping: [[/Test]] --> %2FTest
    # No escaping: [[/Test]] --> Test
    attr_writer :no_escape
    def no_escape?; @no_escape; end

    # Disable url escaping for local links
    # [[whatwerver]] stays [[whatwerver]]
    attr_writer :no_link
    def no_link?; @no_link; end

    attr_writer :math
    def math?; @math; end

    attr_writer :merge
    def merge?; @merge; end

    # Create a new Parser instance.
    def initialize(text, options = {})
      @allowed_schemes = %w(http https ftp ftps)
      @text = text
      @no_escape = nil
      options.each_pair {|k,v| send("#{k}=", v) }
    end

    @was_math = false
    def was_math?; @was_math; end

    # Convert CCreole text to HTML and return
    # the result. The resulting HTML does not contain <html> and
    # <body> tags.
    #
    # Example:
    #
    # parser = Parser.new("**Hello //World//**")
    # parser.to_html
    # #=> "<p><strong>Hello <em>World</em></strong></p>"
    def to_html
      @out = ''
      @p = false
      @stack = []
      @stacki = []
      @was_math = false
      parse_block(@text)
      @out
    end

    protected

    # Escape any characters with special meaning in HTML using HTML
    # entities.
    def escape_html(string)
      CGI::escapeHTML(string)
    end

    # Escape any characters with special meaning in URLs using URL
    # encoding.
    def escape_url(string)
      CGI::escape(string)
    end

    def start_tag(tag, args = '', lindent = nil)
      lindent = @stacki.last || -1  if lindent.nil?

      @stack.push(tag)
      @stacki.push(lindent)

      if tag == 'strongem'
        @out << '<strong><em>'
      else
        @out << '<' << tag << args << '>'
      end
    end

    def end_tag
      tag = @stack.pop
      tagi = @stacki.pop
      if tag == 'strongem'
        @out << '</em></strong>'
      elsif tag == 'p'
        @out << "</p>\n"
      else
        @out << "</#{tag}>"
      end
    end

    def toggle_tag(tag, match)
      if @stack.include?(tag)
        if @stack.last == tag
          end_tag
        else
          @out << escape_html(match)
        end
      else
        start_tag(tag)
      end
    end

    def end_paragraph
      end_tag while !@stack.empty?
      @p = false
    end

    def start_paragraph
      if @p
        @out << ' ' if @out[-1] != ?\s
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
      no_escape? ? link : escape_url(link)
    end

    # Sanatize a direct url (e.g. http://wikipedia.org/). The default
    # behaviour returns the original link as-is.
    #
    # Must ensure that the result is properly URL-escaped. The caller
    # will handle HTML escaping as necessary. Links will not be
    # converted to HTML links if the function returns link.
    #
    # Custom versions of this function in inherited classes can
    # implement specific link handling behaviour, such as redirection
    # to intermediate pages (for example, for notifing the user that
    # he is leaving the site).
    def make_direct_link(url) #:doc:
      url
    end

    # Sanatize and prefix image URLs. When images are encountered in
    # Creole text, this function is called to obtain the actual URL of
    # the image. The default behaviour is to return the image link
    # as-is. No image tags are inserted if the function returns nil.
    #
    # Custom version of the method can be used to sanatize URLs
    # (e.g. remove query-parts), inhibit off-site images, or add a
    # base URL, for example:
    #
    # def make_image_link(url)
    # URI.join("http://mywiki.org/images/", url)
    # end
    def make_image_link(url) #:doc:
      url
    end

    # Create image markup. This
    # method can be overridden to generate custom
    # markup, for example to add html additional attributes or
    # to put divs around the imgs.
    def make_image(uri, attrs='')
      "<img src=\"#{make_explicit_link(uri)}\"#{make_image_attrs(attrs)}/>"
    end

    def make_image_attrs(attrs)
       return '' if ! attrs
       a = {}
       style = []
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
       a['style'] = style.join(';') if ! style.empty?
       return '' if a.empty?
       return ' ' + a.map{|k,v| "#{k}=\"#{v}\"" }.sort.join(' ')
    end

    def make_headline(level, text, aname)
      ret = "<h#{level}>" << escape_html(text) << "</h#{level}>"
      if aname
        ret = "<a name=\"#{ escape_html(aname) }\"/>" + ret
      end
      ret
    end

    def make_explicit_link(link)
      begin
        uri = URI.parse(link)
        return uri.to_s if uri.scheme && @allowed_schemes.include?(uri.scheme)
      rescue URI::InvalidURIError
      end
      make_local_link(link)
    end

    def parse_inline(str)
      until str.empty?
        case str
        # raw url
        when /\A(!)?((https?|ftps?):\/\/\S+?)(?=([\]\,.?!:;"'\)]+)?(\s|$))/
          str = $'
          if $1
            @out << escape_html($2)
          else
            if uri = make_direct_link($2)
              @out << '<a href="' << escape_html(uri) << '">' << escape_html($2) << '</a>'
            else
              @out << escape_html($&)
            end
          end
        # [[Image(pic.jpg|tag)]]
        when /\A\[\[Image\(([^,]*?)(,(.*?))?\)\]\]/   # image 
          str = $'
          @out << make_image($1, $3)
        # [[link]]
        #          [     link1          | text2          ]
        when /\A \[ \s* ([^\[|]*?) \s* (\|\s*(.*?))? \s* \] /mx
          str = $'
          link, content, whole= $1, $3, $&
          make_link(link, content, "[#{whole}]")
        when /\A \[\[ \s* ([^|]*?) \s* (\|\s*(.*?))? \s* \]\] /mx
          str = $'
          link, content, whole= $1, $3, $&
          make_link(link, content, whole)
        else
          str = parse_inline_tag(str)
        end

      end
    end

    def make_link(link, content, whole)
      # specail "link" [[BR]]:
      if link =~ /^br$/i
        @out << '<br/>'
        return
      end
      uri = make_explicit_link(link)
      if not uri
        @out << escape_html(whole)
        return
      end

      if no_link?
        if uri !~ /^(ftp|https?):/
          @out << escape_html(whole)
          return
        end
      end

      @out << '<a href="' << escape_html(uri) << '">'
      if content
        until content.empty?
          content = parse_inline_tag(content)
        end
      else
          @out << escape_html(link)
      end
      @out << '</a>'
    end

    def parse_inline_tag(str)
      case
      when str =~ /\A\{\{\{(.*?\}*)\}\}\}/     # inline pre (tt)
        @out << '<tt>' << escape_html($1) << '</tt>'
      when str =~ /\A`(.*?)`/                  # inline pre (tt)
        @out << '<tt>' << escape_html($1) << '</tt>'

      when math? && str =~ /\A\$(.+?)\$/       # inline math  (tt)
        @out << '\( ' << escape_html($1) << ' \)'
        @was_math = true

#      when /\A\[\[Image\(([^|].*?)(\|(.*?))?\)\]\]/   # image 
#       @out << make_image($1, $3)

#      when /\A\{\{\s*(.*?)\s*(\|\s*(.*?)\s*)?\}\}/
#        if uri = make_image_link($1)
#          @out << make_image(uri, $3)
#        else
#          @out << escape_html($&)
#        end                             # link

      when str =~ /\A([:alpha:]|[:digit:])+/
        @out << $&                      # word
      when str =~ /\A\s+/
        @out << ' ' if @out[-1] != ?\s  # spaces
      when str =~ /\A'''''/
        toggle_tag 'strongem', $&       # bolditallic
      when str =~ /\A\*\*/ || str =~ /\A'''/
        toggle_tag 'strong', $&         # bold
      when str =~ /\A''/ || str =~ /\A\/\//
        toggle_tag 'em', $&             # italic
      when str =~ /\A\\\\/ || str =~ /\A\[\[br\]\]/i
        @out << '<br/>'                 # newline
      when str =~ /\A__/
        toggle_tag 'u', $&              # underline
      when str =~ /\A~~/
        toggle_tag 'del', $&            # delete
#      when /\A\+\+/
#        toggle_tag 'ins', $&           # insert
      when str =~ /\A\^/
        toggle_tag 'sup', $&            # ^{}
      when str =~ /\A,,/
        toggle_tag 'sub', $&            # _{}
      when str =~ /\A!([^\s])/
        @out << escape_html($1)         # !neco
      when str =~ /./
        @out << escape_html($&)         # ordinal char
      end
      return $'
    end

    def parse_table_row(str)
      start_tag('tr') if !@stack.include?('tr')
      colspan = 1
      print_tr = true
      last_tail  = ''
      last_txt  = ''
      str.scan(/(=?)(\s*)(.*?)\1?($ | \|\|\\\s*$ | \|\| )/x) do
        tdth = $1.empty? ? 'td' : 'th'
        le, txt, tail  = $2.size, $3, $4

        # do not end row, continue on next line
        print_tr = false if tail =~ /^\|\|\\/

        if txt.empty? && le == 0
          colspan += 1
          next
        end

        style = ''
        if  txt =~ /\S(\s*)$/
              ri = $1.size
              ri += 100 if tail.empty? # do not right when last || omnited
              style = " style='text-align:right'"  if ri == 0 && le >= 1
              style = " style='text-align:center'" if le >= 2 && ri >= 2
              #print "le#{le} ri#{ri} st:#{style}\n"
        end

        colspan_txt  =  colspan > 1 ? " colspan='#{colspan}'" : ''
        start_tag(tdth, style + colspan_txt);
        colspan = 1

        parse_inline(txt.strip) if txt
        end_tag while @stack.last != 'tr'
      end
      if print_tr
        end_tag
      end
    end

    def make_nowikiblock(input)
      input.gsub(/^ (?=\}\}\})/, '')
    end

    def parse_li_line(spc_size, bullet, text)

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
        attr = ""
        attr = " type='i'" if bullet =~ /i/i;
        attr = " type='a'" if bullet =~ /a/i;

        if bullet =~ /^\d+$/ && bullet != '1'
                attr += " start='#{bullet}'"
        end
        start_tag(ulol, attr, spc_size)
      end

      start_tag('li')
      parse_inline(text)

    end

    def blockquote_level_to(level)
      cur_level = @stack.count('blockquote')
      if cur_level ==  level
        @out << ' '
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

    def parse_block(str)
      until str.empty?
        case
        # pre {{{ ... }}}
        when math? && str =~ /\A\$\$(.*?)\$\$/m
          end_paragraph
          nowikiblock = make_nowikiblock($1)
          @out << "$$" << escape_html(nowikiblock) << "$$\n"
          @was_math = true
        when merge? && str =~ /\A(<{7}|={7}|>{7}|\|{7}) *(\S*).*$(\r?\n)?/
          who = $2
          merge_class = case $1[0]
                          when '<' ; 'merge-mine'
                          when '=' ; 'merge-split'
                          when '|' ; 'merge-orig'
                          when '>' ; 'merge-your'
                        end
          end_paragraph
          @out << "<div class='merge #{merge_class}'>" << escape_html(who) << "</div>\n"
        when str =~ /\A\{\{\{\r?\n(.*?)\r?\n\}\}\}/m
          end_paragraph
          nowikiblock = make_nowikiblock($1)
          @out << '<pre>' << escape_html(nowikiblock) << '</pre>'

        # horizontal rule
        when str =~ /\A\s*-{4,}\s*$/
          end_paragraph
          @out << '<hr/>'

        # heading == Wiki Ruless ==
        # heading == Wiki Ruless ==  #tag
        when str =~ /\A\s*(={1,6})\s*(.*?)\s*=*\s*(#(\S*))?\s*$(\r?\n)?/
          level = $1.size
          title= $2
          aname= $4
          end_paragraph
          @out << make_headline(level, title, aname)

        # table row
        when str =~ /\A[ \t]*\|\|(.*)$(\r?\n)?/
          if !@stack.include?('table')
            end_paragraph
            start_tag('table')
          end
          parse_table_row($1)

        # empty line
        when str =~ /\A\s*$(\r?\n)?/
          end_paragraph
        when str =~ /\A([:\w\s]+)::(\s+|\r?\n)/
          term = $1
          start_tag('dl')
          start_tag('dt')
          @out << escape_html(term)
          end_tag
          start_tag('dd')

        # li
        when str =~ /\A(\s*)([*-]|[aAIi\d]\.)\s+(.*?)$(\r?\n)?/
          parse_li_line($1.size, $2, $3)

        when str =~ /\A(>[>\s]*)(.*?)$(\r?\n)?/
          # citation
          level, quote =  $1.count('>'), $2

          start_paragraph if !@stack.include? 'p'
          blockquote_level_to(level)
          parse_inline(quote.strip)


        # ordinary line
        when str =~ /\A(\s*)(\S+.*?)$(\r?\n)?/
          spc_size, text =  $1.size, $2
          text.rstrip!

          if @stack.include?('li') ||@stack.include?('dl')

            # dl, li continuation
            parse_inline(' ')
            parse_inline(text)

          elsif spc_size > 0
            # quote continuation
            start_paragraph if !@stack.include? 'p'
            blockquote_level_to(1)
            parse_inline(text)

          else
            # real ordinary line
            start_paragraph
            parse_inline(text)
          end
        else # case str
          raise "Parse error at #{str[0,30].inspect}"
        end
        str = $'
      end
      end_paragraph
      @out
    end
  end
end
