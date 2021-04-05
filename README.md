# Lazy Streams in Lua

A Lua library to manipulate lazy linked lists.
Highly based on Haskell's list type.


## Usage Examples

To calculate all Fibonacci number, you can do:

```lua
s = require("lazy-streams")

local add = function(x,y)
  return x+y
end

-- Stream of all Fibonacci numbers
local fibs = s.cons(0, s.new(1, function()
  return s.map(add, fibs, fibs:tail())
  end))
```

To calculate all prime numbers,
you can do an infinite sieve of Eratosthenes:

```lua
s = require("lazy-streams")

-- Make a non-divisibility test
function notDivisible(p)
  return function(x)
    return math.fmod(x,p) ~= 0
  end
end

-- Sieve of Eratosthenes
function sieve(stream)
  local p = stream:head()
  return s.new(p, function()
    return era(stream:tail():filter(notDivisible(p)))
  end)
end

-- Stream of all prime numbers
local primes = sieve(s.range(2))
```
