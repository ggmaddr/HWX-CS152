NUM_PAT = /[1-9]\d*|0/

# Available opcodes for our VM
PRINT_OP = "PRINT"
PUSH_OP = "PUSH"
ADD_OP = "ADD"
SUB_OP = "SUB"
MUL_OP = "MUL"

class AST
  @@register_map = {} # Class variable for the register map
  @@current_register = 0 # Class variable for the next available register
  attr_accessor :op, :parent, :args
  def initialize(op, parent)
    @op = op
    @parent = parent
    @args = []
  end
  def add_arg(x)
    @args.push(x)
  end
  def to_s
    s = "(" + @op
    @args.each do |arg|
      s += " " + arg.to_s
    end
    s + ")"
  end
  # recursively evaluates the AST, used for the interpreter
  def evaluate
    case @op
    when 'println'
      v = @args[0]
      v = v.evaluate if v.is_a?(AST)
      puts v
    when '+'
      sum = 0
      @args.each do |x|
        x = x.evaluate if x.is_a?(AST)
        sum += x
      end
      return sum
    when '-'
      diff = @args[0]
      diff = diff.evaluate if diff.is_a?(AST)
      args_tail = @args.slice(1, args.length-1)
      args_tail.each do |x|
        x = x.evaluate if x.is_a?(AST)
        diff -= x
      end
      return diff
    when '*'
      prod = 1
      @args.each do |x|
        x = x.evaluate if x.is_a?(AST)
        prod *= x
      end
      return prod
    else
      raise "Unrecognized op '#{@op}'"
    end
  end
  # recursively compiles the AST to bytecode, used for the compiler
  def to_bytecode
    bytecode = []
    case @op
    when 'println'
      comp_arg(@args[0], bytecode) 
      bytecode.push(PRINT_OP)
    when '+'
      comp_arg(@args[0], bytecode)
      comp_arg(@args[1], bytecode)
      bytecode.push(ADD_OP)
      for i in 2..@args.length-1 do
        comp_arg(@args[i], bytecode)
        bytecode.push(ADD_OP)
      end
    when '-'
      comp_arg(@args[0], bytecode)
      comp_arg(@args[1], bytecode)
      bytecode.push(SUB_OP)
      for i in 2..@args.length-1 do
        comp_arg(@args[i], bytecode)
        bytecode.push(SUB_OP)
      end
    when '*'
      comp_arg(@args[0], bytecode)
      comp_arg(@args[1], bytecode)
      bytecode.push(MUL_OP)
      for i in 2..@args.length-1 do
        comp_arg(@args[i], bytecode)
        bytecode.push(MUL_OP)
      end
    when 'let'
      bindings = @args[0].instance_variable_get:@args
      bindings.each do |arg|
        var, value = arg
        comp_arg(value.to_i, bytecode) # Compile the value
        if @@register_map[var] == nil
          @@register_map[var] = @@current_register # Map variable to register
          @@current_register += 1
        end
        bytecode.push("STOR #{@@register_map[var]}") # Store value in the register
      end

      # puts "After binding", @@register_map
      body = @args[1..] # Extract body expressions

      # Generate bytecode for the body expressions
      body.each do |expr|
        bytecode.concat(expr.to_bytecode)
      end
    
    when 'if'
      comp_arg(@args[0], bytecode) # Condition
      label_else = generate_label('fls')
      label_true = generate_label('tru') # Add a label for the true branch
      label_end = generate_label('done')
    
      bytecode.push("JZ #{label_else}")
      bytecode.push("#{label_true}:") # Emit the true branch label
      bytecode.concat(@args[1].to_bytecode) # Then branch
      bytecode.push("JMP #{label_end}")
      bytecode.push("#{label_else}:")
      bytecode.concat(@args[2].to_bytecode) # Else branch
      bytecode.push("#{label_end}:")    
    when "" #Ignore "" op
    else
    
      raise "Unrecognized op '#{@op}'"
    end
    bytecode # Returning bytecode
  end
  def generate_label(prefix)
    #hashmap counter of fls, tru, done 
    @label_counters ||= {} # Initialize the hash to store separate counters
    @label_counters[prefix] ||= 0 # Initialize the counter for the specific prefix if it doesn't exist
    label = "#{prefix}#{@label_counters[prefix]}"
    @label_counters[prefix] += 1 # Increment the counter for the specific prefix
    label
  end  
  
  private # Unlike Java, this means that *all* of the following functions in AST are private.
  def comp_arg(v, bytecode)
    case v
    when Integer
      bytecode.push("#{PUSH_OP} #{v}")
    when '#t'
      bytecode.push("#{PUSH_OP} 1") # Represent `true` as 1
    when '#f'
      bytecode.push("#{PUSH_OP} 0") # Represent `false` as 0
    when String
      if @@register_map && @@register_map[v]
        bytecode.push("LOAD #{@@register_map[v]}") # Load the variable value from its register
      else
        raise "Undefined variable '#{v}'"
      end
    else
      bytecode.concat(v.to_bytecode) if v.is_a?(AST)
    end
  end
  
end

# Responsible for parsing the source code, either for the interpreter or the compiler
class Parser
  def parse(fileS)
    asts = []
    file = File.expand_path(fileS, Dir.pwd)

    File.open(file, "r") do |file|
      file.each_line do |ln|
        asts.push(parse_line(ln))
      end
    end
    asts # Returning the ASTs
  end
  private # Unlike Java, this means that *all* of the following functions in AST are private.
  # String -> tokens
  def tokenize_line(line)
    # Remove comments starting with `;`
    line = line.split(';')[0] || '' # Ignore everything after `;`
    
    # Add spaces around brackets for tokenization
    line = line.gsub(/\[/, ' [ ').gsub(/\]/, ' ] ')
    
    # Add spaces around parens to make tokenization trivial
    line = line.gsub(/\(/, ' ( ').gsub(/\)/, ' ) ')
    
    # Split into tokens
    line.split
  end
  

  # [token] -> [AST]
 # [token] -> [AST]
  def parse_line(line)
    tokens = tokenize_line(line)
    ast = nil
    i = 0
    while (i <= tokens.length)
      case tokens[i]
      when '('
        if tokens[i+1].start_with?("[")
          ast = AST.new("", ast)
        else 
          ast = AST.new(tokens[i+1], ast) # Assuming that we will only receive valid programs
          i += 1 # Skipping an extra token
        end
        
      when ')'
        if ast.parent then
          ast.parent.add_arg(ast)
          ast = ast.parent
        end
      when NUM_PAT
        if ast
            ast.add_arg(tokens[i].to_i)
        else
          raise "Top-level numbers are not permitted"
        end
      when '#f'
        ast.add_arg(tokens[i])
      when '#t'
        ast.add_arg(tokens[i])
      when '['
        ast.add_arg([tokens[i+1], tokens[i+2]])
        i+=3
      when /.+/ # If anything else matches (and is at least one char), raise an error
        if ast # If it’s a variable reference
          ast.add_arg(tokens[i]) # Treat it as an argument
        else
          raise "Unrecognized token: '#{tokens[i]}'"
        end
      end
      i += 1
    end
    ast # Returning the abstract syntax tree
  end

end

# The interpreter, which walks the AST and evaluates as it goes.
# (Not used in this assignment, but available for reference).
class Interpreter
  def initialize
    @parser = Parser.new
  end
  def execute(file)
    asts = @parser.parse(file)
    asts.each do |ast|
      ast.evaluate if ast
    end
  end
end

# Compiles the source code into bytecode format
class Compiler
  def initialize
    @parser = Parser.new
  end
  def compile(scheme_file, bytecode_fileS)
    asts = @parser.parse(scheme_file)
    bytecode_file = File.expand_path(bytecode_fileS, Dir.pwd)
    File.open(bytecode_file, 'w') do |out|
      asts.each do |ast|
        if ast then
          puts "Parsing #{ast}"
          bytecode = ast.to_bytecode
          out.puts bytecode
        end
      end
    end
  end
end


if ARGV.length < 2
  puts "Usage: ruby compiler.rb <scheme file> <bytecode file>"
  exit 1
end

source = ARGV[0]
output = ARGV[1]

comp = Compiler.new
comp.compile(source, output)


