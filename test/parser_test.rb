# encoding: UTF-8
require 'trac-wiki'
require 'pp'


class Bacon::Context
  def tc(html, wiki, options = {})
    options[:plugins] = { '!print' => proc { |env| env.arg(0) + '! ' }, 
                        }
    options[:template_handler] = self.method(:template_handler)

    parser = TracWiki.parser(wiki, options)
    parser.to_html.should.equal html
  end

  def template_handler(tname, env)
    case tname
    when 'ifeqtest'
      "{{!ifeq {{$1}}|{{$2}}|TRUE|FALSE}}"
    when 'vartest2'
      "{{vartest {{$1}}|{{$dva}}|p={{$p}}|{{$3   |tridef}}}}"
    when 'ytest'
      "{{$y.ahoj}},{{$y.bhoj.1}}"
    when 'ytest2'
      "{{!set i|ahoj}}{{$y.$i}},{{$y.bhoj.1}}"
    when 'vartest'
      "jedna:{{$1}},dve:{{$2}},p:{{$p}},arg:{{$arg}}"
    when 'test'
      "{{west}}"
    when 'west'
      "WEST"
    when 'deep'
      "{{deep}}"
    when 'nl'
       "line one\nline two\n"
    when 'nl2'
       "* line one\n* line two\n"
    when 'maclentest'
       "maclen:{{$maclen}}"
    when 'wide'
      "0123456789{{wide}}" * 10
    else
      nil
      #"UNK_TEMPL(#{tname})"
    end
  end
  def  h(hash, wiki, opts = {})
    parser = TracWiki.parser(wiki, opts)
    parser.to_html
    #pp parser.headers
    parser.headings.should == hash
  end
end

describe TracWiki::Parser do
  it 'should not parse linkd' do
    tc "<p>[[ahoj]]</p>\n", "[ahoj]", :no_link => true
    tc "<p>[[ahoj]]</p>\n", "[[ahoj]]", :no_link => true
    tc "<p>[[ahoj|bhoj]]</p>\n", "[[ahoj|bhoj]]", :no_link => true
    tc "<ul><li>[[ahoj|bhoj]]</li>\n</ul>\n", "* [[ahoj|bhoj]]", :no_link => true
  end
  it 'should parse bold' do
    # Bold can be used inside paragraphs
    tc "<p>This <strong>is</strong> bold</p>\n", "This **is** bold"
    tc "<p>This <strong>is</strong> bold and <strong>bold</strong>ish</p>\n", "This **is** bold and **bold**ish"

    # Bold can be used inside list items
    tc "<ul><li>This is <strong>bold</strong></li>\n</ul>\n", "* This is **bold**"

    # Bold can be used inside table cells
    tc("<table><tr><td>This is <strong>bold</strong></td>\n</tr>\n</table>\n",
       "||This is **bold**||")

    # Links can appear inside bold text:
    tc("<p>A bold link: <strong><a href=\"http://example.org/\">http://example.org/</a> nice! </strong></p>\n",
       "A bold link: **http://example.org/ nice! **")

    # Bold will end at the end of paragraph
    tc "<p>This <strong>is bold</strong></p>\n", "This **is bold"

    # Bold will end at the end of list items
    tc("<ul><li>Item <strong>bold</strong></li>\n<li>Item normal</li>\n</ul>\n",
       "* Item **bold\n* Item normal")

    # Bold will end at the end of table cells
    tc("<table><tr><td>Item <strong>bold</strong></td>\n<td>Another <strong>bold</strong></td>\n</tr>\n</table>\n",
       "||Item **bold||Another **bold||")

    # Bold should not cross paragraphs
    tc("<p>This <strong>is</strong></p>\n<p>bold<strong> maybe</strong></p>\n",
       "This **is\n\nbold** maybe")

    # Bold should be able to cross lines
    tc "<p>This <strong>is bold</strong></p>\n", "This **is\nbold**"
  end

  it 'should be toc' do
    tc "<p>{{toc}}</p>\n", "{{toc}}"
    tc "<h2>ahoj</h2><p>{{toc}}</p>\n<h2>ahoj</h2>", "==ahoj==\n{{toc}}\n\n==ahoj==\n"
    #tc "{{toc}}", "{{toc}}"
    #tc "<h2>ahoj</h2>{{toc}}<h2>ahoj</h2>", "==ahoj==\r\n{{toc}}\r\n\r\n==ahoj==\r\n"
  end

  it 'should parse bolditalic' do
    tc "<p>This is <strong><em>bolditallic</em></strong>.</p>\n", "This is '''''bolditallic'''''."
    tc "<p>This is <strong> <em>bolditallic</em> </strong>.</p>\n", "This is ''' ''bolditallic'' '''."
    tc "<p>This is <em> <strong>bolditallic</strong> </em>.</p>\n", "This is '' '''bolditallic''' ''."
    tc "<p>This is <strong>bold</strong>.</p>\n", "This is '''bold'''."
    #fuj tc '<p>This is <strong><em>bolditallic</em></strong>.</p>\n', "This is **''bolditallic**''."
  end
  it 'should parse monospace' do
    tc "<p>This is <tt>monospace</tt>.</p>\n", "This is {{{monospace}}}."
    tc "<p>This is not {{{monospace}}}.</p>\n", "This is not !{{{monospace}}}."
    tc "<p>This is <tt>mon**o**space</tt>.</p>\n", "This is {{{mon**o**space}}}."
    tc "<p>This is <tt>mon&lt;o&gt;space</tt>.</p>\n", "This is {{{mon<o>space}}}."
    tc "<p>This is <tt>mon''o''space</tt>.</p>\n", "This is {{{mon''o''space}}}."
    tc "<p>This is <tt>mon''o''space</tt>.</p>\n", "This is `mon''o''space`."
    tc "<p>This is <tt>mon{{o}}space</tt>.</p>\n", "This is {{{mon{{o}}space}}}."
    tc "<p>This is <tt>mon``o''space</tt>.</p>\n", "This is {{{mon``o''space}}}."
    tc "<p>This is <tt>mon{{o}}space</tt>.</p>\n", "This is `mon{{o}}space`."
  end

  it 'should parse italic' do
    # Italic can be used inside paragraphs
    tc("<p>This <em>is</em> italic</p>\n",
       "This ''is'' italic")
    tc("<p>This <em>is</em> italic and <em>italic</em>ish</p>\n",
       "This ''is'' italic and ''italic''ish")

    # Italic can be used inside list items
    tc "<ul><li>This is <em>italic</em></li>\n</ul>\n", "* This is ''italic''"

    # Italic can be used inside table cells
    tc("<table><tr><td>This is <em>italic</em></td>\n</tr>\n</table>\n",
       "||This is ''italic''||")

    # Links can appear inside italic text:
    tc("<p>A italic link: <em><a href=\"http://example.org/\">http://example.org/</a> nice! </em></p>\n",
       "A italic link: ''http://example.org/ nice! ''")

    # Italic will end at the end of paragraph
    tc "<p>This <em>is italic</em></p>\n", "This ''is italic"

    # Italic will end at the end of list items
    tc("<ul><li>Item <em>italic</em></li>\n<li>Item normal</li>\n</ul>\n",
       "* Item ''italic\n* Item normal")

    # Italic will end at the end of table cells
    tc("<table><tr><td>Item <em>italic</em></td>\n<td>Another <em>italic</em></td>\n</tr>\n</table>\n",
       "||Item ''italic||Another ''italic")

    # Italic should not cross paragraphs
    tc("<p>This <em>is</em></p>\n<p>italic<em> maybe</em></p>\n",
       "This ''is\n\nitalic'' maybe")

    # Italic should be able to cross lines
    tc "<p>This <em>is italic</em></p>\n", "This ''is\nitalic''"
  end

  it 'should parse bold italics' do
    # By example
    tc "<p><strong><em>bold italics</em></strong></p>\n", "**''bold italics''**"

    # By example
    tc "<p><em><strong>bold italics</strong></em></p>\n", "''**bold italics**''"

    # By example
    tc "<p><em>This is <strong>also</strong> good.</em></p>\n", "''This is **also** good.''"
  end

  it 'should parse math' do
    tc "<p><span class=\"math\">the</span></p>\n", '$the$', math: true
    tc "<p>test <span class=\"math\">the</span> west</p>\n", 'test $the$ west', math: true
    tc "<p>test <span class=\"math\">e^{i\\pi}</span> test</p>\n", 'test $e^{i\pi}$ test', math: true
    tc "<p>test $ e<sup>{i\\pi} test</sup></p>\n", 'test $ e^{i\pi} test', math: true
    tc "<p>$the$</p>\n", '$the$', math: false

    tc "<p>ahoj</p>\n<div class=\"math\">e^{i\\pi}</div>\n<p>nazdar</p>\n", "ahoj\n$$e^{i\\pi}$$\nnazdar", math: true
    tc "<p>ahoj $$e<sup>{i\\pi}$$ nazdar</sup></p>\n", "ahoj\n$$e^{i\\pi}$$\nnazdar", math: false

    tc "<div class=\"math\">\\\\</div>\n", "$$\\\\$$", math: true
    tc "<div class=\"math\">\n^test\n</div>\n", "$$\n^test\n$$", math: true

    tc "<p>$a<sup>b</sup>c$</p>\n", "!$a^b^c$", math: true
    tc "<p>$a<strong>b</strong>c$</p>\n", "!$a**b**c$", math: true
    tc "<p>!$a$</p>\n", "!!!$a$", math: true
  end
  it 'should parse headings' do
    # Only three differed sized levels of heading are required.
    tc "<h1>Heading 1</h1>", "= Heading 1 ="
    tc "<h2>Heading 2</h2>", "== Heading 2 =="
    tc "<h3>Heading 3</h3>", "=== Heading 3 ==="
    #tc "<h3>Heading 3\u00a0B</h3>", "=== Heading 3~B ==="
    tc "<h3>Heading 3&nbsp;B</h3>", "=== Heading 3~B ==="
    tc "<h3 id=\"HE3\">Heading 3</h3>", "=== Heading 3 === #HE3"
    tc "<h3 id=\"Heading-3\">Heading 3</h3>", "=== Heading 3 === #Heading-3"
    tc "<h3 id=\"Heading/3\">Heading 3</h3>", "=== Heading 3 === #Heading/3"
    tc "<h3 id=\"Heading/3\">Heading 3</h3>", "=== Heading 3 === #Heading/3  "
    tc "<h3 id=\"Heading/3\">Heading 3</h3><h3 id=\"Heading/3.2\">Heading 3</h3>",
       "=== Heading 3 === #Heading/3\n=== Heading 3 === #Heading/3\n  "
    tc "<h3 id=\"Heading&lt;3&gt;\">Heading 3</h3>", "=== Heading 3 === #Heading<3>"
    tc "<h3 id=\"Heading'&quot;3&quot;'\">Heading 3</h3>", "=== Heading 3 === #Heading'\"3\"'"
    # WARNING: Optional feature, not specified in 
    tc "<h4>Heading 4</h4>", "==== Heading 4 ===="
    tc "<h5>Heading 5</h5>", "===== Heading 5 ====="
    tc "<h6>Heading 6</h6>", "====== Heading 6 ======"

    # Closing (right-side) equal signs are optional
    tc "<h1>Heading 1</h1>", "=Heading 1"
    tc "<h2>Heading 2</h2>", "== Heading 2"
    tc "<h3>Heading 3</h3>", " === Heading 3"

    # Closing (right-side) equal signs don't need to be balanced and don't impact the kind of heading generated
    tc "<h1>Heading 1</h1>", "=Heading 1 ==="
    tc "<h2>Heading 2</h2>", "== Heading 2 ="
    tc "<h3>Heading 3</h3>", " === Heading 3 ==========="

    # Whitespace is allowed before the left-side equal signs.
    tc "<h1>Heading 1</h1>", " \t= Heading 1 ="
    tc "<h2>Heading 2</h2>", " \t== Heading 2 =="

    # Only white-space characters are permitted after the closing equal signs.
    tc "<h1>Heading 1</h1>", " = Heading 1 = "
    tc "<h2>Heading 2</h2>", " == Heading 2 == \t "

    # WARNING: !! XXX doesn't specify if text after closing equal signs
    # !!becomes part of the heading or invalidates the entire heading.
    # tc "<p> == Heading 2 == foo</p>\n", " == Heading 2 == foo"
    tc "<h2>Heading 2 == foo</h2>", " == Heading 2 == foo"

    # Line must start with equal sign
    tc "<p>foo = Heading 1 =</p>\n", "foo = Heading 1 ="
  end

  it 'should parse links' do
    #  Links
    tc "<p><a href=\"link\">link</a></p>\n", "[[link]]"
    tc "<p><a href=\"link\">Flink</a></p>\n", "[[link|Flink]]"

    # FIXME: http://trac.edgewall.org/wiki/TracLinks: this is wrong
    #tc "<p><a href=\"link\">Flink</a></p>\n", "[link Flink]"
    tc "<p><a href=\"BASE/link\">link</a></p>\n", "[[link]]",  base: 'BASE'
    tc "<p><a href=\"BASE/link\">link</a></p>\n", "[[link]]",  base: 'BASE/'
    tc "<p><a href=\"link#link\">link#link</a></p>\n", "[[link#link]]"
    tc "<p><a href=\"#link\">#link</a></p>\n", "[[#link]]"

    #  Links can appear in paragraphs (i.e. inline item)
    tc "<p>Hello, <a href=\"world\">world</a></p>\n", "Hello, [[world]]"

    #  Named links
    tc "<p><a href=\"MyBigPage\">Go to my page</a></p>\n", "[[MyBigPage|Go to my page]]"

    #  URLs
    tc "<p><a href=\"http://www.example.org/\">http://www.example.org/</a></p>\n", "[[http://www.example.org/]]"
    tc "<p><a href=\"http://www.example.org/#anch\">http://www.example.org/#anch</a></p>\n", "[[http://www.example.org/#anch]]"

    #  Single punctuation characters at the end of URLs
    # should not be considered a part of the URL.
    [',','.','?','!',':',';','\'','"'].each do |punct|
      esc_punct = TracWiki::Parser.escapeHTML(punct)
      tc "<p><a href=\"http://www.example.org/\">http://www.example.org/</a>#{esc_punct}</p>\n", "http://www.example.org/#{punct}"
    end
    #  Nameds URLs (by example)
    tc("<p><a href=\"http://www.example.org/\">Visit the Example website</a></p>\n",
       "[[http://www.example.org/|Visit the Example website]]")

    # WRNING: Parsing markup within a link is optional
    tc "<p><a href=\"Weird+Stuff\"><strong>Weird</strong> <em>Stuff</em></a></p>\n", "[[Weird Stuff|**Weird** ''Stuff'']]"
    #tc("<p><a href=\"http://example.org/\"><img src=\"image.jpg\"/></a></p>\n", "[[http://example.org/|{{image.jpg}}]]")

    # Inside bold
    tc "<p><strong><a href=\"link\">link</a></strong></p>\n", "**[[link]]**"

    # Whitespace inside [[ ]] should be ignored
    tc("<p><a href=\"link\">link</a></p>\n", "[[ link ]]")
    tc("<p><a href=\"link+me\">link me</a></p>\n", "[[ link me ]]")
    tc("<p><a href=\"http://dot.com/\">dot.com</a></p>\n", "[[ http://dot.com/ \t| \t dot.com ]]")
    tc("<p><a href=\"http://dot.com/\">dot.com</a></p>\n", "[[ http://dot.com/ | dot.com ]]")
  end

  it 'should parse freestanding urls' do
    # Free-standing URL's should be turned into links
    tc "<p><a href=\"http://www.example.org/\">http://www.example.org/</a></p>\n", "http://www.example.org/"

    # URL ending in .
    tc "<p>Text <a href=\"http://example.org\">http://example.org</a>. other text</p>\n", "Text http://example.org. other text"

    # URL ending in ),
    tc "<p>Text (<a href=\"http://example.org\">http://example.org</a>), other text</p>\n", "Text (http://example.org), other text"

    # URL ending in ).
    tc "<p>Text (<a href=\"http://example.org\">http://example.org</a>). other text</p>\n", "Text (http://example.org). other text"

    # URL ending in ).
    tc "<p>Text (<a href=\"http://example.org\">http://example.org</a>).</p>\n", "Text (http://example.org)."

    # URL ending in )
    tc "<p>Text (<a href=\"http://example.org\">http://example.org</a>)</p>\n", "Text (http://example.org)"
  end

  it 'should parse paragraphs' do
    # One or more blank lines end paragraphs.
    tc "<p>This is my text.</p>\n<p>This is more text.</p>\n", "This is\nmy text.\n\nThis is\nmore text."
    tc "<p>This is my text.</p>\n<p>This is more text.</p>\n", "This is \nmy text.\n\nThis is\nmore text."
    tc "<p>This is my text.</p>\n<p>This is more text.</p>\n", "This is\nmy text.\n\n\nThis is\nmore text."
    tc "<p>This is my text.</p>\n<p>This is more text.</p>\n", "This is\nmy text.\n\n\n\nThis is\nmore text."

    # A list end paragraphs too.
    tc "<p>Hello</p>\n<ul><li>Item</li>\n</ul>\n", "Hello\n* Item\n"

    #  A table end paragraphs too.
    tc "<p>Hello</p>\n<table><tr><td>Cell</td>\n</tr>\n</table>\n", "Hello\n||Cell||"

    #  A nowiki end paragraphs too.
    tc "<p>Hello</p>\n<pre>nowiki</pre>", "Hello\n{{{\nnowiki\n}}}\n"

    # WARNING: A heading ends a paragraph (not specced)
    tc "<p>Hello</p>\n<h1>Heading</h1>", "Hello\n= Heading =\n"
  end

  it 'should parse linebreaks' do
    #  \\ (wiki-style) for line breaks.
    tc "<p>This is the first line,<br/>and this is the second.</p>\n", "This is the first line,\\\\and this is the second."
    tc "<p>This is the first line,<br/>and this is the second.</p>\n", "This is the first line,[[br]]and this is the second."
    tc "<p>This is the first line,<br/>and this is the second.</p>\n", "This is the first line,[[Br]]and this is the second."
  end

  it 'should parse blockquote' do
    tc "<p><blockquote>Monty Python</blockquote></p>\n", "> Monty Python\n"
    tc "<p><blockquote>Monty Python q2</blockquote></p>\n", "> Monty Python\n> q2\n"
    tc "<p><blockquote>Monty Python q2</blockquote></p>\n", "> Monty Python\n>q2\n"
    tc "<p><blockquote>Monty Python <strong>q2</strong></blockquote></p>\n", "> Monty Python\n>**q2**\n"
    tc "<p><blockquote>Monty Python<blockquote>q2</blockquote></blockquote></p>\n", "> Monty Python\n> > q2\n"
    tc "<p><blockquote>Monty Python<blockquote>q2 q3</blockquote></blockquote></p>\n", "> Monty Python\n> > q2\n>>q3\n"
    tc "<p><blockquote>Monty Python<blockquote><em>q2</em></blockquote>q1</blockquote></p>\n", ">Monty Python\n> > ''q2''\n>q1"
    tc "<p><blockquote>Monty Python rules</blockquote></p>\n", "  Monty Python\n rules\n"
  end
  it 'should parse definition list' do
    # FIXME: trailing space 
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>\n", "Monty Python:: \n   definition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>\n", "Monty Python::\ndefinition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>\n", "Monty Python::\r\ndefinition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>\n", "Monty Python::\r\n definition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>\n", "Monty Python:: \r\n definition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>\n", "Monty Python::   definition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>\n", "Monty Python:: definition\n"
    tc "<dl><dt>Monty::Python</dt><dd> definition</dd></dl>\n", "Monty::Python:: definition\n"
    tc "<dl><dt>::Python</dt><dd> definition</dd></dl>\n", "::Python:: definition\n"
  end
  it 'should not parse definition list' do
    # FIXME: trailing space 
    tc "<p>Monty::Python::definition</p>\n", "Monty::Python::definition\n"
    tc "<p>bla Monty::Python bla</p>\n", "bla Monty::Python bla\n"
    tc "<p>bla Monty::Python</p>\n", "bla Monty::Python\n"
    tc "<p>Monty::Python bla</p>\n", "Monty::Python bla\n"
    tc "<p>::Python bla</p>\n", "::Python bla\n"
    tc "<p>:: Python bla</p>\n", ":: Python bla\n"
  end
  it 'should parse unordered_lists' do
    # List items begin with a * at the beginning of a line.
    # An item ends at the next *

    tc "<ul><li>Item 1 next</li>\n</ul>\n", "* Item 1\n  next\n"

    #  Whitespace is optional before and after the *.
    tc("<ul><li>Item 1</li>\n<li>Item 2</li>\n<li>Item 3</li>\n</ul>\n",
       " * Item 1\n * Item 2\n *\t\tItem 3\n")

    #  A space is required if if the list element starts with bold text.
    tc("<ul><li><strong>Item 1</strong></li>\n</ul>\n", "* **Item 1")

    #  An item ends at blank line
    tc("<ul><li>Item</li>\n</ul>\n<p>Par</p>\n", "* Item\n\nPar\n")

    #  An item ends at a heading
    tc("<ul><li>Item</li>\n</ul>\n<h1>Heading</h1>", "* Item\n= Heading =\n")

    #  An item ends at a table
    tc("<ul><li>Item</li>\n</ul>\n<table><tr><td>Cell</td>\n</tr>\n</table>\n", "* Item\n||Cell||\n")

    #  An item ends at a nowiki block
    tc("<ul><li>Item</li>\n</ul>\n<pre>Code</pre>", "* Item\n{{{\nCode\n}}}\n")

    #  An item can span multiple lines
    tc("<ul><li>The quick brown fox jumps over lazy dog.</li>\n<li>Humpty Dumpty sat on a wall.</li>\n</ul>\n",
       "* The quick\nbrown fox\n\tjumps over\nlazy dog.\n* Humpty Dumpty\nsat\t\non a wall.")

    #  An item can contain line breaks
    tc("<ul><li>The quick brown<br/>fox jumps over lazy dog.</li>\n</ul>\n",
       "* The quick brown\\\\fox jumps over lazy dog.")

    #  Nested
    tc "<ul><li>Item 1<ul><li>Item 2</li>\n</ul>\n</li>\n<li>Item 3</li>\n</ul>\n", "* Item 1\n  * Item 2\n*\t\tItem 3\n"

    #  Nested up to 5 levels
    tc("<ul><li>Item 1<ul><li>Item 2<ul><li>Item 3<ul><li>Item 4<ul><li>Item 5</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>\n",
       "* Item 1\n * Item 2\n   * Item 3\n    *    Item 4\n     * Item 5\n")

    tc("<ul><li>Item 1<ul><li>Item 2<ul><li>Item 3<ul><li>Item 4</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>\n</li>\n<li>Item 5</li>\n</ul>\n",
       "* Item 1\n * Item 2\n   * Item 3\n    *    Item 4\n* Item 5\n")

    #  ** immediatly following a list element will be treated as a nested unordered element.
    tc("<ul><li>Hello, World!<ul><li>Not bold</li>\n</ul>\n</li>\n</ul>\n",
       "* Hello,\n  World!\n  * Not bold\n")

    #  ** immediatly following a list element will be treated as a nested unordered element.
    tc("<ol><li>Hello, World!<ul><li>Not bold</li>\n</ul>\n</li>\n</ol>\n",
       "1. Hello,\n   World!\n  * Not bold\n")

    #  [...] otherwise it will be treated as the beginning of bold text.
    tc("<ul><li>Hello, World!</li>\n</ul>\n<p><strong>Not bold</strong></p>\n",
       "* Hello,\nWorld!\n\n**Not bold\n")
  end

  it 'should parse ordered lists' do
    #  List items begin with a * at the beginning of a line.
    #  An item ends at the next *
    tc "<ol><li>Item 1</li>\n<li>Item 2</li>\n<li>Item 3</li>\n</ol>\n", "1. Item 1\n2. Item 2\n3. \t\tItem 3\n"

    #  Whitespace is optional before and after the #.
    tc("<ol><li>Item 1</li>\n<li>Item 2</li>\n<li>Item 3</li>\n</ol>\n",
       "1. Item 1\n1.   Item 2\n4.\t\tItem 3\n")

    #  A space is required if if the list element starts with bold text.
#    tc("<ol><li><ol><li><ol><li>Item 1</li></ol>\n</li>\n</ol>\n</li>\n</ol>\n", "###Item 1")
    tc("<ol><li><strong>Item 1</strong></li>\n</ol>\n", "1. **Item 1")

    #  An item ends at blank line
    tc("<ol><li>Item</li>\n</ol>\n<p>Par</p>\n", "1. Item\n\nPar\n")

    #  An item ends at a heading
    tc("<ol><li>Item</li>\n</ol>\n<h1>Heading</h1>", "1. Item\n= Heading =\n")

    #  An item ends at a table
    tc("<ol><li>Item</li>\n</ol>\n<table><tr><td>Cell</td>\n</tr>\n</table>\n", "1. Item\n||Cell||\n")

    #  An item ends at a nowiki block
    tc("<ol><li>Item</li>\n</ol>\n<pre>Code</pre>", "1. Item\n{{{\nCode\n}}}\n")

    #  An item can span multiple lines
    tc("<ol><li>The quick brown fox jumps over lazy dog.</li>\n<li>Humpty Dumpty sat on a wall.</li>\n</ol>\n",
       "1. The quick\nbrown fox\n\tjumps over\nlazy dog.\n2. Humpty Dumpty\nsat\t\non a wall.")

    #  An item can contain line breaks
    tc("<ol><li>The quick brown<br/>fox jumps over lazy dog.</li>\n</ol>\n",
       "1. The quick brown\\\\fox jumps over lazy dog.")

    #  Nested
    tc "<ol><li>Item 1<ol><li>Item 2</li>\n</ol>\n</li>\n<li>Item 3</li>\n</ol>\n", "1. Item 1\n  1. Item 2\n2.\t\tItem 3\n"

    #  Nested up to 5 levels
    tc("<ol><li>Item 1<ol><li>Item 2<ol><li>Item 3<ol><li>Item 4<ol><li>Item 5</li>\n</ol>\n</li>\n</ol>\n</li>\n</ol>\n</li>\n</ol>\n</li>\n</ol>\n",
       "1. Item 1\n  1. Item 2\n     1. Item 3\n      1. Item 4\n               1. Item 5\n")

    #  The two-bullet rule only applies to **.
#    tc("<ol><li><ol><li>Item</li>\n</ol>\n</li>\n</ol>\n", "##Item")
  end

  it 'should parse ordered lists #2' do
    tc "<ol><li>Item 1</li>\n<li>Item 2</li>\n<li>Item 3</li>\n</ol>\n", "1. Item 1\n1.    Item 2\n1.\t\tItem 3\n"
    # Nested
    tc "<ol><li>Item 1<ol><li>Item 2</li>\n</ol>\n</li>\n<li>Item 3</li>\n</ol>\n", "1. Item 1\n  1. Item 2\n1.\t\tItem 3\n"
    # Multiline
    tc "<ol><li>Item 1 on multiple lines</li>\n</ol>\n", "1. Item 1\non multiple lines"
  end

  it 'should parse ambiguious mixed lists' do
    # ol following ul
    tc("<ul><li>uitem</li>\n</ul>\n<ol><li>oitem</li>\n</ol>\n", "* uitem\n1. oitem\n")

    # ul following ol
    tc("<ol><li>uitem</li>\n</ol>\n<ul><li>oitem</li>\n</ul>\n", "1. uitem\n* oitem\n")

    # 2ol following ul
    tc("<ul><li>uitem<ol><li>oitem</li>\n</ol>\n</li>\n</ul>\n", "* uitem\n  1. oitem\n")

    # 2ul following ol
    tc("<ol><li>uitem<ul><li>oitem</li>\n</ul>\n</li>\n</ol>\n", "1. uitem\n  * oitem\n")

    # 3ol following 3ul
#    tc("<ul><li><ul><li><ul><li>uitem</li>\n</ul>\n<ol><li>oitem</li>\n</ol>\n</li>\n</ul>\n</li>\n</ul>\n", "***uitem\n###oitem\n")

    # 2ul following 2ol
#    tc("<ol><li><ol><li>uitem</li>\n</ol>\n<ul><li>oitem</li>\n</ul>\n</li>\n</ol>\n", "##uitem\n**oitem\n")

    # ol following 2ol
#    tc("<ol><li><ol><li>oitem1</li>\n</ol>\n</li>\n<li>oitem2</li>\n</ol>\n", "##oitem1\n#oitem2\n")
    # ul following 2ol
#    tc("<ol><li><ol><li>oitem1</li>\n</ol>\n</li>\n</ol>\n<ul><li>oitem2</li>\n</ul>\n", "##oitem1\n*oitem2\n")
  end

  it 'should parse ambiguious italics and url' do
    # Uncommon URL schemes should not be parsed as URLs
    tc("<p>This is what can go wrong:<em>this should be an italic text</em>.</p>\n",
       "This is what can go wrong:''this should be an italic text''.")

    # A link inside italic text
    tc("<p>How about <em>a link, like <a href=\"http://example.org\">http://example.org</a>, in italic</em> text?</p>\n",
       "How about ''a link, like http://example.org, in italic'' text?")

    tc("<p>How about <em>a link, like <a href=\"http://example.org\">http://example.org</a>, in italic</em> text?</p>\n",
       "How about ''a link, like [http://example.org], in italic'' text?")

    # Another test 
    tc("<p>Formatted fruits, for example:<em>apples</em>, oranges, <strong>pears</strong> ...</p>\n",
       "Formatted fruits, for example:''apples'', oranges, **pears** ...")
  end

  it 'should parse ambiguious bold and lists' do
    tc "<p><strong> bold text </strong></p>\n", "** bold text **"
    tc "<p><blockquote><strong> bold text </strong></blockquote></p>\n", " ** bold text **"
    tc "<p><blockquote><strong> bold text </strong></blockquote></p>\n", " ** bold\ntext **"
  end

  it 'should parse nowiki' do
    # ... works as block
    tc "<pre>Hello</pre>", "{{{\nHello\n}}}\n"
    tc "<p><tt>{{{-}}}</tt></p>\n", "`{{{-}}}`\n"

    # ... works inline
    tc "<p>Hello <tt>world</tt>.</p>\n", "Hello {{{world}}}."
    tc "<p><tt>Hello</tt> <tt>world</tt>.</p>\n", "{{{Hello}}} {{{world}}}."

    # No wiki markup is interpreted inbetween
    tc "<pre>**Hello**</pre>", "{{{\n**Hello**\n}}}\n"

    # Leading whitespaces are not permitted
#    tc("<p>{{{ Hello }}}</p>\n", " {{{\nHello\n}}}")
    tc("<p>{{{ Hello<blockquote>}}}</blockquote></p>\n", "{{{\nHello\n }}}")

    # Assumed: Should preserve whitespace
    tc("<pre> \t Hello, \t \n \t World \t </pre>",
       "{{{\n \t Hello, \t \n \t World \t \n}}}\n")

    # In preformatted blocks ... one leading space is removed
    tc("<pre>nowikiblock\n}}}</pre>", "{{{\nnowikiblock\n }}}\n}}}\n")

    # In inline nowiki, any trailing closing brace is included in the span
    tc("<p>this is <tt>nowiki}</tt></p>\n", "this is {{{nowiki}}}}")
    tc("<p>this is <tt>nowiki}}</tt></p>\n", "this is {{{nowiki}}}}}")
    tc("<p>this is <tt>nowiki}}}</tt></p>\n", "this is {{{nowiki}}}}}}")
    tc("<p>this is <tt>nowiki}}}}</tt></p>\n", "this is {{{nowiki}}}}}}}")
  end

  it 'should escape html' do
    # Special HTML chars should be escaped
    tc("<p>&lt;b&gt;not bold&lt;/b&gt;</p>\n", "<b>not bold</b>")

    # Image tags should be escape
    tc("<p><img src=\"image.jpg\"/></p>\n", "[[Image(image.jpg)]]")
    tc("<p><img src=\"image.jpg\"/></p>\n", "[[Image(image.jpg)]]", :no_link=>true)
    tc("<p><img alt=\"a%22tag%22\" src=\"image.jpg\"/></p>\n", "[[Image(image.jpg,alt=a\"tag\")]]")
    tc("<p><img alt=\"a%22tag%22\" src=\"image.jpg\"/></p>\n", "[[Image(image.jpg,alt=a\"tag\")]]", :no_link=>true)

    # Malicious links should not be converted.
    tc("<p><a href=\"javascript%3Aalert%28%22Boo%21%22%29\">Click</a></p>\n", "[[javascript:alert(\"Boo!\")|Click]]")
  end

  it 'should support character escape' do
    tc "<p>** Not Bold **</p>\n", "!** Not Bold !**"
    tc "<p>// Not Italic //</p>\n", "!// Not Italic !//"
    tc "<p>* Not Bullet</p>\n", "!* Not Bullet"
    # Following char is not a blank (space or line feed)
    #tc "<p>Hello \u00a0 world</p>\n", "Hello ~ world\n"
    tc "<p>Hello &nbsp; world</p>\n", "Hello ~ world\n"
    tc "<p>Hello ! world</p>\n", "Hello ! world\n"
    tc "<p>Hello ! world</p>\n", "Hello ! world\n"
    tc "<p>Hello ! world</p>\n", "Hello !\nworld\n"
    # Not escaping inside URLs 
    tc "<p><a href=\"http://example.org/~user/\">http://example.org/~user/</a></p>\n", "http://example.org/~user/"
    tc "<p><a href=\"http://example.org/~user/\">http://example.org/~user/</a></p>\n", "[http://example.org/~user/]"
    tc "<p><a href=\"http://example.org/~user/\">http://example.org/~user/</a></p>\n", "[http://example.org/~user/]", :no_link=>true
    tc "<p><a href=\"http://example.org/~user/\">http://example.org/~user/</a></p>\n", "[[http://example.org/~user/]]", :no_link=>true
    tc "<p><a href=\"http://example.org/~user/\">http://example.org/~user/</a></p>\n", "[[http://example.org/~user/]]"

    # Escaping links
    tc "<p>http://www.example.org/</p>\n", "!http://www.example.org/"
    tc "<p>[http://www.example.org/]</p>\n", "![!http://www.example.org/]"
    tc "<p>[<a href=\"http://www.example.org/\">http://www.example.org/</a>]</p>\n", "![http://www.example.org/]"
  end

  it 'should parse horizontal rule' do
    # Four hyphens make a horizontal rule
    tc "<hr/>", "----"

    # Whitespace around them is allowed
    tc "<hr/>", " ----"
    tc "<hr/>", "---- "
    tc "<hr/>", " ---- "
    tc "<hr/>", " \t ---- \t "

    # Nothing else than hyphens and whitespace is "allowed"
    tc "<p>foo ----</p>\n", "foo ----\n"
    tc "<p>---- foo</p>\n", "---- foo\n"

    # [...] no whitespace is allowed between them
    tc "<p>-- --</p>\n", "-- -- "
    tc "<p>-- --</p>\n", "--\t-- "
  end

  it 'should parse table' do
    tc "<table><tr><td>Hello</td>\n<td>World!</td>\n</tr>\n</table>\n", "||Hello||World!||"
    tc "<table><tr><td>Hello</td>\n<td>World!</td>\n</tr>\n<tr><td>Hello</td>\n<td>World!</td>\n</tr>\n</table>\n", "||Hello||World!||\n||Hello||World!||\n\n"
    tc "<table><tr><td>Hello</td>\n<td>World!</td>\n</tr>\n<tr><td>Hello</td>\n<td>World!</td>\n</tr>\n</table>\n", "||Hello||World!||\r\n||Hello||World!||\r\n\n"
    tc "<table><tr><td>Hello</td>\n<td>World!</td>\n</tr>\n</table>\n", "||Hello||\\\n||World!||"
    tc "<table><tr><td>He</td>\n<td>llo</td>\n<td>World!</td>\n</tr>\n</table>\n", "||He||llo||\\\n||World!||"
    tc "<table><tr><td>Hello</td>\n<td colspan=\"2\">World!</td>\n</tr>\n</table>\n", "||Hello||||World!||"
    tc "<table><tr><td>Hello</td>\n<td colspan=\"2\">kuk</td>\n<td>World!</td>\n</tr>\n</table>\n", "||Hello||||kuk||\\\n||World!||"
    tc "<table><tr><td>1</td>\n<td>2</td>\n<td>3</td>\n</tr>\n<tr><td colspan=\"2\">1-2</td>\n<td>3</td>\n</tr>\n<tr><td>1</td>\n<td colspan=\"2\">2-3</td>\n</tr>\n<tr><td colspan=\"3\">1-2-3</td>\n</tr>\n</table>\n", "|| 1 || 2 || 3 ||\n|||| 1-2 || 3 ||\n|| 1 |||| 2-3 ||\n|||||| 1-2-3 ||\n"

    tc "<table><tr><td>table</td>\n<td style=\"text-align:center\">center</td>\n</tr>\n</table>\n", "||table||   center  ||"
    tc "<table><tr><td>table</td>\n<td style=\"text-align:right\">right</td>\n</tr>\n</table>\n", "||table||   right||"
    tc "<table><tr><td>table</td>\n<td style=\"text-align:center\">center</td>\n<td style=\"text-align:right\">right</td>\n</tr>\n</table>\n", "||table||  center  ||   right||"

    tc "<table><tr><td>Hello, World!</td>\n</tr>\n</table>\n", "||Hello, World!||"
    tc "<table><tr><td style=\"text-align:right\">Hello, Right World!</td>\n</tr>\n</table>\n", "|| Hello, Right World!||"
    tc "<table><tr><th style=\"text-align:right\">Hello, Right World!</th>\n</tr>\n</table>\n", "||= Hello, Right World!=||"
    tc "<table><tr><td style=\"text-align:center\">Hello, Centered World!</td>\n</tr>\n</table>\n", "||    Hello, Centered World!  ||"
    tc "<table><tr><th style=\"text-align:center\">Hello, Centered World!</th>\n</tr>\n</table>\n", "||=    Hello, Centered World!  =||"
    # Multiple columns
    tc "<table><tr><td>c1</td>\n<td>c2</td>\n<td>c3</td>\n</tr>\n</table>\n", "||c1||c2||c3||"
    # Multiple rows
    tc "<table><tr><td>c11</td>\n<td>c12</td>\n</tr>\n<tr><td>c21</td>\n<td>c22</td>\n</tr>\n</table>\n", "||c11||c12||\n||c21||c22||\n"
    # End pipe is optional
    tc "<table><tr><td>c1</td>\n<td>c2</td>\n<td>c3</td>\n</tr>\n</table>\n", "||c1||c2||c3"
    # Empty cells
    tc "<table><tr><td>c1</td>\n<td></td>\n<td>c2</td>\n</tr>\n</table>\n", "||c1|| ||c2"
    # Escaping cell separator
    tc "<table><tr><td>c1|c2</td>\n<td>c3</td>\n</tr>\n</table>\n", "||c1!|c2||c3"
    # Escape in last cell + empty cell
    tc "<table><tr><td>c1</td>\n<td>c2|</td>\n</tr>\n</table>\n", "||c1||c2!|"
    tc "<table><tr><td>c1</td>\n<td>c2|</td>\n</tr>\n</table>\n", "||c1||c2!|"
    tc "<table><tr><td>c1</td>\n<td>c2|</td>\n<td></td>\n</tr>\n</table>\n", "||c1||c2| || ||"
    # Equal sign after pipe make a header
    tc "<table><tr><th>Header</th>\n</tr>\n</table>\n", "||=Header=||"

    tc "<table><tr><td>c1</td>\n<td><a href=\"Link\">Link text</a></td>\n<td><img src=\"Image\"/></td>\n</tr>\n</table>\n", "||c1||[[Link|Link text]]||[[Image(Image)]]||"
    tc "<table><tr><td>c1</td>\n<td><a href=\"Link\">Link text</a></td>\n<td><img src=\"Image\"/></td>\n</tr>\n</table>\n", "||c1||[Link|Link text]||[[Image(Image)]]||"
  end

  it 'should parse following table' do
    # table followed by heading
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<h1>heading</h1>", "||table||\n=heading=\n")
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<h1>heading</h1>", "||table||\n\n=heading=\n")
    # table followed by paragraph
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<p>par</p>\n", "||table||\npar\n")
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<p>par</p>\n", "||table||\n\npar\n")
    # table followed by unordered list
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<ul><li>item</li>\n</ul>\n", "||table||\n* item\n")
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<ul><li>item</li>\n</ul>\n", "||table||\n\n* item\n")
    # table followed by ordered list
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<ol><li>item</li>\n</ol>\n", "||table||\n1. item\n")
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<ol><li>item</li>\n</ol>\n", "||table||\n\n1. item\n")
    # table followed by horizontal rule
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<hr/>", "||table||\n----\n")
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<hr/>", "||table||\n\n----\n")
    # table followed by nowiki block
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<pre>pre</pre>", "||table||\n{{{\npre\n}}}\n")
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<pre>pre</pre>", "||table||\n\n{{{\npre\n}}}\n")
    # table followed by table
    tc("<table><tr><td>table</td>\n</tr>\n<tr><td>table</td>\n</tr>\n</table>\n", "||table||\n||table||\n")
    tc("<table><tr><td>table</td>\n</tr>\n</table>\n<table><tr><td>table</td>\n</tr>\n</table>\n", "||table||\n\n||table||\n")
  end

  it 'should parse following heading' do
    # heading
    tc("<h1>heading1</h1><h1>heading2</h1>", "=heading1=\n=heading2\n")
    tc("<h1>heading1</h1><h1>heading2</h1>", "=heading1=\n\n=heading2\n")
    # paragraph
    tc("<h1>heading</h1><p>par</p>\n", "=heading=\npar\n")
    tc("<h1>heading</h1><p>par</p>\n", "=heading=\n\npar\n")
    # unordered list
    tc("<h1>heading</h1><ul><li>item</li>\n</ul>\n", "=heading=\n* item\n")
    tc("<h1>heading</h1><ul><li>item</li>\n</ul>\n", "=heading=\n\n* item\n")
    # ordered list
    tc("<h1>heading</h1><ol><li>item</li>\n</ol>\n", "=heading=\n1. item\n")
    tc("<h1>heading</h1><ol><li>item</li>\n</ol>\n", "=heading=\n\n1. item\n")
    # horizontal rule
    tc("<h1>heading</h1><hr/>", "=heading=\n----\n")
    tc("<h1>heading</h1><hr/>", "=heading=\n\n----\n")
    # nowiki block
    tc("<h1>heading</h1><pre>nowiki</pre>", "=heading=\n{{{\nnowiki\n}}}\n")
    tc("<h1>heading</h1><pre>nowiki</pre>", "=heading=\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<h1>heading</h1><table><tr><td>table</td>\n</tr>\n</table>\n", "=heading=\n||table||\n")
    tc("<h1>heading</h1><table><tr><td>table</td>\n</tr>\n</table>\n", "=heading=\n\n||table||\n")
  end

  it 'should parse following paragraph' do
    # heading
    tc("<p>par</p>\n<h1>heading</h1>", "par\n=heading=")
    tc("<p>par</p>\n<h1>heading</h1>", "par\n\n=heading=")
    # paragraph
    tc("<p>par par</p>\n", "par\npar\n")
    tc("<p>par</p>\n<p>par</p>\n", "par\n\npar\n")
    # unordered
    tc("<p>par</p>\n<ul><li>item</li>\n</ul>\n", "par\n* item")
    tc("<p>par</p>\n<ul><li>item</li>\n</ul>\n", "par\n\n* item")
    # ordered
    tc("<p>par</p>\n<ol><li>item</li>\n</ol>\n", "par\n1. item\n")
    tc("<p>par</p>\n<ol><li>item</li>\n</ol>\n", "par\n\n1. item\n")
    # horizontal
    tc("<p>par</p>\n<hr/>", "par\n----\n")
    tc("<p>par</p>\n<hr/>", "par\n\n----\n")
    # nowiki
    tc("<p>par</p>\n<pre>nowiki</pre>", "par\n{{{\nnowiki\n}}}\n")
    tc("<p>par</p>\n<pre>nowiki</pre>", "par\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<p>par</p>\n<table><tr><td>table</td>\n</tr>\n</table>\n", "par\n||table||\n")
    tc("<p>par</p>\n<table><tr><td>table</td>\n</tr>\n</table>\n", "par\n\n||table||\n")
  end

  it 'should parse following unordered list' do
    # heading
    tc("<ul><li>item</li>\n</ul>\n<h1>heading</h1>", "* item\n=heading=")
    tc("<ul><li>item</li>\n</ul>\n<h1>heading</h1>", "* item\n\n=heading=")
    # paragraph
    tc("<ul><li>item par</li>\n</ul>\n", "* item\npar\n") # items may span multiple lines
    tc("<ul><li>item</li>\n</ul>\n<p>par</p>\n", "* item\n\npar\n")
    # unordered
    tc("<ul><li>item</li>\n<li>item</li>\n</ul>\n", "* item\n* item\n")
    tc("<ul><li>item</li>\n</ul>\n<ul><li>item</li>\n</ul>\n", "* item\n\n* item\n")
    # ordered
    tc("<ul><li>item</li>\n</ul>\n<ol><li>item</li>\n</ol>\n", "* item\n1. item\n")
    tc("<ul><li>item</li>\n</ul>\n<ol><li>item</li>\n</ol>\n", "* item\n\n1. item\n")
    # horizontal rule
    tc("<ul><li>item</li>\n</ul>\n<hr/>", "* item\n----\n")
    tc("<ul><li>item</li>\n</ul>\n<hr/>", "* item\n\n----\n")
    # nowiki
    tc("<ul><li>item</li>\n</ul>\n<pre>nowiki</pre>", "* item\n{{{\nnowiki\n}}}\n")
    tc("<ul><li>item</li>\n</ul>\n<pre>nowiki</pre>", "* item\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<ul><li>item</li>\n</ul>\n<table><tr><td>table</td>\n</tr>\n</table>\n", "* item\n||table||\n")
    tc("<ul><li>item</li>\n</ul>\n<table><tr><td>table</td>\n</tr>\n</table>\n", "* item\n\n||table||\n")
  end

  it 'should parse following ordered list' do
    # heading
    tc("<ol><li>item</li>\n</ol>\n<h1>heading</h1>", "1. item\n=heading=")
    tc("<ol><li>item</li>\n</ol>\n<h1>heading</h1>", "1. item\n\n=heading=")
    # paragraph
    tc("<ol><li>item par</li>\n</ol>\n", "1. item\npar\n") # items may span multiple lines
    tc("<ol><li>item</li>\n</ol>\n<p>par</p>\n", "1. item\n\npar\n")
    # unordered
    tc("<ol><li>item</li>\n</ol>\n<ul><li>item</li>\n</ul>\n", "1. item\n* item\n")
    tc("<ol><li>item</li>\n</ol>\n<ul><li>item</li>\n</ul>\n", "1. item\n\n*   item\n")
    # ordered
    tc("<ol><li>item</li>\n<li>item</li>\n</ol>\n", "1. item\n2. item\n")
    tc("<ol><li>item</li>\n</ol>\n<ol><li>item</li>\n</ol>\n", "1. item\n\n1. item\n")
    # horizontal role
    tc("<ol><li>item</li>\n</ol>\n<hr/>", "1. item\n----\n")
    tc("<ol><li>item</li>\n</ol>\n<hr/>", "1. item\n\n----\n")
    # nowiki
    tc("<ol><li>item</li>\n</ol>\n<pre>nowiki</pre>", "1. item\n{{{\nnowiki\n}}}\n")
    tc("<ol><li>item</li>\n</ol>\n<pre>nowiki</pre>", "1. item\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<ol><li>item</li>\n</ol>\n<table><tr><td>table</td>\n</tr>\n</table>\n", "1. item\n||table||\n")
    tc("<ol><li>item</li>\n</ol>\n<table><tr><td>table</td>\n</tr>\n</table>\n", "1. item\n\n||table||\n")
  end

  it 'should parse following horizontal rule' do
    # heading
    tc("<hr/><h1>heading</h1>", "----\n=heading=")
    tc("<hr/><h1>heading</h1>", "----\n\n=heading=")
    # paragraph
    tc("<hr/><p>par</p>\n", "----\npar\n")
    tc("<hr/><p>par</p>\n", "----\n\npar\n")
    # unordered
    tc("<hr/><ul><li>item</li>\n</ul>\n", "----\n* item")
    tc("<hr/><ul><li>item</li>\n</ul>\n", "----\n* item")
    tc("<hr/><ul><li>item</li>\n</ul>\n", "----\n- item")
    tc("<hr/><ul><li>item</li>\n</ul>\n", "----\n- item")
    tc("<hr/><ul><li>item</li>\n</ul>\n", "----\n - item")
    # ordered
    tc("<hr/><ol><li>item</li>\n</ol>\n", "----\n1. item")
    tc("<hr/><ol><li>item</li>\n</ol>\n", "----\n1. item")
    # horizontal
    tc("<hr/><hr/>", "----\n----\n")
    tc("<hr/><hr/>", "----\n\n----\n")
    # nowiki
    tc("<hr/><pre>nowiki</pre>", "----\n{{{\nnowiki\n}}}\n")
    tc("<hr/><pre>nowiki</pre>", "----\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<hr/><table><tr><td>table</td>\n</tr>\n</table>\n", "----\n||table||\n")
    tc("<hr/><table><tr><td>table</td>\n</tr>\n</table>\n", "----\n\n||table||\n")
  end

  it 'should parse following nowiki block' do
    # heading
    tc("<pre>nowiki</pre><h1>heading</h1>", "{{{\nnowiki\n}}}\n=heading=")
    tc("<pre>nowiki</pre><h1>heading</h1>", "{{{\nnowiki\n}}}\n\n=heading=")
    # paragraph
    tc("<pre>nowiki</pre><p>par</p>\n", "{{{\nnowiki\n}}}\npar")
    tc("<pre>nowiki</pre><p>par</p>\n", "{{{\nnowiki\n}}}\n\npar")
    # unordered
    tc("<pre>nowiki</pre><ul><li>item</li>\n</ul>\n", "{{{\nnowiki\n}}}\n* item\n")
    tc("<pre>nowiki</pre><ul><li>item</li>\n</ul>\n", "{{{\nnowiki\n}}}\n\n* item\n")
    # ordered
    tc("<pre>nowiki</pre><ol><li>item</li>\n</ol>\n", "{{{\nnowiki\n}}}\n1. item\n")
    tc("<pre>nowiki</pre><ol><li>item</li>\n</ol>\n", "{{{\nnowiki\n}}}\n\n1. item\n")
    # horizontal
    tc("<pre>nowiki</pre><hr/>", "{{{\nnowiki\n}}}\n----\n")
    tc("<pre>nowiki</pre><hr/>", "{{{\nnowiki\n}}}\n\n----\n")
    # nowiki
    tc("<pre>nowiki</pre><pre>nowiki</pre>", "{{{\nnowiki\n}}}\n{{{\nnowiki\n}}}\n")
    tc("<pre>nowiki</pre><pre>nowiki</pre>", "{{{\nnowiki\n}}}\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<pre>nowiki</pre><table><tr><td>table</td>\n</tr>\n</table>\n", "{{{\nnowiki\n}}}\n||table||\n")
    tc("<pre>nowiki</pre><table><tr><td>table</td>\n</tr>\n</table>\n", "{{{\nnowiki\n}}}\n\n||table||\n")
  end

  it 'should parse image' do
    tc("<p><img src=\"image.jpg\"/></p>\n", "[[Image(image.jpg)]]")
    tc("<p><img alt=\"tag\" src=\"javascript%3Aimage.jpg\"/></p>\n", "[[Image(javascript:image.jpg,alt=tag)]]")
    tc("<p><img alt=\"tag\" src=\"image.jpg\"/></p>\n", "[[Image(image.jpg,alt=tag)]]")
    tc("<p><img src=\"image.jpg\" width=\"120px\"/></p>\n", "[[Image(image.jpg, 120px )]]")
    tc("<p><img src=\"image.jpg\" width=\"120px\"/></p>\n", "[[Image(image.jpg, \t120px   )]]")
    tc("<p><img align=\"right\" src=\"image.jpg\"/></p>\n", "[[Image(image.jpg, right)]]")
    tc("<p><img align=\"right\" src=\"image.jpg\" valign=\"top\"/></p>\n", "[[Image(image.jpg, right,top)]]")
    tc("<p><img align=\"right\" src=\"image.jpg\" valign=\"top\"/></p>\n", "[[Image(image.jpg, top,right)]]")
    tc("<p><img src=\"image.jpg\" valign=\"top\"/></p>\n", "[[Image(image.jpg, top)]]")
    tc("<p><img src=\"image.jpg\" valign=\"top\"/></p>\n", "[[Image(image.jpg, valign=top)]]")
    tc("<p><img align=\"center\" src=\"image.jpg\"/></p>\n", "[[Image(image.jpg, center)]]")
    tc("<p><img src=\"image.jpg\" valign=\"middle\"/></p>\n", "[[Image(image.jpg, middle)]]")
    tc("<p><img src=\"image.jpg\" title=\"houhouhou\"/></p>\n", "[[Image(image.jpg, title=houhouhou)]]")
    tc("<p><img src=\"image.jpg\" width=\"120px\"/></p>\n", "[[Image(image.jpg,width=120px)]]")
    tc("<p><img src=\"image.jpg\" width=\"120%25\"/></p>\n", "[[Image(image.jpg, width=120%)]]")
    tc("<p><img src=\"image.jpg\" style=\"margin:5\"/></p>\n", "[[Image(image.jpg,margin=5)]]")
    tc("<p><img src=\"http://example.org/image.jpg\"/></p>\n", "[[Image(http://example.org/image.jpg)]]")
  end

  it 'should parse bold combo' do
    tc("<p><strong>bold and</strong></p>\n<table><tr><td>table</td>\n</tr>\n</table>\n<p>end</p>\n",
       "**bold and\n||table||\nend**")
  end

  it 'should support font styles below' do
    tc("<p>This is <u>underlined</u></p>\n",
       "This is __underlined__")

    tc("<p>This is <del>deleted</del></p>\n",
       "This is ~~deleted~~")

    tc("<p>This is <sup>super</sup></p>\n",
       "This is ^super^")

    tc("<p>This is <sub>sub</sub></p>\n",
       "This is ,,sub,,")
  end

  it 'should not support signs' do
    TracWiki.render("(R)").should.not.equal "<p>&#174;</p>\n"
    TracWiki.render("(r)").should.not.equal "<p>&#174;</p>\n"
    TracWiki.render("(C)").should.not.equal "<p>&#169;</p>\n"
    TracWiki.render("(c)").should.not.equal "<p>&#169;</p>\n"
  end

  it 'should support no_escape' do
    tc("<p><a href=\"a%2Fb%2Fc\">a/b/c</a></p>\n", "[[a/b/c]]")
    tc("<p><a href=\"a%2Fb%2Fc\">a/b/c</a></p>\n", "[a/b/c]")
    tc("<p><a href=\"a/b/c\">a/b/c</a></p>\n", "[[a/b/c]]", :no_escape => true)
  end
  it 'should support merge' do
    tc "<div class=\"merge merge-orig\">orig</div>\n",     "||||||| orig", :merge => true
    tc "<div class=\"merge merge-mine\">mine</div>\n",     "<<<<<<< mine", :merge => true
    tc "<div class=\"merge merge-your\">your</div>\n",     ">>>>>>> your", :merge => true
    tc "<p>bhoj</p>\n<div class=\"merge merge-your\">your</div>\n<p>ahoj</p>\n",     "bhoj\n>>>>>>> your\nahoj", :merge => true
    tc "<div class=\"merge merge-split\"></div>\n<p>ahoj</p>\n", "=======\nahoj\n", :merge => true
    tc "<div class=\"merge merge-split\">split</div>\n", "======= split", :merge => true

    tc "<h6></h6><p>ahoj</p>\n", "=======\nahoj\n", :merge => false
  end
  it 'should compute headers' do
    h( [ {:level=>0, :sline=>1, :eline=>2},
         {:title=>"ahoj", :sline=>3, :eline=> 5, :aname=>nil, :level=>2},
       ],
       "\nahoj\n== ahoj ==\nbhoj\nchoj\n")
    h( [ {:level=>0, :sline=>1, :eline=>2},
         {:title=>"ahoj", :sline=>3, :eline => 5, :aname=>nil, :level=>2},
         {:title=>"dhoj", :sline=>6, :eline => 7, :aname=>nil, :level=>3},
       ],
       "\nahoj\n== ahoj ==\nbhoj\nchoj\n===dhoj===\nkuk\n")
    h( [ {:level=>0, :sline=>1, :eline=>2},
         {:title=>"ahoj", :sline=>3, :eline => 7, :aname=>nil, :level=>2},
         {:title=>"dhoj", :sline=>8, :eline => 9, :aname=>nil, :level=>3},
       ],
       "\nahoj\n== ahoj ==\nbhoj\nchoj\n\n\n===dhoj===\nkuk\n")
    h( [ {:level=>0, :sline=>1, :eline=>2},
         {:title=>"ah o ~'j", :sline=>3, :eline => 5, :aname=>nil, :level=>2},
         {:title=>"*dhoj",    :sline=>6, :eline => 7, :aname=>'ble', :level=>3},
       ],
       "\nahoj\n== ah o ~'j ==\nbhoj\nchoj\n===*dhoj   ===#ble\nkuk\n")
    h( [ {:level=>0, :sline=>1, :eline=>2},
         {:title=>"ah o ~'j", :sline=>3, :eline => 8, :aname=>nil, :level=>2},
         {:title=>"*dhoj", :sline=>9, :eline => 11, :aname=>'ble', :level=>3},
       ], <<eos)

ahoj
== ah o ~'j ==
{{{
==a1.5hoj==
}}}


===*dhoj   ===#ble
kuk

eos


  end
  it 'should support macro' do
    tc "<p>ahoj</p>\n" , "{{#echo \nahoj\n}}"
    tc "<h2>H2</h2>" , "{{#echo == H2 ==}}"
    tc "<h2>H2</h2>" , "{{#echo =={{#echo H2}}==}}"
    tc "<h3 id=\"test\">H3</h3>" , "{{#echo =={{#echo =H3=}}=={{#echo #test}}}}"

    tc "<p>This is correct</p>\n" , "This is {{# NOT}} correct" 
    tc "<h1>h1</h1>" , "{{# comment }}\n= h1 =\n" 
    tc "<h1>h1</h1>" , "{{# comment }}\n\n\n= h1 =\n" 
    tc "<h1>h1</h1>" , "{{# comment }}\n\n\n= h1 =\n{{# Comment2}}\n" 

    tc "<h1>h1</h1>" , "{{# co{{HUU}}mment }}\n\n\n= h1 =\n{{# Comment2}}\n" 

    tc "<p>UMACRO(macr|ahoj )</p>\n" , "{{macr\nahoj\n}}"
    tc "<p>ahoj UMACRO(macr|UMACRO(o|))</p>\n" , "ahoj {{macr{{o}}}}"
    tc "<p>ahoj UMACRO(macro|)</p>\n" , "ahoj {{macro}}"
    tc "<p>ahoj {{%macrUMACRO(o|)}}</p>\n" , "ahoj {{%macr{{o}}}}"
    tc "<p>ahoj UMACRO(macr|UMACRO(mac|<strong>o</strong>))</p>\n" , "ahoj {{macr{{mac **o**}}}}"
    tc "<p>ahoj ahoj</p>\n" , "ahoj {{$mac|ahoj}}"
  end

  it 'should do temlate' do
    tc "<p>1WEST</p>\n", "1{{west}}"
    tc "<p>2WEST</p>\n", "2{{test}}"

    # macro errors:
    tc "<p>TOO_DEEP_RECURSION(<tt>{{deep}}</tt>)3</p>\n", "{{deep}}3"
    tc "<p>TOO_LONG_EXPANSION_OF_MACRO(wide)QUIT</p>\n", "{{wide}}3"
    tc "<p>UMACRO(unknown|)3</p>\n", "{{unknown}}3"
  end
  it 'should do temlate with args' do
    tc "<p>jedna:VARTESTPARAM,dve:,p:DVE,arg:VARTESTPARAM|p=DVE</p>\n", "{{vartest VARTESTPARAM|p=DVE}}"
    tc "<p>jedna:VARTESTPARAM,dve:TRI,p:DVE,arg:VARTESTPARAM|p=DVE|TRI</p>\n", "{{vartest VARTESTPARAM|p=DVE|TRI}}"
    tc "<p>jedna:VARTESTPARAM,dve:TRI,p:DVE,arg:VARTESTPARAM|TRI|p=DVE|tridef</p>\n", "{{vartest2 VARTESTPARAM|p=DVE|dva=TRI}}"
    tc "<p>ahoj |</p>\n", "ahoj {{!}}"
    tc "<p>jedna:be||not to be,dve:,p:,arg:be||not to be</p>\n", "{{vartest be{{!}}{{!}}not to be}}"
  end
  it 'should support options' do
    tc "<h3>h1<a class=\"editheading\" href=\"?edit=1\">edit</a></h3>", "=== h1 ==", edit_heading: true
  end
  it 'should not html' do
    tc "<p>&lt;b&gt;&lt;/b&gt;</p>\n", "<b></b>\n"
    tc "<p>&lt;div&gt;&lt;script&gt;alert(666)&lt;/script&gt;&lt;/div&gt;</p>\n", "<div><script>alert(666)</script></div>\n"
  end
  it 'should entity' do
    #tc "<p>\u00a0</p>\n", "&nbsp;"
    #tc "<p>„text“</p>\n", "&bdquo;text&ldquo;"
    tc "<p>&nbsp;</p>\n", "&nbsp;"
    tc "<p>&bdquo;text&ldquo;</p>\n", "&bdquo;text&ldquo;"
  end
  it 'should plugin' do
    tc "<p>AHOJTE!</p>\n", "{{!print AHOJTE}}"
    tc "<p>test:AHOJTE! AHOJTE! </p>\n", "test:{{!print AHOJTE}}{{!print AHOJTE}}"
    tc "<p>FALSE</p>\n", "{{ifeqtest JEDNA|DVE}}"
    tc "<p>TRUE</p>\n", "{{ifeqtest JEDNA|JEDNA}}"
    tc "<p>AHOJ</p>\n", "{{!set ahoj|AHOJ}}{{$ahoj}}"
    tc "<p>BHOJ</p>\n", "{{!ifeq a|b|{{!set ahoj|AHOJ}}|{{!set ahoj|BHOJ}}}}{{$ahoj}}"
    tc "<p>AHOJ</p>\n", "{{!ifeq a|a|{{!set ahoj|AHOJ}}|{{!set ahoj|BHOJ}}}}{{$ahoj}}"
    tc "<p>TRUE</p>\n", "{{!set a|a}}{{!ifeq {{$a}}|a|TRUE|FALSE}}"
    tc "<p>FALSE</p>\n", "{{!set a|a}}{{!ifeq {{$a}}|b|TRUE|FALSE}}"
    tc "<p>,AHOJ! ,FALSE</p>\n", "{{!set a|a}},{{!print AHOJ}},{{!ifeq {{$a}}|b|TRUE|FALSE}}"
    tc "", "{{!ifeq a|b|TRUE}}"
    tc "<p>AHOJ,dve</p>\n", "{{ytest \nahoj: AHOJ\nbhoj: [ jedna, dve ]\n}}"
    tc "<p>,malo</p>\n", "{{!yset ahoj|data: [1,2]\ndesc: malo}},{{$ahoj.desc}}"
    tc "<p>,BETA</p>\n", "{{!yset ahoj|data: [ALFA,BETA]\ndesc: malo}},{{$ahoj.data.1}}"
    tc "<p>,GAMA</p>\n", "{{!yset ahoj|data: [ALFA,BETA]\ndesc: malo}},{{!set ahoj.data.3|GAMA}}{{$ahoj.data.3}}"
    tc "<p>,2</p>\n", "{{!yset ahoj|data: [1,2]\ndesc: malo}},{{$ahoj.data.1}}"
    tc "<p>AHOJ,dve</p>\n", "{{ytest2 \nahoj: AHOJ\nbhoj: [ jedna, dve ]\n}}"
    tc "<p>,,BHOJ</p>\n", "{{!set ahoj|AHOJ}},{{!set AHOJ|BHOJ}},{{$$ahoj}}"
    tc "<p>(0),(1),(2),</p>\n", "{{!for i|3|({{$i}}),}}", raw_html: true
    tc "<p>(0),(1),(2),(3),</p>\n", "{{!for i|4|({{$i}}),}}", raw_html: true
    tc "<p>,(ALFA),(BETA),</p>\n", "{{!yset data|[ALFA,BETA]}},{{!for i|data|({{$data.$i}}),}}"
    tc "<p>,(1),(2),</p>\n", "{{!yset data|[1,2]}},{{!for i|data|({{$data.$i}}),}}"
    tc "<p>,(alfa:ALFA),(beta:BETA),</p>\n", "{{!yset data|beta: BETA\nalfa: ALFA\n}},{{!for i|data|({{$i}}:{{$data.$i}}),}}"
    tc "<p>,(0:1),(1:2),</p>\n", "{{!yset data|[ 1,2 ]\n}},{{!for i|data|({{$i}}:{{$data.$i}}),}}"
    tc "<p>,</p>\n", "{{!yset data|[  ]\n}},{{!for i|data|({{$i}}:{{$data.$i}}),}}"

    tc "<p>,FALSE</p>\n", "{{!yset data|[1,2]}},{{!ifdef data.55|TRUE|FALSE}}"
    tc "<p>,TRUE</p>\n", "{{!yset data|[1,2]}},{{!ifdef data.1|TRUE|FALSE}}"
    tc "<p>,TRUE</p>\n", "{{!yset data|{a: 1, b: 2} }},{{!ifdef data.a|TRUE|FALSE}}"
    tc "<p>,FALSE</p>\n", "{{!yset data|{a: 1, b: 2} }},{{!ifdef data.q|TRUE|FALSE}}"
  end

  it 'should parse html' do
    tc "<p>alert(666)</p>\n", "<script>alert(666)</script>", raw_html: true
    tc "<p><b>T</b>E</p>\n", "<p><b>T</b>E</p>", raw_html: true
    tc "<p><span>Span</span></p>\n", "<span>Span</span>\n", raw_html: true
    tc "<p><strong><span>Span</span></strong></p>\n", "**<span>Span</span>**\n", raw_html: true
    tc "<div class=\"ahoj\">Div</div>\n", "<div class=\"ahoj\">Div</div>\n", raw_html: true
    tc "<p><strong>ahoj</strong></p>\n<div class=\"ahoj\">Div</div>\n", "**ahoj<div class=\"ahoj\">Div</div>\n", raw_html: true
    tc "<p><span>Span</span><span>Span</span></p>\n", "<span>Span</span><span>Span</span>\n", raw_html: true
    tc "<p><em><b>boldoitali</b></em>cE</p>\n", "<p>''<b>boldoitali''c</b>E</p>", raw_html: true
    tc "<p><b>blabla</b></p>\n<p>endE</p>\n", "<p><b>bla</html>bla</p>end</b>E</p>", raw_html: true
    tc "<p>baf</p>\n", "\n\n\nbaf\n\n\n", raw_html: true
    tc "<div class=\"ahoj\">Div</div>\n<p>baf</p>\n", "<div class=\"ahoj\">Div</div>\nbaf\n", raw_html: true

    tc "<p><b>BOLD</b></p>\n", "<b>BOLD</b>\n", raw_html: true
    tc "<p><br/></p>\n", "<br/>\n", raw_html: true
    tc "<p><br/></p>\n", "<br></br>\n", raw_html: true
    tc "<p><b class=\"bclass\">BOLD</b></p>\n", "<b class=\"bclass\">BOLD</b>\n", raw_html: true
    tc "<p><b class=\"bclass\">BOLD</b></p>\n", "<b bad=\"bad\" class=\"bclass\">BOLD</b>\n", raw_html: true
    tc "<p><b class=\"bclass\">BOLD</b></p>\n", "<b bad=\"bad\" class=\"bclass\">BOLD</b>\n", raw_html: true
  end
  it 'should parse link' do
    tc "<p><a href=\"#here\">Here</a></p>\n", "[[#here|Here]]"
    tc "<p><a href=\"#here+i+m\">Here</a></p>\n", "[[#here i m|Here]]"
    tc "<p><a href=\"there#i+m\">There</a></p>\n", "[[there#i m|There]]"
    tc "<p><a href=\"http://example.com/there#i+m\">There</a></p>\n", "[[there#i m|There]]", base: 'http://example.com/'
    tc "<p><a href=\"#here+i+m\">Here</a></p>\n", "[[#here i m|Here]]", base: 'http://example.com/'
  end
  it 'should parse dnl inside macro' do
    tc "<p>d<blockquote>e</blockquote></p>\n", "{{!ifeq a|b|c|d\n e}}"
    tc "<p>de</p>\n", "{{!ifeq a|b|c|d\\\n e}}"
    tc "<p>d<strong>e</strong></p>\n", "{{!ifeq a|b|c|d**\\\ne**}}"
    tc "<p>d<strong>e</strong></p>\n", "{{!ifeq a|b|c|d*\\\n*e**}}"
    tc "<p>d<strong>e</strong></p>\n", "{{!ifeq a|b|c|d*\\\r\n*e**}}"
    tc "<p>e</p>\n", "{{!ifeq a|b|c|\\\r\ne}}"
    tc "<p>a0a1a2</p>\n", "{{!for i|3|a\\\n{{$i}}}}"
    tc "<p>a0a1a2</p>\n", "{{!for i|3|a\\\n   {{$i}}}}"
  end
  it 'should parse offset' do
    tc "<p>0</p>\n", "{{$offset}}"
    tc "<p>12345-6</p>\n", "12345-{{$offset}}"
    tc "<p>žížala-7</p>\n", "žížala-{{$offset}}"
    tc "<p><strong>B</strong>-6</p>\n", "**B**-{{$offset}}"
    tc "<p><a href=\"L\">L</a>-6</p>\n", "[[L]]-{{$offset}}"
    tc "<p><a href=\"L\">4</a></p>\n", "[[L|{{$offset}}]]"
    tc "<p><a href=\"L\">3</a></p>\n", "[L|{{$offset}}]"
    tc "<p><strong>B</strong><a href=\"L\">9</a></p>\n", "**B**[[L|{{$offset}}]]"
    tc "<ul><li>2</li>\n</ul>\n", "* {{$offset}}"
    tc "<h1>2</h1>", "= {{$offset}} ="
    tc "<h1><strong>B</strong> 8</h1>", "= **B** {{$offset}} ="
    tc "<p>bla</p>\n<h1><strong>B</strong> 8</h1>", "bla\n= **B** {{$offset}} ="
    tc "<p><blockquote>2</blockquote></p>\n", "  {{$offset}}"
    tc "<table><tr><td>ahoj</td>\n<td>11</td>\n</tr>\n</table>\n", "|| ahoj || {{$offset}} ||"
    tc "<table><tr><td>ahoj</td>\n<td>13</td>\n</tr>\n</table>\n", "|| ahoj ||   {{$offset}} ||"
    tc "<table><tr><td>3</td>\n<td>20</td>\n</tr>\n</table>\n", "|| {{$offset}} ||   {{$offset}} ||"
    tc "<table><tr><td>3</td>\n<td>20</td>\n</tr>\n<tr><td>3</td>\n<td>20</td>\n</tr>\n</table>\n",
       "|| {{$offset}} ||   {{$offset}} ||\n|| {{$offset}} ||   {{$offset}} ||"
    tc "<table><tr><td>3</td>\n</tr>\n</table>\n", "|| {{$offset}} ||"
    tc "<table><tr><th>3</th>\n</tr>\n</table>\n", "||={{$offset}}=||"
    tc "<table><tr><th>4</th>\n</tr>\n</table>\n", "||= {{$offset}} =||"
    tc "<table><tr><td style=\"text-align:right\">3</td>\n</tr>\n</table>\n", "|| {{$offset}}||"
    tc "<table><tr><td style=\"text-align:center\">4</td>\n</tr>\n</table>\n", "||  {{$offset}}    ||"
    tc "<p><blockquote>2</blockquote></p>\n", "> {{$offset}}"
    tc "<p><blockquote>2<blockquote>6</blockquote></blockquote></p>\n", "> {{$offset}}\n> >   {{$offset}}"
    tc "<p>test:5,17</p>\n", "test:{{$offset}},{{$offset}}"
    tc "<p>test:5,17,<strong>31</strong></p>\n", "test:{{$offset}},{{$offset}},**{{$offset}}**"
  end
  it 'should parse offset and template' do
    tc "<p>ahoj ahoj,19</p>\n" , "ahoj {{$mac|ahoj}},{{$offset}}"
    tc "<p>ahoj line one line two ,12</p>\n" , "ahoj {{nl}},{{$offset}}"
    tc "<ul><li>line one</li>\n<li>line two,8</li>\n</ul>\n" , "{{nl2}},{{$offset}}"
    tc "<ul><li>line one</li>\n<li>line two 8</li>\n</ul>\n" , "{{nl2}} {{$offset}}"
    # in the future:
    #tc "<p>ble * line one</p>\n<ul><li>line two 8</li>\n</ul>\n" , "ble {{nl2}} {{$offset}}"
  end
  it 'should parse macro len' do
    tc "<p>11</p>\n" , "{{$maclen}}"
    tc "<p>17</p>\n" , "{{$maclen|12345}}"
    tc "<p>18</p>\n" , "{{$maclen| 12345}}"
    tc "<p>19</p>\n" , "{{$maclen | 12345}}"
    tc "<p>18</p>\n" , "{{$maclen |12345}}"
    tc "<p>18</p>\n" , "{{$maclen |12345}}"
    tc "<p>15</p>\n" , "{{$maclen|kuk}}"
    tc "<p>15</p>\n" , "{{$maclen|123}}"
    tc "<p>18</p>\n" , "{{$maclen|žížala}}"
    tc "<p>37</p>\n" , "{{$maclen|{{$maclen}}{{!echo ahoj}}}}"
    tc "<p><strong>37</strong></p>\n" , "**{{$maclen|{{$maclen}}{{!echo ahoj}}}}**"
    tc "<p>28</p>\n" , "{{$maclen|a=e|b=c|d={{$e}}}}"
    tc "<p>maclen:14</p>\n" , "{{maclentest}}"
  end
  it 'should parse lineno' do
    tc "<p>1</p>\n" , "{{$lineno}}"
    tc "<p>3</p>\n" , "\n\n{{$lineno}}"
    tc "<p><strong>ahoj</strong></p>\n<p>4</p>\n" , "**ahoj**\n\n\n{{$lineno}}"
    tc "<pre>ahoj</pre><p>4</p>\n" , "{{{\nahoj\n}}}\n{{$lineno}}"
    tc "<div class=\"math\">\nahoj\n</div>\n<p>4</p>\n" , "$$\nahoj\n$$\n{{$lineno}}", math: true
    tc "<p>WEST WEST 3</p>\n" , "{{test}}\n{{test}}\n{{$lineno}}"
    tc "<p>WEST 2</p>\n" , "{{test}}\n{{$lineno}}"
    tc "<p>line one line two 1</p>\n" , "{{nl}} {{$lineno}}"
    tc "<ul><li>line one</li>\n<li>line two 1</li>\n</ul>\n" , "{{nl2}} {{$lineno}}"
    tc "<ul><li>line one</li>\n<li>line two 2</li>\n</ul>\n" , "{{nl2}}\n{{$lineno}}"
    tc "<ul><li>line one</li>\n<li>line twoline one line two 3</li>\n</ul>\n" , "\n{{nl2}}{{nl}}\n{{$lineno}}"
    tc "<h2>ahoj</h2><p>2</p>\n<h2>ahoj</h2><p>5</p>\n", "==ahoj==\n{{$lineno}}\n\n==ahoj==\n{{$lineno}}"
    tc "<table><tr><td>This is <strong>bold</strong></td>\n</tr>\n</table>\n<p>2</p>\n", "||This is **bold**||\n{{$lineno}}"
    tc "<ul><li>[[ahoj|bhoj]]</li>\n</ul>\n<p>3</p>\n", "* [[ahoj|bhoj]]\n\n{{$lineno}}", :no_link => true
    tc "<ul><li>[[ahoj|bhoj]] 2</li>\n</ul>\n", "* [[ahoj|bhoj]]\n{{$lineno}}", :no_link => true
  end
end
# vim: tw=0
