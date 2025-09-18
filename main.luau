local network = require_shared("network")
local pprint = require_shared("pprint")
local json = require_shared("json")
local tgbot = require_shared("tgbot")
local io = require_shared("io")
local cbor = require_shared("cbor")
local task = require_shared("task")

tgbot.SetToken(io.ReadFile(".token"))

local tokens = io.ReadFile("gb.tokens")
tokens = if tokens then cbor.decode(tokens) else {}

local function check(update)
    return update.message.chat.id ~= -4693646044
end

local function start(update)
    if check(update) then return end
    tgbot.SendMessage(update.message.chat.id, "Send promo")
end
tgbot.AddCommand("start", start)

local function add_token(update)
    if check(update) then return end

    local args = string.split(update.message.text, " ")
    if #args < 3 then
        tgbot.SendMessage(update.message.chat.id, "Токен не был введен")
        return
    end

    if table.find(tokens, args[3]) then
        tgbot.SendMessage(update.message.chat.id, "Токен уже в системе")
        return
    end
    table.insert(tokens, args[3])
    io.WriteFile("gb.tokens", cbor.encode(tokens))
    tgbot.SendMessage(update.message.chat.id, "Токен успешно добавленный")
end
tgbot.AddCommand("add_token", add_token)

local function remove_token(update)
    if check(update) then return end
    
    local args = string.split(update.message.text, "/remove_token ")
    if #args < 2 then
        tgbot.SendMessage(update.message.chat.id, "Токен не был введен")
        return
    end

    local id = table.find(tokens, args[2])
    if id == nil then
        tgbot.SendMessage(update.message.chat.id, "Токен не найден")
        return
    end

    table.remove(tokens, id)

    io.WriteFile("gb.tokens", cbor.encode(tokens))
    tgbot.SendMessage(update.message.chat.id, "Токен успешно удален")
end
tgbot.AddCommand("remove_token", remove_token)

tgbot.AddCommand("stats", function(update)
    if check(update) then return end
    tgbot.SendMessage(update.message.chat.id, `Количество токенов: {#tokens}`)
end)

tgbot.SetTextHandler(function(update)
    task.truethread(function()
    if check(update) then return end
    local message = tgbot.SendMessage(update.message.chat.id, "Начинаем активировать промо...", nil, update.message.message_id)
    local activated = 0
    for i,v in tokens do
        task.truethread(function()
        local headers, data = network.RequestPost(
            'https://giftsbattle.com/api/v1/promo/activate/',
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
            },
            `\{"code_data":"{update.message.text}"\}`
        )
        local status = string.split(headers, "\r\n")[1]:split(" ")[2]
        
        if status == "200" then
            local fd = io.fopen(`.stars-{update.update_id}`)
            local file = io.fread(fd)
            if not file then
                local data = json.decode(data)
                io.fwrite(fd, data.sum or 0)
                tgbot.SendMessage(update.message.chat.id, `[{i}] ХАПАЕМ ПО {data.sum or 0}⭐️`, nil, message.message_id)
            end
            io.fclose(fd)
            --task.__sleep(0.05 * i)
            local fd = io.fopen(`.activations-{update.update_id}`)
            local file = io.fread(fd)
            io.fwrite(fd, (tonumber(file) or 0) + 1)
            io.fclose(fd)
        else
            print(task.__time(), status, v, data)
        end
        
        end)
    end
    task.__sleep(0.02 * #tokens)
    local activated = tonumber(io.ReadFile(`.activations-{update.update_id}`) or "0")
    local stars = tonumber(io.ReadFile(`.stars-{update.update_id}`) or "0")
    tgbot.SendMessage(update.message.chat.id, `Схавано {activated} промиков по {stars}⭐️`, nil, message.message_id)
    io.DeleteFile(`.activations-{update.update_id}`)
    io.DeleteFile(`.stars-{update.update_id}`)
    end)
end)

tgbot.AddCommand("get_stars", function(update)
    task.truethread(function()
    if check(update) then return end
    local args = string.split(update.message.text, " ")
    local number = tonumber(args[2])
    if not number then return end

    local text = "Список аккаунтов\n\n"

    local balance = {}
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
        data = json.decode(data)

        if data.balance and data.balance >= number then
            table.insert(balance, {name = if data.telegram_username then "@"..data.telegram_username else data.user.first_name,
                                   balance = data.balance})
        end
    end
    table.sort(balance, function(l,r) return l.balance > r.balance end)
    for i,v in balance do
        text = text .. `{v.name} {v.balance}⭐️\n`
    end
    tgbot.SendMessage(update.message.chat.id, text)
    end)
end)

tgbot.StartLoop()