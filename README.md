# R64
## Ruby Commodore 64 Assembler
Version 0.2.0

By Maxwell of Graffity

## Introduction

R64 is a Ruby-based assembler for the Commodore 64 that provides an object-oriented-like development experience for writing assembly code. **Important: While R64 uses classes and objects for code organization, the final output is still traditional 6502 assembly code - this is not object-oriented programming in the runtime sense.**

### Features and Benefits

- **Modular Code Organization**: Structure your assembly code using Ruby classes and methods
- **Automatic Subroutine Management**: Methods starting with `_` become assembly subroutines with automatic JSR/RTS handling
- **Shared Memory with Isolated Labels**: All classes share the same memory space while maintaining separate label namespaces
- **Inline vs Subroutine Control**: Choose between inline code generation or subroutine calls for performance optimization
- **Ruby's Power**: Leverage Ruby's syntax for loops, conditionals, and data manipulation during assembly generation
- **Hierarchical Architecture**: Build complex programs with parent-child class relationships

### Important Limitations and Differences

**Not True OOP**: The object-oriented structure exists only during code generation. The compiled output is standard 6502 assembly without any object-oriented runtime features.

**Modified Assembly Syntax**: Some traditional assembly mnemonics had to be changed due to Ruby keyword conflicts:
- `AND` → `ANA` (since `and` is a Ruby keyword)
- Other syntax differences from standard 6502 assembly

**Ruby-Style Syntax**: The assembly syntax is heavily influenced by Ruby conventions rather than traditional assembly syntax, which may require adjustment for experienced assembly programmers.

### Best Use Cases

R64 is ideal for:
- Complex C64 programs that benefit from modular organization
- Developers familiar with Ruby who want to write assembly
- Projects requiring sophisticated code generation and templating
- Large assembly projects that need better structure and maintainability

References:
 * http://www.oxyron.de/html/opcodes02.html
 * http://unusedino.de/ec64/technical/aay/c64/bmain.htm
 * http://sta.c64.org/cbm64mem.html


## Installation

Download the gem and install it:

```
gem install r64-0.2.0.gem
```

## Debugging

Download the debugger and install:

https://github.com/slajerek/RetroDebugger/releases

Make sure, the debugger is on PATH.

## Usage:

```
r64 compile # creates a prg in the output folder
r64 debug   # creates a prg in the output folder and opens the debugger
r64 version # shows the version
```

## Quick Start

1. **Create a project folder:**
   ```bash
   mkdir my-c64-project
   cd my-c64-project
   ```

2. **Create the app structure:**
   ```bash
   mkdir app
   ```

3. **Create the main class file:**
   Create `app/main.rb` with the following content:
   ```ruby

   class Main < R64::Base
     before do
       setup start: 0x1000, end: 0x3fff
     end
     
     def _main
       label :main_loop
         inc 0xd020
         jmp :main_loop
     end
   end
   ```

   This will save the memory from 0x1000 to 0x3fff into the output file and starts generating the code from 0x1000.

4. **Compile your project:**
   ```bash
   r64 compile
   ```

   This will create a `.prg` file in the output folder that can be run on a Commodore 64 or emulator.

## Underscored Methods and Inline Rendering

R64 uses a special convention for method naming and rendering that allows you to write modular assembly code.

### Underscored Methods

Methods that start with an underscore (`_`) are treated as assembly subroutines:

```ruby
class MyClass < R64::Base
  def _my_subroutine
    lda 0x01
    sta 0xd020
  end
  
  def _main
    my_subroutine  # This generates: JSR _my_subroutine
  end
end
```

When the code is compiled underscore methods are rendered as subroutines marked by a label and the `RTS` is added at the end of the method.

When you call `my_subroutine` (without underscore), R64 automatically generates a `JSR :_my_subroutine` instruction which will use the label created for the `_my_subroutine` method.

### Inline Rendering

You can force methods to be rendered inline instead of as subroutines in two ways:

#### Method 1: Using `:inline` parameter

```ruby
def _main
  my_subroutine :inline  # Code is inserted directly, no JSR/RTS
end
```

- subroutine is rendered inline and the `RTS` is omitted. 
- subroutine version is also rendered and can be used in other calls.

#### Method 2: Using `inline_methods` declaration

```ruby
class MyClass < R64::Base
  def inline_methods
    [:_my_subroutine, :_another_method]
  end
  
  def _my_subroutine
    lda 0x01
    sta 0xd020
  end
end
```

- subroutine is rendered inline and the `RTS` is omitted whenever it is called. 
- subroutine version is not rendered.

### When to Use Inline vs Subroutines

- **Subroutines (default)**: Use for code that's called multiple times to save memory
- **Inline**: Use for small code blocks called once, or when you need to avoid the JSR/RTS overhead

#### Example

```ruby
class Sprite < R64::Base
  def _move
    lda :xpos
    clc  
    adc :xspeed
    sta :xpos
    set_position  # This calls _set_position as JSR
  end
  
  def _set_position
    lda :xpos
    sta 0xd000 + @index * 2
  end
end
```

## Class Connections and Memory Management

R64 allows classes to be connected in a parent-child hierarchy where they share memory space but maintain separate label pools.

### Creating Connected Classes

Classes are connected by passing the parent instance to child constructors:

```ruby
class Main < R64::Base
  before do
    setup start: 0x2000, end: 0x3fff
    @_screen = Screen.new self  # Pass 'self' as parent
  end
end

class Screen < R64::Base
  before do
    @_multiplexer = Multiplexer.new self  # Screen becomes parent of Multiplexer
  end
end
```

#### Mandatory Requirements for Class Connections
- **Use `@_` prefix for instance variables that hold R64::Base objects** - This tells R64 to automatically render these child instances
- **Pass `self` as parent to maintain the connection chain** - This ensures shared memory and proper parent-child relationships

### Calling Methods Between Classes

Child instances can call parent methods and vice versa using the instance variables:

```ruby
class Main < R64::Base
  def _main
    @_screen.setup_irq  # Calls _setup_irq method on Screen instance
  end
end

class Screen < R64::Base
  def _setup_irq
    @_multiplexer.turn_on_sprites  # Calls _turn_on_sprites on Multiplexer
  end
end
```

### Shared Memory, Separate Labels

**Shared Memory:**
- All connected instances share the same memory space
- Memory addresses are consistent across all classes
- The parent's memory configuration applies to all children

**Separate Label Pools:**
- Each class instance maintains its own label namespace
- Labels like `:main_loop` in one class don't conflict with the same label in another
- Each instance gets a unique index (`@index`) for label disambiguation

### Instance Management

```ruby
class SpriteManager < R64::Base
  before do
    @_sprites = []
    8.times do |i|
      @_sprites.push Sprite.new self  # Create 8 sprite instances
    end
  end
  
  def _move_sprites
    @_sprites.each(&:move)  # Call move on each sprite instance (generates 8 JSR instructions)
  end
end
```
