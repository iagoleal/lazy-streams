--[[
  MIT License

  Copyright (c) 2021 Iago Leal de Freitas

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
--]]

-- Setup the environment
local M = {__version = "0.1.0"}
setmetatable(M, {__index = _G})
if setfenv then
  setfenv(1, M) -- for 5.1 / luajit
else
  _ENV = M      -- for 5.2+
end

-- Constant function
function const(x)
  return function() return x end
end

-- Class for lazy streams
Stream = {}

-- Memoize any constructor
local function delay(proc)
  local already = false
  local result  = nil
  return function ()
    if proc == nil then
      return nil
    end
    if not already then
      result  = proc()
      already = true
    end
    return result
  end
end

-- Force execution of constructor
local function force(f)
  return f()
end

------------
-- Creation
------------

-- The empty stream
empty = nil

function isempty(s)
  return s == nil
end

function new(val, constructor)
  assert(type(constructor) == "function", "Function needed to build stream")
  constructor = constructor or const(nil)
  local t = { value = val
            , next  = delay(constructor)
            }
  setmetatable(t,
    { __type = "stream"
    , __tostring = function(s)
      if isempty(s) then
        return "empty"
      end
      return table.concat {'stream [', tostring(s.value), ', ...]'}
    end
    , __index = function(s, idx)
        return access(s, idx)
      end
    , __setindex = function(t, k, v)
      error("Streams are read-only --- Try creating a new one", 2)
    end
    , __len   = function(s)
        local op = function(x,y) return 1 + y end
        return fold(op, 0, s)
      end
    })
  return t
end



function isstream(s)
  local mt = getmetatable(s)
  return mt and mt.__type == "stream"
end

function cons(val, stream)
  return new(val, const(stream))
end
-- Accessor functions
function head(s)
  return rawget(s, 'value')
end

function tail(s)
  return force(s.next)
end

-- Access stream at given index.
-- Note: stream (like lua tables) are 1-indexed.
function access(s, idx)
  assert(type(idx) == "number" and idx >= 1, "Stream indices start from 1")
  if isempty(s) then
    error("Tried to access index " .. tostring(idx) .. " of empty stream")
  end
  if idx == 1 then
    return head(s)
  else
    return access(tail(s), idx-1)
  end
end

-- Dismember a stream into head and tail.
-- Note: This function forces the tail execution
function uncons(s)
  return head(s), tail(s)
end

--------------------------
-- Higher Order Functions
--------------------------

-- Apply function f to all elements of a stream.
-- If f is n-ary, you can enter n streams and it will be applied to all of them.
function map(f, ...)
  local streams = table.pack(...)
  local hs = {}
  if streams.n ==  0 then return empty end
  for i = 1, streams.n do
    if isempty(streams[i]) then
      return empty
    end
    hs[i] = head(streams[i])
  end
  return new(f(table.unpack(hs)), function()
      local ts = {}
      for i = 1, streams.n do
        if isempty(streams[i]) then
          return empty
        end
        ts[i] = tail(streams[i])
      end
      return map(f, table.unpack(ts))
  end)
end

function filter(p, s)
  if isempty(s) then
    return empty
  else
    local h = head(s)
    if p(h) then
      return new(h, function()
        return filter(p, tail(h))
      end)
    else
      return filter(p, tail(h))
    end
  end
end

function fold(op, base, s)
  if isempty(s) then
    return base
  else
    return op(head(s), fold(op, base, tail(s)))
  end
end

-------------------
-- Slicing streams
-------------------

-- Truncate the first n elements of a stream
function take(n, s)
  if isempty(s) then return empty end
  if n == nil then
    return s
  end
  if n <= 0 then
    return empty
  else
    return new(head(s), function()
      return take(n-1, tail(s))
    end)
  end
end

-- Drop the first n elements of a stream
function drop(n, s)
  if isempty(s) then return empty end
  if n == nil then
    return s
  end
  if n <= 0 then
    return s
  else
    return drop(n-1, tail(s))
  end
end

-- Collect a stream into a table.
-- Optional argument may be used to collect only the first n elements
function collect(s, n)
  if n ~= nil then
    return collect(take(n, s))
  end
  local values = {}
  local i = 1
  while not (isempty(s)) do
    values[i] = head(s)
    s = tail(s)
    i = i + 1
  end
  return values
end

----------------
-- Construction
----------------

-- A stream of number from i to j.
-- Default step is 1.
function range(i, j, step)
  if type(j) == "number" and i > j then
    return empty
  end
  step = step or 1
  return new(i, function()
    return range(i + step, j, step)
  end)
end

-- Return a stream repeating the same value
function replicate(x)
  return new(x, function()
    return replicate(x)
  end)
end

pp = function(t)
  if isstream(t) then
    return pp(collect(t))
  end
  io.write('[')
  for _, v in ipairs(t) do
    io.write(tostring(v), ", ")

-----------------------
-- Set methods
-----------------------

do
  local mt   = methods
  mt.head    = head
  mt.tail    = tail
  mt.uncons  = uncons
  mt.map     = function(self, f)
    return map(f, self)
  end
  io.write(']\n')
  mt.filter  = flip(filter)
  mt.fold    = function(self, op, base)
    return fold(op, base, self)
  end
  mt.take    = flip(take)
  mt.drop    = flip(drop)
  mt.collect = collect
end

return M
