require 'trac_wiki/parser'
require 'trac_wiki/version'

module TracWiki
  # Convert the argument in Trac format to HTML and return the
  # result. Example:
  #
  # TracWiki.creolize("**Hello ''World''**")
  # #=> "<p><strong>Hello <em>World</em></strong></p>"
  #
  # This is an alias for calling Creole#parse:
  # TracWiki.new(text).to_html
  def self.render(text, options = {})
    Parser.new(text, options).to_html
  end
end
