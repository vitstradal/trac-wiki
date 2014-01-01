require 'cgi'
require 'uri'
require 'iconv'
require 'yaml'

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
  class TooLongException < Exception
  end



  class Env
    def initialize(parser, env = {})
      @parser = parser
      @env = env
    end

    def parse_macro_all(macro_name, str)
      #print "macro_all: #{macro_name}, str:#{str}.\n"
      if macro_name =~ /\A!/
         # {{!cmd}}
         mac_out, rest, lines = parse_macro_cmd(macro_name, str)
      else
         # {{$cmd}},  {{template}}, ...
         mac_out, rest, lines = parse_macro_vartempl(macro_name, str)
      end
      return mac_out || '', rest, lines
    end

    # read to args to }}  (while balancing {{ and }})
    # ret: (arg, rest, lines)
    # mac_out  -- string to }} (macros inside expanded)
    # rest -- str aftrer }}
    # lines -- howmany \n eaten from str (from begining to }})
    def parse_macro_vartempl(macro_name, str)
      str_orig = str
      lines = 0
      arg = ''
      # FIXME: MACRO_REX
      #              prefix  }}...    {{macro_name
      while str =~ TracWiki::Parser::MACRO_END_REX
        prefix, bracket, sub_macro_name, str = $1, $2, $3, $'
        arg << prefix
        lines += prefix.count("\n")
        if bracket == '}}'
          #print "prefix: #{prefix}\n"
          return do_macro_var($1, arg), str, lines if macro_name =~ /^\$(.*)/
          return do_macro_templ(macro_name, arg), str, lines
        end

        # we need to go deeper!
        mac_out, str, l = parse_macro_all(sub_macro_name, str)
        arg << mac_out
        lines += l
      end
      print "Error parsing macro(#{macro_name}) near '#{str}'(#{str_orig}) (arg:#{arg}, lines=#{lines})\n"
      raise "Error parsing macro near '#{str}' (arg:#{arg}, lines=#{lines})"
    end

    # parse to next }} (with balanced {{..}})
    # like parse_macro_vartempl but not expand content
    # r: [expansion, rest_of_str, count_of_consumed_lines]
    def parse_macro_cmd(macro_name, str)
      str.sub!(/\A\s*\|?/, '')
      return do_macro_cmd(macro_name, []), $', 0 if str =~ /\A}}/
      #print "parse_macro_cmd: #{macro_name}, str#{str}\n"
      dep = 0
      lines = 0
      args = ['']
      while str =~ /{{|}}|\|/
        prefix, match  = $`, $&
        args[-1] += prefix
        lines += prefix.count("\n")
        if match == '{{'
          dep += 1
          args[-1]  += $&
        elsif match == '}}'
          dep -= 1
          return do_macro_cmd(macro_name, args), $', lines if dep < 0
          args[-1]  += $&
        elsif match == '|' && dep == 0
          args.push('')
        else
          args[-1]  += $&
        end
        str = $'
      end
      raise "eol in parsing macro params"
    end

    # calls {{!cmd}} (if exists
    # r: result of  {{!cmd}}
    def do_macro_cmd(macro_name, args)
      return '|' if macro_name == '!'
      if @parser.plugins.key?(macro_name)
        @env['args'] =  args
        @env['arg0'] =  macro_name
        #print "mac: #{macro_name} env:" ; pp (@env)
        ret = @parser.plugins[macro_name].call(self)
        return ret
      end
      "UCMD(#{macro_name}|#{@env['arg']})"
    end
    def arg(idx)
      @env['args'][idx] || ''
    end

    def prepare_y
      return if @env.key? 'y'
      arg = @env['arg']
      return if arg.nil?
      begin
        @env['y'] = YAML.load(arg)
        #print "y"
        #pp @env['y']
      rescue
        @env['y'] = nil
        #print "y:nil\n"
      end
    end

    def at(key, default = nil, to_str = true)
      #print "at(#{key}), env:"
      #pp @env
      return @env[key] || default if key.is_a? Symbol
      prepare_y if key =~ /^y\./
      cur = @env
      key.split(/\./).each do |subkey|
        subkey = at($1, '') if subkey =~ /\A\$(.*)/
        #print "at:subkey: #{subkey}\n"
        if  cur.is_a? Hash
          cur = cur[subkey]
        elsif cur.is_a? Array
          cur = cur[subkey.to_i]
        else
          #print "at(#{key})->: default"
          return default
        end
        #print "at(#{key}) -> default\n" if cur.nil?
        return default if cur.nil?
      end
      #print "at(#{key})->#{cur}\n"
      to_str ? cur.to_s : cur
    end
    def atput(key, val = nil)
      #print "atput: #{key}, #{val} env:"
      #pp @env
      cur = @env
      if val.is_a? Symbol
        @env[key] = val
        return
      end
      keys = key.split(/\./)
      lastkey = keys.pop
      keys.each do |subkey|
        if cur.is_a? Hash
          cur = cur[subkey]
        elsif cur.is_a? Array
          cur = cur[subkey.to_i]
        else
          return
        end
      end
      if  cur.is_a? Hash
        cur[lastkey] = val
      elsif cur.is_a? Array
        cur[lastkey.to_i] = val
      end
      #print "atput:env:"
      #pp @env
    end

    def [](key)
      at(key)
    end

    def []=(key,val)
      #print "set #{key} to #{val}\n"
      atput(key,val)
    end

    # expand macro `macro_name` with `args`
    # afer expansion all {{macros}} will be expanded recursively
    # r: expanded string
    def do_macro_templ(macro_name, arg)
      return "!{{toc}}" if macro_name == 'toc'
      return arg.strip  if macro_name == '#echo'
      return '' if macro_name == '#'

      env = do_macro_arg_to_env(arg, @env[:depth])

      #print "templ:#{macro_name}env:"
      #pp(env)

      if ! @parser.template_handler.nil?
        str = @parser.template_handler.call(macro_name, env)
        if !str.nil?
          #print "dep:#{env[:depth]}(#{macro_name}, #{str})\n"
          if env[:depth] > 32
             return "TOO_DEEP_RECURSION(`#{str}`)\n"
             #return "TOO_DEEP_RECURSION"
          end
          # FIXME: melo by nahlasit jestli to chce expandovat | wiki expadnovat |raw html
          #print "temp(#{macro_name}) --> : #{str}\n"
          str = env.expand(str)
          return str
        end
      end
      #print "UMACRO(#{macro_name}|#{arg})\n"
      "UMACRO(#{macro_name}|#{arg})"
    end

    def do_macro_arg_to_env(arg, depth)
      arg.sub!(/\A\s*\|?/, '')
      env  = { 'arg' => arg , depth: (depth||0) + 1  }
      idx = 1
      arg.split(/\|/).each do |val|
        if val =~ /\A\s*(\w+)\s*=\s*(.*)/s
          env[$1] = $2
        else
          env[idx.to_s] = val
          idx+=1
        end
      end
      return Env.new(@parser, env)
    end

    def do_macro_var(var_name, arg)
      #print "var(#{var_name})env:"
      #pp(@env)
      ret = at(var_name, nil)
      return ret if !ret.nil?
      return arg.sub(/\A\s*\|?/, '') if arg
      "UVAR(#{macro_name}|#{@env['arg']})"
    end

    # template expand
    def expand_arg(idx)
      expand(@env['args'][idx])
    end

    def expand(str)
      ret = ''
      return '' if str.nil?
      while str =~ TracWiki::Parser::MACRO_BEG_INSIDE_REX
          prefix, macro_name2, str = $1, $2, $'
          ret << prefix
          # FIXME if macro_name2 =~ /^!/
          mac_out, str, lines = parse_macro_all(macro_name2, str)
          ret << mac_out
          #print "Too long macro expadion" if ret.size > 1_000_000
          raise TooLongException if ret.size > 1_000_000
      end
      #print "text: #{text.nil?}\n"
      #print "ret: #{ret.nil?}\n"
      return ret + str
    end
  end

  class Parser

    # Allowed url schemes
    # Examples: http https ftp ftps
    attr_accessor :allowed_schemes

    attr_accessor :headings
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

    attr_writer :math
    def math?; @math; end

    # allow {{{! ... html ... }}}
    # html will be sanitized
    # {{{!\n html here  \n}}}\n
    attr_writer :raw_html
    def raw_html?; @raw_html; end

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

    # every heading will had id, generated from heading text
    attr_writer :id_from_heading
    def id_from_heading?; @id_from_heading; end

    # when id_from_heading, non ascii char are transliterated to ascii
    attr_writer :id_translit
    attr_accessor :plugins
    @plugins = {}

    # string begins with macro
    MACRO_BEG_REX =  /\A\{\{ ( \$[\$\.\w]+ | [\#!]\w* |\w+ ) /x
    MACRO_BEG_INSIDE_REX =  /(.*?)(?<!\{)\{\{ ( \$[\$\.\w]+ | [\#!]\w* | \w+ ) /x
    # find end of marcro or begin of inner macro
    MACRO_END_REX =  /\A(.*?) ( \}\} | \{\{ ( \$[\$\.\w]+ | [\#!]\w* | \w+)  )/mx
    def id_translit?; @id_translit; end

    # Create a new Parser instance.
    def initialize(text, options = {})
      init_plugins
      @allowed_schemes = %w(http https ftp ftps)
      @anames = {}
      plugins = options.delete :plugins
      @plugins.merge! plugins if ! plugins.nil?
      @text = text
      @no_escape = nil
      @base = ''
      options.each_pair {|k,v| send("#{k}=", v) }
      @base += '/' if !@base.empty? && @base[-1] != '/'
    end

    def init_plugins
      @plugins = {
        '!html'  => proc { |env| "\n{{{!\n#{env.arg(0)}\n}}}\n" },
        '!ifeq'  => proc { |env| env.expand_arg(0) == env.expand_arg(1) ? env.expand_arg(2) : env.expand_arg(3) },
        '!set'   => proc { |env| env[env.expand_arg(0)] = env.expand_arg(1); '' },
        '!yset'  => proc { |env| env[env.expand_arg(0)] = YAML.load(env.arg(1)); '' },
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
                                 else
                                   print "error top(#{top}), set#{set} #{set.class}\n"
                                   pp env
                                   return 'Error'
                                 end
                               end
                               set.map do |i|
                                 env[i_name] = i.to_s
                                 env.expand(tmpl)
                               end.join('')
                       },
      }

    end

    # th(macroname) -> template_text
    attr_accessor :template_handler

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

    def add_plugin(name, &block)
        @plugins[name] = block
    end



    protected

    # Escape any characters with special meaning in HTML using HTML
    # entities. (&<>" not ')
    def escape_html(string)
      #CGI::escapeHTML(string)
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

    def start_paragraph
      if @p
        #FIXME: multiple space s
        @tree.add_spc
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
      return "#{@base}#{link}" if no_escape?
      link, anch = link.split(/#/, 2)
      return "#{@base}#{escape_url(link)}" if ! anch
      "#{@base}#{escape_url(link)}##{escape_url(anch)}"
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
      #"<img src=\"#{make_explicit_link(uri)}\"#{make_image_attrs(attrs)}/>"
      @tree.tag(:img, make_image_attrs(uri, attrs))
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

    def make_headline(level, text, aname)

      hN = "h#{level}".to_sym

      @tree.tag_beg(hN, { id: aname } )
      parse_inline(text)
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

    def parse_inline(str)
      until str.empty?
        case str
        # raw url
        when /\A(!)?((https?|ftps?):\/\/\S+?)(?=([\]\,.?!:;"'\)]+)?(\s|$))/
          str = $'
          if $1
            @tree.add($2)
          else
            if uri = make_direct_link($2)
              @tree.tag(:a, {href:uri}, $2)
            else
              @tree.add($&)
            end
          end
        # [[Image(pic.jpg|tag)]]
        when /\A\[\[Image\(([^,]*?)(,(.*?))?\)\]\]/   # image 
          str = $'
          make_image($1, $3)
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
        @tree.tag(:br)
        return
      end
      uri = make_explicit_link(link)
      if not uri
        @tree.add(whole)
        return
      end

      if no_link?
        if uri !~ /^(ftp|https?):/
          @tree.add(whole)
          return
        end
      end

      @tree.tag_beg(:a, {href:uri})
      if content
        until content.empty?
          content = parse_inline_tag(content)
        end
      else
          @tree.add(link)
      end
      @tree.tag_end(:a)
    end

    def parse_inline_tag(str)
      case
      when str =~ /\A\{\{\{(.*?\}*)\}\}\}/     # inline pre (tt)
        @tree.tag(:tt, $1)
      when str =~ MACRO_BEG_REX                # macro  {{
        str, lines = parse_macro($1, $')
        #print "MACRO.inline(#{$1}), next:#{str}"
        return str
      when str =~ /\A`(.*?)`/                  # inline pre (tt)
        @tree.tag(:tt, $1)
      when math? && str =~ /\A\$(.+?)\$/       # inline math  (tt)
        @tree.add("\\( #{$1} \\)")
        #@tree.add("$#{$1}$")
        #@tree.tag(:span, {class:'math'},  $1)
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
#      when /\A\+\+/
#        toggle_tag 'ins', $&           # insert
      when str =~ /\A\^/
        toggle_tag 'sup', $&            # ^{}
      when str =~ /\A,,/
        toggle_tag 'sub', $&            # _{}
      when str =~ /\A!(\{\{|[^\s])/
        @tree.add($1)                   # !neco !{{
      when str =~ /./
        @tree.add($&)                   # ordinal char
      end
      return $'
    end

    #################################################################
    # macro {{ }}
    #  convetntion {{!cmd}} {{template}} {{$var}} {{# comment}} {{!}} (pipe)

    # r: expanded macro + rest of str, count lines taken from str
    # sideefect: parse result of macro
    def parse_macro(macro_name, str)
      @env = Env.new(self) if @env.nil?
      begin
        mac_out, rest, lines = @env.parse_macro_all(macro_name, str)
        return mac_out + rest, lines
      rescue  TooLongException => e
        return "TOO_LONG_EXPANSION_OF_MACRO(#{macro_name})QUIT", 0
      end
    end



    #################################################################


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

        type = nil
        type = 'i' if bullet =~ /i/i;
        type = 'a' if bullet =~ /a/i;

        start = nil
        start = bullet if bullet =~ /^\d+$/ && bullet != '1'

        start_tag(ulol, {type: type, start: start}, spc_size)
      end

      start_tag('li')
      parse_inline(text)

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
      @tree.add("$$#{text}$$\n")
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

    def do_raw_html(text)
      end_paragraph
      @tree.add_raw(text)
    end

    def do_hr
      end_paragraph
      @tree.tag(:hr)
    end

    def do_heading(level, title, aname)
      aname= aname_nice(aname, title)
      @headings.last[:eline] = @line_no - 1
      @headings.push({ :title =>  title, :sline => @line_no, :aname => aname, :level => level, })
      end_paragraph
      make_headline(level, title, aname)
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

    def do_citation(level, quote) 
      start_paragraph if !@stack.include? 'p'
      blockquote_level_to(level)
      parse_inline(quote.strip)
    end

    def do_ord_line(spc_size, text)
      text.rstrip!

      if @stack.include?('li') || @stack.include?('dl')

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
    end

    def parse_block(str)
      #print "BLOCK.str(#{str})\n"
      until str.empty?
        case
        # macro
        when str =~ MACRO_BEG_REX
          str, lines = parse_macro($1, $')
          #print "MACRO.block(#{$1})next:#{str}\n"
          @line_no += lines
          next
        # display math $$
        when math? && str =~ /\A\$\$(.*?)\$\$/m
          do_math($1)
        # merge
        when merge? && str =~ /\A(<{7}|={7}|>{7}|\|{7}) *(\S*).*$(\r?\n)?/
          do_merge($1, $2)
        # raw_html {{{! ... }}}
        when raw_html? && str =~ /\A\{\{\{!\r?\n(.*?)\r?\n\}\}\}/m
          do_raw_html($1)
        # pre {{{ ... }}}
        when str =~ /\A\{\{\{\r?\n(.*?)\r?\n\}\}\}/m
          do_pre($1)
        # horizontal rule
        when str =~ /\A\s*-{4,}\s*$/
          do_hr()
        # heading == Wiki Ruless ==
        # heading == Wiki Ruless ==  #tag
        when str =~ /\A[[:blank:]]*(={1,6})\s*(.*?)\s*=*\s*(#(\S*))?\s*$(\r?\n)?/
          do_heading($1.size, $2, $4)
        # table row ||
        when str =~ /\A[ \t]*\|\|(.*)$(\r?\n)?/
          do_table_row($1)
        # empty line
        when str =~ /\A\s*$(\r?\n)?/
          end_paragraph
        when str =~ /\A([:\w\s]+)::(\s+|\r?\n)/
          do_term($1)
        # li
        when str =~ /\A(\s*)([*-]|[aAIi\d]\.)\s+(.*?)$(\r?\n)?/
          parse_li_line($1.size, $2, $3)
        # citation
        when str =~ /\A(>[>\s]*)(.*?)$(\r?\n)?/
          do_citation($1.count('>'), $2)
        # ordinary line
        when str =~ /\A(\s*)(\S+.*?)$(\r?\n)?/
          do_ord_line($1.size, $2)
        else # case str
          raise "Parse error at #{str[0,30].inspect}"
        end
        @line_no += ($`+$&).count("\n")
        str = $'
      end
      end_paragraph
      @headings.last[:eline] = @line_no - 1
    end

    def aname_nice(aname, title)

      if aname.nil? && id_from_heading?
        aname = title.gsub /\s+/, '_'
        if id_translit?
          aname = Iconv.iconv('ascii//translit', 'utf-8', aname).join
        end
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
  end
end
