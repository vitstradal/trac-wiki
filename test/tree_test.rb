# encoding: UTF-8

require 'trac-wiki'
require 'pp'

class Bacon::Context
end
describe TracWiki::Parser do
 it 'should work' do 
   t = TracWiki::Tree.new
   t.tag_beg(:html)
   t.tag_beg(:body, {hus:'JAN', mistr: nil})
   t.tag(:div, {ahoj: "ahoj", bhoj: "BHOJ"})
   t.tag(:br)
   t.add("bye")
   t.add_spc
   t.add("bye ")
   t.add_spc
   t.add("bye")
   t.tag_end(:body)
   t.tag_end(:html)
   t.add('\bye')
   t.add_raw('&gt;')
   t.add_raw('&nbsp;')
   t.add_raw('&bdquo;')

   res =  "<html><body hus=\"JAN\"><div ahoj=\"ahoj\" bhoj=\"BHOJ\"/>\n<br/>bye bye bye</body></html>\\bye"
   res += "&gt;"
   res += "\u00a0"
   res += "„"

   #print "\n#{t.to_html}\n#{res}"
   t.to_html.should.equal res
 end
end
