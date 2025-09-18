local io = require_shared("io")
local cbor = require_shared("cbor")

local target = io.ReadFile(argv[1])
      target = if target then cbor.decode(target) else {}


local source = io.ReadFile(argv[2])
      source = if source then cbor.decode(source) else {}

for i,v in source do
    if table.find(target, v) then continue end
    table.insert(target, v)
    print(`[{i}] Merged`)
end

io.WriteFile(argv[1], cbor.encode(target))