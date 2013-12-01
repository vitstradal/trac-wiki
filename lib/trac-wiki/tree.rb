require 'pp'
module TracWiki
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
        if @cur.tag == tag_name.to_sym
          @cur = @cur.par
        else
          raise "tag_end: cur tag is not <#{tag_name}>, but <#{@cur.tag}>"
        end
        self
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
       tree_to_html(@root)
     end

     def tree_to_html(node)
        tag = node.tag
        if tag.nil?
          return cont_to_s(node.cont)
        end

        nl = ""
        #nl = "\n"  if [:div, :h1, :h2, :h3, :h4, :h5, :p].include? tag
        nl = "\n"  if [:div, :p].include? tag

        if node.cont.size == 0
          if [:a, :td, :h1, :h2, :h3, :h4, :h5, :h6,:strong, :script].include? tag
            return "<#{tag}#{attrs_to_s(node.attrs)}></#{tag}>"
          end
          return "<#{tag}#{attrs_to_s(node.attrs)}/>#{nl}"
        end

        return "<#{tag}#{attrs_to_s(node.attrs)}>#{cont_to_s(node.cont)}</#{tag}>#{nl}"
     end

     def cont_to_s(cont)
       if cont.is_a? String
         return cont.to_s
       end
       cont.map do |c|
          if c.is_a? Node
             tree_to_html(c)
          else
             TracWiki::Parser.escapeHTML(c.to_s)
          end
        end.join('')
      end

     def attrs_to_s(attrs)
       return '' if attrs.nil? || attrs.size == 0
       ret = ['']
       attrs.each_pair do |k,v|
         ret.push "#{TracWiki::Parser.escapeHTML(k.to_s)}=\"#{TracWiki::Parser.escapeHTML(v.to_s)}\"" if !v.nil?
       end
       return ret.sort.join(' ')
     end
    end
end
