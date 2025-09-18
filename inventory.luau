local io = require_shared("io")
local cbor = require_shared("cbor")
local network = require_shared("network")
local json = require_shared("json")

local tokens = cbor.decode(io.ReadFile("gb.tokens"))

for i,v in tokens do
    local headers, data = network.RequestGet(
        'https://giftsbattle.com/api/v1/user/items?limit=10&offset=0',
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
        print(status, v, data)
    else
        if new_data.count > 0 then
            print(status, i, new_data.count, new_data.results[1].price, new_data.results[1].name)
        end
    end
    
end
