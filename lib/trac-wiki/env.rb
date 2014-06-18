# encoding: utf-8
module TracWiki

  class Env
    attr_accessor :env
    def initialize(parser, env = {})
      @parser = parser
      @env = env || {}
      @argv = {}
      @argv_stack = []
    end

    # r: expanded-macro, rest-of-str, lines, offset-in-line
    def parse_macro_all(macro_name, str, macro_name_size = nil)
      str_size = str.size
      args, rest, lines, offset = parse_balanced(str)
      atput('maclen', str_size - rest.size + macro_name_size) if ! macro_name_size.nil?


      if macro_name =~ /\A!/
         # {{!cmd}}
         mac_out = parse_macro_cmd(macro_name, args)
      else
         # {{$cmd}},  {{template}}, ...
         if @argv_stack.size == 0
           prefix_size  = lines == 0  ? macro_name.size + 2 + at('offset',0).to_i : 0
           @env['maclines'] = lines
           @env['eoffset'] = offset + prefix_size 
           @env['elineno'] = at('lineno', 0).to_i + lines
         end 
         mac_out = parse_macro_vartempl(macro_name, args)
      end
      return mac_out || '', rest, lines, offset
    end

    # read to args to }}  (while balancing {{ and }})
    # ret: (arg, rest, lines)
    # mac_out  -- string to }} (macros inside expanded)
    # rest -- str aftrer }}
    # lines -- howmany \n eaten from str (from begining to }})
    def parse_macro_vartempl(macro_name, args)
      args.map! { |arg| expand(arg) }
      return do_macro_var($1, args) if macro_name =~ /^\$(.*)/
      return do_macro_templ(macro_name, args)
    end

    # parse to next }} (with balanced {{..}})
    # like parse_macro_vartempl but not expand content
    # r: [expansion, rest_of_str, count_of_consumed_lines]
    def parse_macro_cmd(macro_name, args)
       return do_macro_cmd(macro_name, args)
    end

    # r: [args], rest-of-str, num-of-lines, offset-last-line
    def parse_balanced(str)
      str.sub!(/\A(\s*[\r\n])*([ \t]*[\|:]?)/, '')
      emptylines,  empty  = $1||'', $2||''
      lines = emptylines.count("\n")
      offset = empty.size
      return [], $', 0, offset+2 if str =~ /\A}}/
      #print "_parse_macro_cmd: #{macro_name}, str#{str}\n"
      dep = 0
      args = ['']
      while str =~ /{{|}}|\n|\|/
        prefix, match, str  = $`, $&, $'
        offset += prefix.size + match.size
        #raise "offset is nil" if offset.nil? 
        args[-1] += prefix
        if match == '{{'
          dep += 1
        elsif match == '}}'
          dep -= 1
          return args, str, lines, offset if dep < 0
        elsif match == "\n" 
          lines += 1
          offset = 0
        elsif match == '|' && dep == 0
          args.push('')
          next
        end
        args[-1]  += $&
      end
      raise "eol in parsing macro params"
    end

    # calls {{!cmd}} (if exists
    # r: result of  {{!cmd}}
    def do_macro_cmd(macro_name, args)
      return '|' if macro_name == '!'
      if @parser.macro_commands.key?(macro_name)
        @env[:cmd_args] =  args
        @env[:cmd_arg0] =  macro_name
        #print "mac: #{macro_name} env:" ; pp (@env)
        ret = @parser.macro_commands[macro_name].call(self)
        return ret
      end
      "UCMD(#{macro_name}|#{@env['arg']})"
    end
    def arg(idx)
      @env[:cmd_args][idx] || ''
    end

    def prepare_y
      #print "prepare_y\n"
      return if @env.key? 'y'
      arg = @argv['00']
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

      return @argv[key] if @argv.key? key

      prepare_y if key =~ /^y\./

      cur = @env
      key.split(/\./).each do |subkey|
        subkey = at($1, '') if subkey =~ /\A\$(.*)/
        #print "at:subkey: #{subkey}\n"
        if cur.is_a? Hash
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
      #rint "at(#{key})->#{cur}\n"
      to_str ? cur.to_s : cur
    end
    def atput(key, val = nil)
      #print "atput: #{key}, #{val} env:"
      #pp @env

      # local variable
      if @argv.key? key
         @argv[key] = val
         return
      end

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
    def do_macro_templ(macro_name, args)
      return "!{{toc}}" if macro_name == 'toc'
      return args.join('|').strip  if macro_name == '#echo'
      return '' if macro_name == '#'

      @argv_stack.push @argv

      @argv = do_macro_arg_to_env(args)
      ret = _do_macro_temp_low(macro_name)

      @argv = @argv_stack.pop
      return ret
    end

    def _do_macro_temp_low(macro_name)
      if ! @parser.template_handler.nil?
        str = @parser.template_handler.call(macro_name, @env)
        is_defined = !str.nil?
        @parser.used_templates[macro_name] = is_defined
        if is_defined
          if @argv_stack.size > 32
             return "TOO_DEEP_RECURSION(`#{str}`)\n"
             #return "TOO_DEEP_RECURSION"
          end
          # FIXME: melo by nahlasit jestli to chce expandovat | wiki expadnovat |raw html
          #print "temp(#{macro_name}) --> : #{str}\n"
          #print "bf ex: [#{str}]\n"
          str = expand(str)
          #print "af ex: [#{str}]\n"
          return str
        end
      end
      "UNKNOWN-MACRO(#{macro_name})"
    end

    def do_macro_arg_to_env(args)
      argv = {}
      argv['00'] = args.join('|')
      arg0 = []

      idx = 1
      args.each do |arg|
        if arg =~ /\A\s*(\w+)=\s*(.*)/m
          argv[$1] = $2
        else
          argv[idx.to_s] = arg
          arg0.push arg
          idx+=1
        end
      end
      argv['0'] = arg0.join('|')
      return argv
    end

    def do_macro_var(var_name, args)
      ret = at(var_name, nil)
      return ret if !ret.nil?
      return args.join('|')  if args.size > 0
      return ''
      "UVAR(#{var_name}|#{@env['arg']})"
    end

    # template expand
    def expand_arg(idx)
      expand(arg(idx))
    end

    def pp_env
      pp(@env)
    end
    def expand(str)
      ret = ''
      return '' if str.nil?
      while str =~ TracWiki::Parser::MACRO_BEG_INSIDE_REX
          prefix, macro_name2, str = $1, $2, $'
          ret << prefix
          # FIXME if macro_name2 =~ /^!/
          mac_out, str, lines, offset = parse_macro_all(macro_name2, str, nil)

          ret << mac_out
          #print "Too long macro expadion" if ret.size > 1_000_000
          raise TooLongException if ret.size > 1_000_000
      end
      #print "text: #{text.nil?}\n"
      #print "ret: #{ret.nil?}\n"
      ret += str
      return ret.gsub(/\\\r?\n\s*/, '')
    end
  end
end
