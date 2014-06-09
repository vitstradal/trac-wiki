require 'pp'
module TracWiki

    class RawHtml
      def initialize(text)
        @text = text
      end
      def to_s
        @text
      end
    end

    class Node
      attr_accessor :tag
      attr_accessor :par
      attr_accessor :cont
      attr_accessor :attrs
      def initialize(tag_name, par=nil, attrs={}, cont=[])
        @tag = nil
        @tag = tag_name.to_sym if tag_name
        @par = par
        cont = [ cont ] if cont.is_a? String
        @cont = cont || []
        @attrs = attrs || {}
      end

      def add(cont)
        @cont << cont
      end
    end
    class Tree

      def initialize
        @root = Node.new(nil)
        @cur = @root
      end

      def tag(tag, attrs = nil, cont = nil)
        if cont.nil? && ! attrs.is_a?(Hash)
          # tag(:b, "ahoj") -> tag(:b, {}, "ahoj")
          cont = attrs
          attrs = nil
        end
        cont = [ cont ] if cont.is_a? String
        @cur.add(Node.new(tag, @cur, attrs, cont))
        self
      end

      def tag_beg(tag_name, attrs = nil, cont = nil)
        node = Node.new(tag_name, @cur, attrs, cont)
        @cur.add(node)
        @cur = node
        self
      end

      def tag_end(tag_name)
        c = @cur
        ts = tag_name.to_sym
        while c.tag != ts
          c = c.par
          if c.nil?
            return "no such tag in stack, ingoring "
          end
        end
        @cur = c.par
        self

#        if @cur.tag == tag_name.to_sym
#          @cur = @cur.par
#        else
#          #pp(@root)
#          raise "tag_end: cur tag is not <#{tag_name}>, but <#{@cur.tag}>"
#        end
#        self
      end

      # add space if needed
      def add_spc
        if @cur.cont.size > 0
          last = @cur.cont.last
          if last.is_a?(String) && last[-1] == ?\s
            return
          end
        end
        add(' ')
      end

      def add(cont)
        @cur.add(cont)
        self
      end

      def add_raw(cont)
        #cont_san = Sanitize.clean(cont, san_conf)
        @cur.add(RawHtml.new(cont))
        self
      end


     def find_par(tag_name, node = nil)
       node = @cur if node.nil?
       while ! node.par.nil?
         if node.tag == tag_name
            return node.par
         end
         node = node.par
       end
       nil
     end

     def to_html
       ret = tree_to_html(@root)
       ret
     end
     def tree_to_html(node)
        tag = node.tag
        if tag.nil?
          return cont_to_s(node.cont)
        end

        nl = ''
        nl = "\n"  if TAGS_APPEND_NL.include? tag

        if ! TAGS_ALLOVED.include? tag
          return '' if node.cont.size == 0
          return cont_to_s(node.cont)
        end
        if node.cont.size == 0
          if TAGS_SKIP_EMPTY.include? tag
             return ''
          end
          if TAGS_FORCE_PAIR.include? tag
            return "<#{tag}#{attrs_to_s(tag, node.attrs)}></#{tag}>#{nl}"
          end
          return "<#{tag}#{attrs_to_s(tag, node.attrs)}/>#{nl}"
        end

        return "<#{tag}#{attrs_to_s(tag, node.attrs)}>#{cont_to_s(node.cont)}</#{tag}>#{nl}"
     end


     TAGS_APPEND_NL = [:div, :p, :li, :ol, :ul, :dl, :table, :tr, :td , :th]
     TAGS_FORCE_PAIR = [:a, :td, :h1, :h2, :h3, :h4, :h5, :h6, :div, :script]
     TAGS_ALLOVED = [:a,
                     :h1, :h2, :h3, :h4, :h5, :h6,
                     :div, :span, :p, :pre,
                     :li, :ul, :ol, :dl, :dt, :dd,
                     :b, :tt, :u, :del, :blockquote, :strong, :em, :sup, :sub, :i,
                     :table,  :tr, :td, :th,
                     :br , :img, :hr,
                     :form, :textarea, :input, :select, :option,
     ]
     TAGS_SKIP_EMPTY = [ :p , :ol, :li, :strong, :em  ]
     ATTRIBUTES_ALLOWED = { :form  =>  [:action, :meth],
                            :input =>  [:size, :type, :value, :name],
                            :select => [:multiple, :name],
                            :option => [:disabled, :selected, :label, :value, :name],
                            :a     =>  [:name, :href],
                            :img   =>  [:src, :width, :height, :align, :valign, :style, :alt, :title],
                            :td    =>  [:colspan, :rowspan, :style],
                            :th    =>  [:colspan, :rowspan, :style],
                            :_all  =>  [:class, :title, :id],
                           }

     ATTRIBUTE_STYLE_REX = /\A( text-align:(center|right|left) |
                                margin:    \d+(px|em)? |
                                ;
                             )+\Z/x
     def attrs_to_s(tag, attrs)
       return '' if attrs.nil? || attrs.size == 0
       ret = ['']
       tag_attrs = ATTRIBUTES_ALLOWED[tag] || []
       attrs.each_pair do |k,v|
         next if v.nil?
         k_sym = k.to_sym
         next if ! ( ATTRIBUTES_ALLOWED[:_all].include?(k_sym) || tag_attrs.include?(k_sym) )
         next if k == :style && v !~ ATTRIBUTE_STYLE_REX
         #print "style: #{v}\n" if k == :style
         ret.push "#{TracWiki::Parser.escapeHTML(k.to_s)}=\"#{TracWiki::Parser.escapeHTML(v.to_s)}\""
       end
       return ret.sort.join(' ')
     end

     def cont_to_s(cont)
       cont = [cont] if cont.is_a? String
       cont.map do |c|
          if c.is_a? Node
             tree_to_html(c)
          elsif c.is_a? RawHtml
             c.to_s
          else
             TracWiki::Parser.escapeHTML(c.to_s)
          end
        end.join('')
      end

#     def san_conf
#        return @san_conf if @san_conf
#        conf = { elements:   ['tt', 'form', 'input', 'span', 'div'],
#                 output: :xhtml,
#                 attributes: { 'form'  =>  ['action', 'meth'],
#                               'input' =>  ['type', 'value'],
#                               'span'  =>  ['class', 'id'],
#                               'div'   =>  ['class', 'id'],
#                               'a'     =>  ['class', 'id', 'name', 'href'],
#                               :all    =>  ['class', 'id'],
#                             },
#               }
#                   
#        @san_conf = Sanitize::Config::RELAXED.merge(conf){|k,o,n| o.is_a?(Hash) ? o.merge(n) :
#                                                                  o.is_a?(Array) ? o + n :
#                                                                  n }
#
#        #pp @san_conf
#        @san_conf
#     end
    end
end
