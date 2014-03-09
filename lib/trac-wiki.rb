require 'trac-wiki/parser'
require 'trac-wiki/tree'
require 'trac-wiki/version'
require 'trac-wiki/env'

module TracWiki
  # Convert the argument in Trac format to HTML and return the
  # result. Example:
  #
  # TracWiki.render("**Hello ''World''**")
  # #=> "<p><strong>Hello <em>World</em></strong></p>"
  #
  # This is an alias for calling Creole#parse:
  # TracWiki.new(text).to_html
  def self.render(text, options = {})
    Parser.new(text, options).to_html
  end
  def self.parser(text, options = {})
    Parser.new(text, options)
  end
end
