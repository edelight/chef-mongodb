# helper to cast any object to a boolean
def Boolean(obj) # rubocop:disable MethodName
  obj ? true : false
end
