require 'trac-wiki'

class Bacon::Context
  def tc(html, wiki, options = {})
    TracWiki.render(wiki, options).should.equal html
  end
end

describe TracWiki::Parser do
  it 'should not parse linkd' do
    tc "<p>[[ahoj]]</p>\n", "[[ahoj]]", :no_link => true
    tc "<p>[[ahoj|bhoj]]</p>\n", "[[ahoj|bhoj]]", :no_link => true
    tc "<ul><li>[[ahoj|bhoj]]</li></ul>", "* [[ahoj|bhoj]]", :no_link => true
  end
  it 'should parse bold' do
    # Bold can be used inside paragraphs
    tc "<p>This <strong>is</strong> bold</p>\n", "This **is** bold"
    tc "<p>This <strong>is</strong> bold and <strong>bold</strong>ish</p>\n", "This **is** bold and **bold**ish"

    # Bold can be used inside list items
    tc "<ul><li>This is <strong>bold</strong></li></ul>", "* This is **bold**"

    # Bold can be used inside table cells
    tc("<table><tr><td>This is <strong>bold</strong></td></tr></table>",
       "||This is **bold**||")

    # Links can appear inside bold text:
    tc("<p>A bold link: <strong><a href=\"http://example.org/\">http://example.org/</a> nice! </strong></p>\n",
       "A bold link: **http://example.org/ nice! **")

    # Bold will end at the end of paragraph
    tc "<p>This <strong>is bold</strong></p>\n", "This **is bold"

    # Bold will end at the end of list items
    tc("<ul><li>Item <strong>bold</strong></li><li>Item normal</li></ul>",
       "* Item **bold\n* Item normal")

    # Bold will end at the end of table cells
    tc("<table><tr><td>Item <strong>bold</strong></td><td>Another <strong>bold</strong></td></tr></table>",
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
    tc "<h2>ahoj</h2><p>{{toc}}</p>\n<h2>ahoj</h2>", "==ahoj==\r\n{{toc}}\r\n\r\n==ahoj==\r\n"
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
    tc "<ul><li>This is <em>italic</em></li></ul>", "* This is ''italic''"

    # Italic can be used inside table cells
    tc("<table><tr><td>This is <em>italic</em></td></tr></table>",
       "||This is ''italic''||")

    # Links can appear inside italic text:
    tc("<p>A italic link: <em><a href=\"http://example.org/\">http://example.org/</a> nice! </em></p>\n",
       "A italic link: ''http://example.org/ nice! ''")

    # Italic will end at the end of paragraph
    tc "<p>This <em>is italic</em></p>\n", "This ''is italic"

    # Italic will end at the end of list items
    tc("<ul><li>Item <em>italic</em></li><li>Item normal</li></ul>",
       "* Item ''italic\n* Item normal")

    # Italic will end at the end of table cells
    tc("<table><tr><td>Item <em>italic</em></td><td>Another <em>italic</em></td></tr></table>",
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

  it 'should parse headings' do
    # Only three differed sized levels of heading are required.
    tc "<h1>Heading 1</h1>", "= Heading 1 ="
    tc "<h2>Heading 2</h2>", "== Heading 2 =="
    tc "<h3>Heading 3</h3>", "=== Heading 3 ==="
    tc "<a name=\"HE3\"/><h3>Heading 3</h3>", "=== Heading 3 === #HE3"
    tc "<a name=\"Heading-3\"/><h3>Heading 3</h3>", "=== Heading 3 === #Heading-3"
    tc "<a name=\"Heading/3\"/><h3>Heading 3</h3>", "=== Heading 3 === #Heading/3"
    tc "<a name=\"Heading/3\"/><h3>Heading 3</h3>", "=== Heading 3 === #Heading/3  "
    tc "<a name=\"Heading&lt;3&gt;\"/><h3>Heading 3</h3>", "=== Heading 3 === #Heading<3>"
    tc "<a name=\"Heading'&quot;3&quot;'\"/><h3>Heading 3</h3>", "=== Heading 3 === #Heading'\"3\"'"
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

    #  Links can appear in paragraphs (i.e. inline item)
    tc "<p>Hello, <a href=\"world\">world</a></p>\n", "Hello, [[world]]"

    #  Named links
    tc "<p><a href=\"MyBigPage\">Go to my page</a></p>\n", "[[MyBigPage|Go to my page]]"

    #  URLs
    tc "<p><a href=\"http://www.example.org/\">http://www.example.org/</a></p>\n", "[[http://www.example.org/]]"

    #  Single punctuation characters at the end of URLs
    # should not be considered a part of the URL.
    [',','.','?','!',':',';','\'','"'].each do |punct|
      esc_punct = CGI::escapeHTML(punct)
      tc "<p><a href=\"http://www.example.org/\">http://www.example.org/</a>#{esc_punct}</p>\n", "http://www.example.org/#{punct}"
    end
    #  Nameds URLs (by example)
    tc("<p><a href=\"http://www.example.org/\">Visit the Example website</a></p>\n",
       "[[http://www.example.org/|Visit the Example website]]")

    # WRNING: Parsing markup within a link is optional
    tc "<p><a href=\"Weird+Stuff\"><strong>Weird</strong> <em>Stuff</em></a></p>\n", "[[Weird Stuff|**Weird** ''Stuff'']]"
    #tc("<p><a href=\"http://example.org/\"><img src='image.jpg'/></a></p>\n", "[[http://example.org/|{{image.jpg}}]]")

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
    tc "<p>This is my text.</p>\n<p>This is more text.</p>\n", "This is\nmy text.\n\n\nThis is\nmore text."
    tc "<p>This is my text.</p>\n<p>This is more text.</p>\n", "This is\nmy text.\n\n\n\nThis is\nmore text."

    # A list end paragraphs too.
    tc "<p>Hello</p>\n<ul><li>Item</li></ul>", "Hello\n* Item\n"

    #  A table end paragraphs too.
    tc "<p>Hello</p>\n<table><tr><td>Cell</td></tr></table>", "Hello\n||Cell||"

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
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>", "Monty Python:: \n   definition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>", "Monty Python::\ndefinition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>", "Monty Python::\r\ndefinition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>", "Monty Python::\r\n definition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>", "Monty Python:: \r\n definition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>", "Monty Python::   definition\n"
    tc "<dl><dt>Monty Python</dt><dd> definition</dd></dl>", "Monty Python:: definition\n"
    tc "<dl><dt>Monty::Python</dt><dd> definition</dd></dl>", "Monty::Python:: definition\n"
    tc "<dl><dt>::Python</dt><dd> definition</dd></dl>", "::Python:: definition\n"
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

    tc "<ul><li>Item 1 next</li></ul>", "* Item 1\n  next\n"

    #  Whitespace is optional before and after the *.
    tc("<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>",
       " * Item 1\n * Item 2\n *\t\tItem 3\n")

    #  A space is required if if the list element starts with bold text.
    tc("<ul><li><strong>Item 1</strong></li></ul>", "* **Item 1")

    #  An item ends at blank line
    tc("<ul><li>Item</li></ul><p>Par</p>\n", "* Item\n\nPar\n")

    #  An item ends at a heading
    tc("<ul><li>Item</li></ul><h1>Heading</h1>", "* Item\n= Heading =\n")

    #  An item ends at a table
    tc("<ul><li>Item</li></ul><table><tr><td>Cell</td></tr></table>", "* Item\n||Cell||\n")

    #  An item ends at a nowiki block
    tc("<ul><li>Item</li></ul><pre>Code</pre>", "* Item\n{{{\nCode\n}}}\n")

    #  An item can span multiple lines
    tc("<ul><li>The quick brown fox jumps over lazy dog.</li><li>Humpty Dumpty sat on a wall.</li></ul>",
       "* The quick\nbrown fox\n\tjumps over\nlazy dog.\n* Humpty Dumpty\nsat\t\non a wall.")

    #  An item can contain line breaks
    tc("<ul><li>The quick brown<br/>fox jumps over lazy dog.</li></ul>",
       "* The quick brown\\\\fox jumps over lazy dog.")

    #  Nested
    tc "<ul><li>Item 1<ul><li>Item 2</li></ul></li><li>Item 3</li></ul>", "* Item 1\n  * Item 2\n*\t\tItem 3\n"

    #  Nested up to 5 levels
    tc("<ul><li>Item 1<ul><li>Item 2<ul><li>Item 3<ul><li>Item 4<ul><li>Item 5</li></ul></li></ul></li></ul></li></ul></li></ul>",
       "* Item 1\n * Item 2\n   * Item 3\n    *    Item 4\n     * Item 5\n")

    tc("<ul><li>Item 1<ul><li>Item 2<ul><li>Item 3<ul><li>Item 4</li></ul></li></ul></li></ul></li><li>Item 5</li></ul>",
       "* Item 1\n * Item 2\n   * Item 3\n    *    Item 4\n* Item 5\n")

    #  ** immediatly following a list element will be treated as a nested unordered element.
    tc("<ul><li>Hello, World!<ul><li>Not bold</li></ul></li></ul>",
       "* Hello,\n  World!\n  * Not bold\n")

    #  ** immediatly following a list element will be treated as a nested unordered element.
    tc("<ol><li>Hello, World!<ul><li>Not bold</li></ul></li></ol>",
       "1. Hello,\n   World!\n  * Not bold\n")

    #  [...] otherwise it will be treated as the beginning of bold text.
    tc("<ul><li>Hello, World!</li></ul><p><strong>Not bold</strong></p>\n",
       "* Hello,\nWorld!\n\n**Not bold\n")
  end

  it 'should parse ordered lists' do
    #  List items begin with a * at the beginning of a line.
    #  An item ends at the next *
    tc "<ol><li>Item 1</li><li>Item 2</li><li>Item 3</li></ol>", "1. Item 1\n2. Item 2\n3. \t\tItem 3\n"

    #  Whitespace is optional before and after the #.
    tc("<ol><li>Item 1</li><li>Item 2</li><li>Item 3</li></ol>",
       "1. Item 1\n1.   Item 2\n4.\t\tItem 3\n")

    #  A space is required if if the list element starts with bold text.
#    tc("<ol><li><ol><li><ol><li>Item 1</li></ol></li></ol></li></ol>", "###Item 1")
    tc("<ol><li><strong>Item 1</strong></li></ol>", "1. **Item 1")

    #  An item ends at blank line
    tc("<ol><li>Item</li></ol><p>Par</p>\n", "1. Item\n\nPar\n")

    #  An item ends at a heading
    tc("<ol><li>Item</li></ol><h1>Heading</h1>", "1. Item\n= Heading =\n")

    #  An item ends at a table
    tc("<ol><li>Item</li></ol><table><tr><td>Cell</td></tr></table>", "1. Item\n||Cell||\n")

    #  An item ends at a nowiki block
    tc("<ol><li>Item</li></ol><pre>Code</pre>", "1. Item\n{{{\nCode\n}}}\n")

    #  An item can span multiple lines
    tc("<ol><li>The quick brown fox jumps over lazy dog.</li><li>Humpty Dumpty sat on a wall.</li></ol>",
       "1. The quick\nbrown fox\n\tjumps over\nlazy dog.\n2. Humpty Dumpty\nsat\t\non a wall.")

    #  An item can contain line breaks
    tc("<ol><li>The quick brown<br/>fox jumps over lazy dog.</li></ol>",
       "1. The quick brown\\\\fox jumps over lazy dog.")

    #  Nested
    tc "<ol><li>Item 1<ol><li>Item 2</li></ol></li><li>Item 3</li></ol>", "1. Item 1\n  1. Item 2\n2.\t\tItem 3\n"

    #  Nested up to 5 levels
    tc("<ol><li>Item 1<ol><li>Item 2<ol><li>Item 3<ol><li>Item 4<ol><li>Item 5</li></ol></li></ol></li></ol></li></ol></li></ol>",
       "1. Item 1\n  1. Item 2\n     1. Item 3\n      1. Item 4\n               1. Item 5\n")

    #  The two-bullet rule only applies to **.
#    tc("<ol><li><ol><li>Item</li></ol></li></ol>", "##Item")
  end

  it 'should parse ordered lists #2' do
    tc "<ol><li>Item 1</li><li>Item 2</li><li>Item 3</li></ol>", "1. Item 1\n1.    Item 2\n1.\t\tItem 3\n"
    # Nested
    tc "<ol><li>Item 1<ol><li>Item 2</li></ol></li><li>Item 3</li></ol>", "1. Item 1\n  1. Item 2\n1.\t\tItem 3\n"
    # Multiline
    tc "<ol><li>Item 1 on multiple lines</li></ol>", "1. Item 1\non multiple lines"
  end

  it 'should parse ambiguious mixed lists' do
    # ol following ul
    tc("<ul><li>uitem</li></ul><ol><li>oitem</li></ol>", "* uitem\n1. oitem\n")

    # ul following ol
    tc("<ol><li>uitem</li></ol><ul><li>oitem</li></ul>", "1. uitem\n* oitem\n")

    # 2ol following ul
    tc("<ul><li>uitem<ol><li>oitem</li></ol></li></ul>", "* uitem\n  1. oitem\n")

    # 2ul following ol
    tc("<ol><li>uitem<ul><li>oitem</li></ul></li></ol>", "1. uitem\n  * oitem\n")

    # 3ol following 3ul
#    tc("<ul><li><ul><li><ul><li>uitem</li></ul><ol><li>oitem</li></ol></li></ul></li></ul>", "***uitem\n###oitem\n")

    # 2ul following 2ol
#    tc("<ol><li><ol><li>uitem</li></ol><ul><li>oitem</li></ul></li></ol>", "##uitem\n**oitem\n")

    # ol following 2ol
#    tc("<ol><li><ol><li>oitem1</li></ol></li><li>oitem2</li></ol>", "##oitem1\n#oitem2\n")
    # ul following 2ol
#    tc("<ol><li><ol><li>oitem1</li></ol></li></ol><ul><li>oitem2</li></ul>", "##oitem1\n*oitem2\n")
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
    tc("<p><img src=\"image.jpg\" alt=\"a%22tag%22\"/></p>\n", "[[Image(image.jpg,alt=a\"tag\")]]")
    tc("<p><img src=\"image.jpg\" alt=\"a%22tag%22\"/></p>\n", "[[Image(image.jpg,alt=a\"tag\")]]", :no_link=>true)

    # Malicious links should not be converted.
    tc("<p><a href=\"javascript%3Aalert%28%22Boo%21%22%29\">Click</a></p>\n", "[[javascript:alert(\"Boo!\")|Click]]")
  end

  it 'should support character escape' do
    tc "<p>** Not Bold **</p>\n", "!** Not Bold !**"
    tc "<p>// Not Italic //</p>\n", "!// Not Italic !//"
    tc "<p>* Not Bullet</p>\n", "!* Not Bullet"
    # Following char is not a blank (space or line feed)
    tc "<p>Hello ~ world</p>\n", "Hello ~ world\n"
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
    tc "<table><tr><td>Hello</td><td>World!</td></tr></table>", "||Hello||World!||"
    tc "<table><tr><td>Hello</td><td>World!</td></tr></table>", "||Hello||\\\n||World!||"
    tc "<table><tr><td>He</td><td>llo</td><td>World!</td></tr></table>", "||He||llo||\\\n||World!||"
    tc "<table><tr><td>Hello</td><td colspan='2'>World!</td></tr></table>", "||Hello||||World!||"
    tc "<table><tr><td>Hello</td><td colspan='2'>kuk</td><td>World!</td></tr></table>", "||Hello||||kuk||\\\n||World!||"
    tc "<table><tr><td>1</td><td>2</td><td>3</td></tr><tr><td colspan='2'>1-2</td><td>3</td></tr><tr><td>1</td><td colspan='2'>2-3</td></tr><tr><td colspan='3'>1-2-3</td></tr></table>", "|| 1 || 2 || 3 ||\n|||| 1-2 || 3 ||\n|| 1 |||| 2-3 ||\n|||||| 1-2-3 ||\n"

    tc "<table><tr><td>table</td><td style='text-align:center'>center</td></tr></table>", "||table||   center  ||"
    tc "<table><tr><td>table</td><td style='text-align:right'>right</td></tr></table>", "||table||   right||"
    tc "<table><tr><td>table</td><td style='text-align:center'>center</td><td style='text-align:right'>right</td></tr></table>", "||table||  center  ||   right||"

    tc "<table><tr><td>Hello, World!</td></tr></table>", "||Hello, World!||"
    tc "<table><tr><td style='text-align:right'>Hello, Right World!</td></tr></table>", "|| Hello, Right World!||"
    tc "<table><tr><th style='text-align:right'>Hello, Right World!</th></tr></table>", "||= Hello, Right World!=||"
    tc "<table><tr><td style='text-align:center'>Hello, Centered World!</td></tr></table>", "||    Hello, Centered World!  ||"
    tc "<table><tr><th style='text-align:center'>Hello, Centered World!</th></tr></table>", "||=    Hello, Centered World!  =||"
    # Multiple columns
    tc "<table><tr><td>c1</td><td>c2</td><td>c3</td></tr></table>", "||c1||c2||c3||"
    # Multiple rows
    tc "<table><tr><td>c11</td><td>c12</td></tr><tr><td>c21</td><td>c22</td></tr></table>", "||c11||c12||\n||c21||c22||\n"
    # End pipe is optional
    tc "<table><tr><td>c1</td><td>c2</td><td>c3</td></tr></table>", "||c1||c2||c3"
    # Empty cells
    tc "<table><tr><td>c1</td><td></td><td>c2</td></tr></table>", "||c1|| ||c2"
    # Escaping cell separator
    tc "<table><tr><td>c1|c2</td><td>c3</td></tr></table>", "||c1!|c2||c3"
    # Escape in last cell + empty cell
    tc "<table><tr><td>c1</td><td>c2|</td></tr></table>", "||c1||c2!|"
    tc "<table><tr><td>c1</td><td>c2|</td></tr></table>", "||c1||c2!|"
    tc "<table><tr><td>c1</td><td>c2|</td><td></td></tr></table>", "||c1||c2| || ||"
    # Equal sign after pipe make a header
    tc "<table><tr><th>Header</th></tr></table>", "||=Header=||"

    tc "<table><tr><td>c1</td><td><a href=\"Link\">Link text</a></td><td><img src=\"Image\"/></td></tr></table>", "||c1||[[Link|Link text]]||[[Image(Image)]]||"
    tc "<table><tr><td>c1</td><td><a href=\"Link\">Link text</a></td><td><img src=\"Image\"/></td></tr></table>", "||c1||[Link|Link text]||[[Image(Image)]]||"
  end

  it 'should parse following table' do
    # table followed by heading
    tc("<table><tr><td>table</td></tr></table><h1>heading</h1>", "||table||\n=heading=\n")
    tc("<table><tr><td>table</td></tr></table><h1>heading</h1>", "||table||\n\n=heading=\n")
    # table followed by paragraph
    tc("<table><tr><td>table</td></tr></table><p>par</p>\n", "||table||\npar\n")
    tc("<table><tr><td>table</td></tr></table><p>par</p>\n", "||table||\n\npar\n")
    # table followed by unordered list
    tc("<table><tr><td>table</td></tr></table><ul><li>item</li></ul>", "||table||\n* item\n")
    tc("<table><tr><td>table</td></tr></table><ul><li>item</li></ul>", "||table||\n\n* item\n")
    # table followed by ordered list
    tc("<table><tr><td>table</td></tr></table><ol><li>item</li></ol>", "||table||\n1. item\n")
    tc("<table><tr><td>table</td></tr></table><ol><li>item</li></ol>", "||table||\n\n1. item\n")
    # table followed by horizontal rule
    tc("<table><tr><td>table</td></tr></table><hr/>", "||table||\n----\n")
    tc("<table><tr><td>table</td></tr></table><hr/>", "||table||\n\n----\n")
    # table followed by nowiki block
    tc("<table><tr><td>table</td></tr></table><pre>pre</pre>", "||table||\n{{{\npre\n}}}\n")
    tc("<table><tr><td>table</td></tr></table><pre>pre</pre>", "||table||\n\n{{{\npre\n}}}\n")
    # table followed by table
    tc("<table><tr><td>table</td></tr><tr><td>table</td></tr></table>", "||table||\n||table||\n")
    tc("<table><tr><td>table</td></tr></table><table><tr><td>table</td></tr></table>", "||table||\n\n||table||\n")
  end

  it 'should parse following heading' do
    # heading
    tc("<h1>heading1</h1><h1>heading2</h1>", "=heading1=\n=heading2\n")
    tc("<h1>heading1</h1><h1>heading2</h1>", "=heading1=\n\n=heading2\n")
    # paragraph
    tc("<h1>heading</h1><p>par</p>\n", "=heading=\npar\n")
    tc("<h1>heading</h1><p>par</p>\n", "=heading=\n\npar\n")
    # unordered list
    tc("<h1>heading</h1><ul><li>item</li></ul>", "=heading=\n* item\n")
    tc("<h1>heading</h1><ul><li>item</li></ul>", "=heading=\n\n* item\n")
    # ordered list
    tc("<h1>heading</h1><ol><li>item</li></ol>", "=heading=\n1. item\n")
    tc("<h1>heading</h1><ol><li>item</li></ol>", "=heading=\n\n1. item\n")
    # horizontal rule
    tc("<h1>heading</h1><hr/>", "=heading=\n----\n")
    tc("<h1>heading</h1><hr/>", "=heading=\n\n----\n")
    # nowiki block
    tc("<h1>heading</h1><pre>nowiki</pre>", "=heading=\n{{{\nnowiki\n}}}\n")
    tc("<h1>heading</h1><pre>nowiki</pre>", "=heading=\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<h1>heading</h1><table><tr><td>table</td></tr></table>", "=heading=\n||table||\n")
    tc("<h1>heading</h1><table><tr><td>table</td></tr></table>", "=heading=\n\n||table||\n")
  end

  it 'should parse following paragraph' do
    # heading
    tc("<p>par</p>\n<h1>heading</h1>", "par\n=heading=")
    tc("<p>par</p>\n<h1>heading</h1>", "par\n\n=heading=")
    # paragraph
    tc("<p>par par</p>\n", "par\npar\n")
    tc("<p>par</p>\n<p>par</p>\n", "par\n\npar\n")
    # unordered
    tc("<p>par</p>\n<ul><li>item</li></ul>", "par\n* item")
    tc("<p>par</p>\n<ul><li>item</li></ul>", "par\n\n* item")
    # ordered
    tc("<p>par</p>\n<ol><li>item</li></ol>", "par\n1. item\n")
    tc("<p>par</p>\n<ol><li>item</li></ol>", "par\n\n1. item\n")
    # horizontal
    tc("<p>par</p>\n<hr/>", "par\n----\n")
    tc("<p>par</p>\n<hr/>", "par\n\n----\n")
    # nowiki
    tc("<p>par</p>\n<pre>nowiki</pre>", "par\n{{{\nnowiki\n}}}\n")
    tc("<p>par</p>\n<pre>nowiki</pre>", "par\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<p>par</p>\n<table><tr><td>table</td></tr></table>", "par\n||table||\n")
    tc("<p>par</p>\n<table><tr><td>table</td></tr></table>", "par\n\n||table||\n")
  end

  it 'should parse following unordered list' do
    # heading
    tc("<ul><li>item</li></ul><h1>heading</h1>", "* item\n=heading=")
    tc("<ul><li>item</li></ul><h1>heading</h1>", "* item\n\n=heading=")
    # paragraph
    tc("<ul><li>item par</li></ul>", "* item\npar\n") # items may span multiple lines
    tc("<ul><li>item</li></ul><p>par</p>\n", "* item\n\npar\n")
    # unordered
    tc("<ul><li>item</li><li>item</li></ul>", "* item\n* item\n")
    tc("<ul><li>item</li></ul><ul><li>item</li></ul>", "* item\n\n* item\n")
    # ordered
    tc("<ul><li>item</li></ul><ol><li>item</li></ol>", "* item\n1. item\n")
    tc("<ul><li>item</li></ul><ol><li>item</li></ol>", "* item\n\n1. item\n")
    # horizontal rule
    tc("<ul><li>item</li></ul><hr/>", "* item\n----\n")
    tc("<ul><li>item</li></ul><hr/>", "* item\n\n----\n")
    # nowiki
    tc("<ul><li>item</li></ul><pre>nowiki</pre>", "* item\n{{{\nnowiki\n}}}\n")
    tc("<ul><li>item</li></ul><pre>nowiki</pre>", "* item\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<ul><li>item</li></ul><table><tr><td>table</td></tr></table>", "* item\n||table||\n")
    tc("<ul><li>item</li></ul><table><tr><td>table</td></tr></table>", "* item\n\n||table||\n")
  end

  it 'should parse following ordered list' do
    # heading
    tc("<ol><li>item</li></ol><h1>heading</h1>", "1. item\n=heading=")
    tc("<ol><li>item</li></ol><h1>heading</h1>", "1. item\n\n=heading=")
    # paragraph
    tc("<ol><li>item par</li></ol>", "1. item\npar\n") # items may span multiple lines
    tc("<ol><li>item</li></ol><p>par</p>\n", "1. item\n\npar\n")
    # unordered
    tc("<ol><li>item</li></ol><ul><li>item</li></ul>", "1. item\n* item\n")
    tc("<ol><li>item</li></ol><ul><li>item</li></ul>", "1. item\n\n*   item\n")
    # ordered
    tc("<ol><li>item</li><li>item</li></ol>", "1. item\n2. item\n")
    tc("<ol><li>item</li></ol><ol><li>item</li></ol>", "1. item\n\n1. item\n")
    # horizontal role
    tc("<ol><li>item</li></ol><hr/>", "1. item\n----\n")
    tc("<ol><li>item</li></ol><hr/>", "1. item\n\n----\n")
    # nowiki
    tc("<ol><li>item</li></ol><pre>nowiki</pre>", "1. item\n{{{\nnowiki\n}}}\n")
    tc("<ol><li>item</li></ol><pre>nowiki</pre>", "1. item\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<ol><li>item</li></ol><table><tr><td>table</td></tr></table>", "1. item\n||table||\n")
    tc("<ol><li>item</li></ol><table><tr><td>table</td></tr></table>", "1. item\n\n||table||\n")
  end

  it 'should parse following horizontal rule' do
    # heading
    tc("<hr/><h1>heading</h1>", "----\n=heading=")
    tc("<hr/><h1>heading</h1>", "----\n\n=heading=")
    # paragraph
    tc("<hr/><p>par</p>\n", "----\npar\n")
    tc("<hr/><p>par</p>\n", "----\n\npar\n")
    # unordered
    tc("<hr/><ul><li>item</li></ul>", "----\n* item")
    tc("<hr/><ul><li>item</li></ul>", "----\n* item")
    tc("<hr/><ul><li>item</li></ul>", "----\n- item")
    tc("<hr/><ul><li>item</li></ul>", "----\n- item")
    tc("<hr/><ul><li>item</li></ul>", "----\n - item")
    # ordered
    tc("<hr/><ol><li>item</li></ol>", "----\n1. item")
    tc("<hr/><ol><li>item</li></ol>", "----\n1. item")
    # horizontal
    tc("<hr/><hr/>", "----\n----\n")
    tc("<hr/><hr/>", "----\n\n----\n")
    # nowiki
    tc("<hr/><pre>nowiki</pre>", "----\n{{{\nnowiki\n}}}\n")
    tc("<hr/><pre>nowiki</pre>", "----\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<hr/><table><tr><td>table</td></tr></table>", "----\n||table||\n")
    tc("<hr/><table><tr><td>table</td></tr></table>", "----\n\n||table||\n")
  end

  it 'should parse following nowiki block' do
    # heading
    tc("<pre>nowiki</pre><h1>heading</h1>", "{{{\nnowiki\n}}}\n=heading=")
    tc("<pre>nowiki</pre><h1>heading</h1>", "{{{\nnowiki\n}}}\n\n=heading=")
    # paragraph
    tc("<pre>nowiki</pre><p>par</p>\n", "{{{\nnowiki\n}}}\npar")
    tc("<pre>nowiki</pre><p>par</p>\n", "{{{\nnowiki\n}}}\n\npar")
    # unordered
    tc("<pre>nowiki</pre><ul><li>item</li></ul>", "{{{\nnowiki\n}}}\n* item\n")
    tc("<pre>nowiki</pre><ul><li>item</li></ul>", "{{{\nnowiki\n}}}\n\n* item\n")
    # ordered
    tc("<pre>nowiki</pre><ol><li>item</li></ol>", "{{{\nnowiki\n}}}\n1. item\n")
    tc("<pre>nowiki</pre><ol><li>item</li></ol>", "{{{\nnowiki\n}}}\n\n1. item\n")
    # horizontal
    tc("<pre>nowiki</pre><hr/>", "{{{\nnowiki\n}}}\n----\n")
    tc("<pre>nowiki</pre><hr/>", "{{{\nnowiki\n}}}\n\n----\n")
    # nowiki
    tc("<pre>nowiki</pre><pre>nowiki</pre>", "{{{\nnowiki\n}}}\n{{{\nnowiki\n}}}\n")
    tc("<pre>nowiki</pre><pre>nowiki</pre>", "{{{\nnowiki\n}}}\n\n{{{\nnowiki\n}}}\n")
    # table
    tc("<pre>nowiki</pre><table><tr><td>table</td></tr></table>", "{{{\nnowiki\n}}}\n||table||\n")
    tc("<pre>nowiki</pre><table><tr><td>table</td></tr></table>", "{{{\nnowiki\n}}}\n\n||table||\n")
  end

  it 'should parse image' do
    tc("<p><img src=\"image.jpg\"/></p>\n", "[[Image(image.jpg)]]")
    tc("<p><img src=\"javascript%3Aimage.jpg\" alt=\"tag\"/></p>\n", "[[Image(javascript:image.jpg,alt=tag)]]")
    tc("<p><img src=\"image.jpg\" alt=\"tag\"/></p>\n", "[[Image(image.jpg,alt=tag)]]")
    tc("<p><img src=\"image.jpg\" width=\"120px\"/></p>\n", "[[Image(image.jpg, 120px )]]")
    tc("<p><img src=\"image.jpg\" width=\"120px\"/></p>\n", "[[Image(image.jpg, \t120px   )]]")
    tc("<p><img src=\"image.jpg\" align=\"right\"/></p>\n", "[[Image(image.jpg, right)]]")
    tc("<p><img src=\"image.jpg\" align=\"right\" valign=\"top\"/></p>\n", "[[Image(image.jpg, right,top)]]")
    tc("<p><img src=\"image.jpg\" align=\"right\" valign=\"top\"/></p>\n", "[[Image(image.jpg, top,right)]]")
    tc("<p><img src=\"image.jpg\" valign=\"top\"/></p>\n", "[[Image(image.jpg, top)]]")
    tc("<p><img src=\"image.jpg\" valign=\"top\"/></p>\n", "[[Image(image.jpg, valign=top)]]")
    tc("<p><img src=\"image.jpg\" align=\"center\"/></p>\n", "[[Image(image.jpg, center)]]")
    tc("<p><img src=\"image.jpg\" valign=\"middle\"/></p>\n", "[[Image(image.jpg, middle)]]")
    tc("<p><img src=\"image.jpg\" title=\"houhouhou\"/></p>\n", "[[Image(image.jpg, title=houhouhou)]]")
    tc("<p><img src=\"image.jpg\" width=\"120px\"/></p>\n", "[[Image(image.jpg,width=120px)]]")
    tc("<p><img src=\"image.jpg\" width=\"120%25\"/></p>\n", "[[Image(image.jpg, width=120%)]]")
    tc("<p><img src=\"image.jpg\" style=\"margin:5\"/></p>\n", "[[Image(image.jpg,margin=5)]]")
    tc("<p><img src=\"http://example.org/image.jpg\"/></p>\n", "[[Image(http://example.org/image.jpg)]]")
  end

  it 'should parse bold combo' do
    tc("<p><strong>bold and</strong></p>\n<table><tr><td>table</td></tr></table><p>end<strong></strong></p>\n",
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
end
# vim: tw=0
