# Available opcodes for our VM
PUSH_OP = /PUSH (\d+)/ # pushes a number (its argument) on to the stack.
PRINT_OP = /PRINT/ # pops the top number off of the stack and prints it
ADD_OP = /ADD/ # pops the top two elements off the stack, adds them, and puts the result back on to the stack
SUB_OP = /SUB/ # pops the top two elements off the stack, subtracts them, and ...
MUL_OP = /MUL/ # pops the top two elements off the stack, multiplies them, and ...
JMP_OP = /JMP (\w+)/ # unconditional jump 
JZ_OP = /JZ (\w+)/ # pop jump if zero
JNZ_OP = /JNZ (\w+)/ # pop jump if nonzero
STOR_OP = /STOR (\d+)/ 
LOAD_OP = /LOAD (\d+)/
LABEL_OP = /^(\w+):$/ 

class VirtualMachine
  def initialize
    @stack = [] # stack for computations
    @registers = {} # hash to simulate registers
    @instructions = [] # stores bytecode instructions
    @labels = {} # stores label positions
    @pc = 0 # program counter
  end

  def exec(bytecode_file)
    # Read and preprocess instructions, mapping labels
    File.open(bytecode_file, 'r') do |file|
      file.each_with_index do |line, index|
        line.strip!
        if line.match?(LABEL_OP)
          label = line.sub(LABEL_OP, '\1')
          @labels[label] = index # Save the label's position
        else
          @instructions << line
        end
      end
    end

    # Execute the instructions
    while @pc < @instructions.size
      ln = @instructions[@pc]
      @pc += 1 # Increment program counter unless modified by a jump
      case ln
      when PUSH_OP
        @stack.push(ln.sub(PUSH_OP, '\1').to_i)
      when PRINT_OP
        v = @stack.pop
        puts v
      when ADD_OP
        a = @stack.pop
        b = @stack.pop
        @stack.push(a + b)
      when SUB_OP
        a = @stack.pop
        b = @stack.pop
        @stack.push(b - a)
      when MUL_OP
        a = @stack.pop
        b = @stack.pop
        @stack.push(a * b)
      when JMP_OP
        label = ln.sub(JMP_OP, '\1')
        raise "Undefined label '#{label}'" unless @labels[label]
        @pc = @labels[label] # Jump to the label
      when JZ_OP
        label = ln.sub(JZ_OP, '\1')
        raise "Undefined label '#{label}'" unless @labels[label]
        v = @stack.pop
        @pc = @labels[label] if v == 0 # Jump if the value is zero
      when JNZ_OP
        label = ln.sub(JNZ_OP, '\1')
        raise "Undefined label '#{label}'" unless @labels[label]
        v = @stack.pop
        @pc = @labels[label] if v != 0 # Jump if the value is nonzero
      when STOR_OP
        reg = ln.sub(STOR_OP, '\1').to_i
        @registers[reg] = @stack.pop # Store top stack value in register
      when LOAD_OP
        reg = ln.sub(LOAD_OP, '\1').to_i
        @stack.push(@registers[reg]) # Push register value to stack
      else
        raise "Unrecognized command: '#{ln}'"
      end
    end
  end
end

# Entry point
if ARGV.length < 1
  puts "Usage: ruby vm.rb <bytecode file>"
  exit 1
end

source = ARGV[0]
vm = VirtualMachine.new
vm.exec(source)
