local io = require_shared("io")
local cbor = require_shared("cbor")
local network = require_shared("network")
local json = require_shared("json")

local tokens = cbor.decode(io.ReadFile(argv[1] or "gb.tokens"))

local delete = {}

local already = {}
for i,v in tokens do
    local headers, data = network.RequestGet(
        'https://giftsbattle.com/api/v1/user',
        {
            'Accept: */*',
            'Content-Type: application/json',
            `Authorization: Bearer {v}`,
            'Origin: https://giftsbattle.app',
            'Referer: https://giftsbattle.app/',
            'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/60.5 Safari/605.1.15',
            'Accept-Language: en-US',
            'Sec-Fetch-Dest: empty',
            'Sec-Fetch-Mode: cors',
            'Sec-Fetch-Site: cross-site',
        }
    )
    local new_data = json.decode(data)
    local status = string.split(headers, "\r\n")[1]:split(" ")[2]
    if status ~= "200" then
        print(status, i, v, data)
        table.insert(delete, v)
    else
        if already[new_data.telegram_id] then
            print("\n[REPEAT]", v)
            table.insert(delete, already[new_data.telegram_id])
        end
        print(status, i, new_data.user.first_name)
        already[new_data.telegram_id] = v
        if new_data.user.first_name == "faderiko"
        or new_data.user.first_name == "farenoak" then
            print(v)
        end
    end
    
end

for i,v in delete do
    local i = table.find(tokens, v)
    print(`Deleting [{v}]...`)
    table.remove(tokens, i)
end

io.WriteFile(argv[2] or argv[1] or "gb.tokens", cbor.encode(tokens))