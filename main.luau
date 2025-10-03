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
    return update.message.chat.id ~= -1002738827583 and update.message.chat.id ~= 829586530
end

print("Loading data...")

local active_accounts = {}
local dead_accounts = {}
local tokens_count = 0
for i,v in tokens do
    tokens_count += #v
end

print("Tokens count:", tokens_count)

local skip = table.find(argv, "--skip") or table.find(argv, "-s")

print("Fetching activity...")
local S = "_|1623|_"

function check_stats()
for owner,v in tokens do
    for i,v in v do
        task.truethread(function()
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
            local ok, new_data = pcall(json.decode, data)
            local status = string.split(headers, "\r\n")[1]:split(" ")[2]

            local accounts_fd = io.fopen(`.accounts`)
            local count_fd = io.fopen(".count")
            local accounts = io.fread(accounts_fd) or ""

            accounts = accounts..`{status}{S}{owner}{S}{v}{S}{if ok then (if new_data.telegram_username then "@"..new_data.telegram_username else new_data.user.first_name) else ""}{S}{if ok then new_data.balance else ""}\n`

            io.fwrite(accounts_fd, accounts)
            io.fwrite(count_fd, tostring((tonumber(io.fread(count_fd) or "0") or 0) + 1))
            io.fclose(accounts_fd)
            io.fclose(count_fd)
        end)
    end
end
while(task.__sleep(0.1) or true) do
        local count_fd = io.fopen(".count")
        local count = tonumber(io.fread(count_fd) or "0") or 0
        io.fclose(count_fd)
        if count < tokens_count then
            continue
        end
        break
    end
    local data = io.ReadFile(".accounts")
    io.DeleteFile(".count")
    io.DeleteFile(".accounts")
    return data
end

print("Proccessing data...")
local accounts = check_stats()
for i,v in string.split(accounts, "\n") do
    if v == "" then continue end
    local data = string.split(v, S)
    if data[1] == "200" then
        table.insert(active_accounts, {
            owner = data[2],
            token = data[3],
            username = data[4]
        })
    else
        table.insert(dead_accounts, {
            owner = data[2],
            token = data[3]
        })
    end
end

print(`Active accounts: {#active_accounts}`)
print(`Dead accounts: {#dead_accounts}`)
print("Done✅")

local start_time = os.time()
local commands = {}

local promo_count = 0
local stars_count = 0

commands[".stats"] = function(update)
    if check(update) then return end
    local tokens_count = 0
    for i,v in tokens do
        tokens_count += #v
    end
    tgbot.SendMessage(update.message.chat.id, `Количество токенов: {tokens_count}✅\n`..
                                              `Рабочих аккаунтов: {#active_accounts}✅\n`..
                                              `Мертвых аккаунтов: {#dead_accounts}❌\n`..
                                              `Время работы бота: {("%.1f"):format((os.time() - start_time)/60)} минут\n`..
                                              `Активнуто промиков за сеанс: {promo_count}🤑\n`..
                                              `Получено звезд: {stars_count}⭐️`)
end

commands[".get_stars"] = function(update)
    task.truethread(function()
    if check(update) then return end
   
    local text = "Список аккаунтов\n\n"

    local balance = {}
    local data = check_stats()
    for i,v in data:split("\n") do
        local args = string.split(v, S)

        if args[1] == "200" then
            table.insert(balance, {name = args[4],
                                   owner = args[2],
                                   balance = tonumber(args[5])})
        end
    end
    table.sort(balance, function(l,r) return l.balance > r.balance end)
    for i,v in balance do
        text = text .. ("%-10s%s %d⭐️\n"):format(v.owner, v.name, v.balance)
    end
    tgbot.SendMessage(update.message.chat.id, text)
    end)
end

tgbot.SetTextHandler(function(update)
    task.truethread(function()
    if check(update) then return end
    if not update.message or not update.message.text then return end

    if string.byte(update.message.text) == 46 then
        (commands[update.message.text] or function()
            tgbot.SendMessage(update.message.chat.id, "Неизвесная комманда", nil, update.message.message_id)
        end)(update)
        return
    end

    local message = tgbot.SendMessage(update.message.chat.id, "Начинаем активировать промо...", nil, update.message.message_id)
    local activated = 0
    for i,v in active_accounts do
        task.truethread(function()
        local headers, data = network.RequestPost(
            'https://giftsbattle.com/api/v1/promo/activate/',
            {
                'Accept: */*',
                'Content-Type: application/json',
                `Authorization: Bearer {v.token}`,
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

        local checkout = io.fopen(`.checkout-{update.update_id}`)
        if status == "200" then
            local fd = io.fopen(`.stars-{update.update_id}`)
            local fd1 = io.fopen(`.activations-{update.update_id}`)
            local file = io.fread(fd)
            if not file then
                local data = json.decode(data)
                io.fwrite(fd, data.sum or 0)
                tgbot.SendMessage(update.message.chat.id, `[{i}] ХАПАЕМ ПО {data.sum or 0}⭐️`, nil, message.message_id)
            end
            local file = io.fread(fd1)
            io.fwrite(fd1, (tonumber(file) or 0) + 1)
            io.fclose(fd)
            io.fclose(fd1)
        else
            --print(task.__time(), status, v.token, data)
        end
        
        io.fwrite(checkout, tostring((tonumber(io.fread(checkout) or "0") or 0) + 1))
        io.fclose(checkout)
        end)
    end

    local limit = 0

    while limit < 0.1*10*60 do
        task.__sleep(0.1)
        limit += 1
        local count_fd = io.fopen(`.checkout-{update.update_id}`)
        local count = tonumber(io.fread(count_fd) or "0") or 0
        io.fclose(count_fd)
        if count < #active_accounts then
            continue
        end
        break
    end
    local activated = tonumber(io.ReadFile(`.activations-{update.update_id}`) or "0")
    local stars = tonumber(io.ReadFile(`.stars-{update.update_id}`) or "0")
    promo_count += activated
    stars_count += stars*activated
    tgbot.SendMessage(update.message.chat.id, `Схавано {activated} промиков по {stars}⭐️`, nil, message.message_id)
    io.DeleteFile(`.activations-{update.update_id}`)
    io.DeleteFile(`.stars-{update.update_id}`)
    io.DeleteFile(`.checkout-{update.update_id}`)
    end)
end)

tgbot.StartLoop()