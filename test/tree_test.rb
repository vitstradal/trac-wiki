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

   res =  "<html><body hus=\"JAN\"><div ahoj=\"ahoj\" bhoj=\"BHOJ\"/>\n<br/>bye bye bye</body></html>\\bye"

   #print "\n#{t.to_html}\n#{res}"
   t.to_html.should.equal res
 end
end
