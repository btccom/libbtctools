oo = require 'loop.cached'
oo.Exception = require 'loop.object.Exception'

-- The base class of exceptions
Exception = oo.class({
  _NAME = 'Exception',
  __EXCEPTION_CLASS = true,
}, oo.Exception)
Exception.toString = Exception.__tostring

function Exception:__init(err, name)
  if type(err) ~= 'table' then
    err = { message = err }
  end
  if name then
    err._NAME = name
  end
  if err.traceback == nil then
    err.traceback = debug.traceback('-------------', 2)
  end
  return oo.rawnew(self, err)
end

-- Language structure: throw, try, catch, finally
throw = error

try = oo.class()

function try:__init(func)
  local traceback = function(err)
    if type(err) == 'table' and err.__EXCEPTION_CLASS then
      return err
    end
    return Exception(err)
  end
  return oo.rawnew(self, {
    result = { xpcall(func, traceback) },
    catched = false,
  })
end

function try:catch(exceptions, func)
  if type(exceptions) == 'function' then
    func = exceptions
    exceptions = nil
  end
  if self.result[1] or self.catched then
    return self
  end
  if exceptions == nil then
    func(self.result[2])
    self.catched = true
    return self
  end
  if type(exceptions) ~= 'table' then
    return self
  end
  if oo.isclass(exceptions) and oo.instanceof(self.result[2], exceptions) then
    func(self.result[2])
    self.catched = true
    return self
  end
  for i=1, #exceptions do
    if oo.isclass(exceptions[i]) and oo.instanceof(self.result[2], exceptions[i]) then
      func(self.result[2])
      self.catched = true
      return self
    end
  end
  return self
end

function try:finally(func)
  func(unpack(self.result))
end
