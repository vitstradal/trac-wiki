module TracWiki

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
      #print "prepare_y\n"
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

end
