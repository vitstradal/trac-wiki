# encoding: UTF-8

require 'trac-wiki'
require 'pp'

class Bacon::Context
end
describe TracWiki::Parser do
 it 'should work' do 
   t = TracWiki::Tree.new
   t.tag_beg(:div, {:class => 'html'})
   t.tag_beg(:div, {id:'JAN', class: nil})
   t.tag(:div, {:class =>  "ahoj", id: "BHOJ"})
   t.tag(:br)
   t.add("bye")
   t.add_spc
   t.add("bye ")
   t.add_spc
   t.add("bye")
   t.tag_end(:div)
   t.tag_end(:div)
   t.add('\bye')
   t.add_raw('&gt;')
   t.add_raw('&nbsp;')
   t.add_raw('&bdquo;')

   res =  "<div class=\"html\"><div id=\"JAN\"><div class=\"ahoj\" id=\"BHOJ\"></div>\n<br/>bye bye bye</div>\n</div>\n\\bye"
   res += "&gt;"
   #res += "\u00a0"
   #res += "„"
   res += '&nbsp;'
   res += '&bdquo;'

   #print "\n#{t.to_html}\n#{res}"
   t.to_html.should.equal res
 end
end
