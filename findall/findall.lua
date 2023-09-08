--[[
Copyright © 2013-2015, Giuliano Riccio
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
* Neither the name of findAll nor the
names of its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Giuliano Riccio BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]



addon.name    = 'findAll'
addon.author  = 'Zohno (ported and extended by farmboy0, ported to Ashita v4 by Shadyt)'
addon.version = '1.0'

-- require 'ffxi.enums'
-- require 'tableex'
ashitaConfig = AshitaCore:GetConfigurationManager();
require 'windower.strings'

ki = require('windower.key_items')
slips = require('windower.slips')

KEY_ITEM_STORAGE_NAME = 'Key Items'

sorted_container_names = {}

Containers = {
    ['Inventory'] = 0,
    ['Safe'] = 1,
    ['Storage'] = 2,
    ['Temporary'] = 3,
    ['Locker'] = 4,
    ['Satchel'] = 5,
    ['Sack'] = 6,
    ['Case'] = 7,
    ['Wardrobe'] = 8,
    ['Safe 2'] = 9,
    ['Wardrobe 2'] = 10,
    ['Wardrobe 3'] = 11,
    ['Wardrobe 4'] = 12,
    ['Wardrobe 5'] = 13,
    ['Wardrobe 6'] = 14,
    ['Wardrobe 7'] = 15,
    ['Wardrobe 8'] = 16
}

-- Containers = {
--     { id=0, name='Inventory' },
--     { id=1, name='Safe' },
--     { id=2, name='Storage' },
--     { id=3, name='Temporary' },
--     { id=4, name='Locker' },
--     { id=5, name='Satchel' },
--     { id=6, name='Sack' },
--     { id=7, name='Case' },
--     { id=8, name='Wardrobe' },
--     { id=9, name='Safe 2' },
--     { id=10, name='Wardrobe 2' },
--     { id=11, name='Wardrobe 3' },
--     { id=12, name='Wardrobe 4' },
--     { id=13, name='Wardrobe 5' },
--     { id=14, name='Wardrobe 6' },
--     { id=15, name='Wardrobe 7' },
--     { id=16, name='Wardrobe 8' }
-- };

for name, id in pairs(Containers) 
    do sorted_container_names[id + 1] = {id = id, name = name} 
end

-- global_storages[server str][character_name str][inventory_name str][item_id num] = count num
global_storages = {}
item_names = {}

function get_item_names_by_id(storage_name, id)
    if storage_name == KEY_ITEM_STORAGE_NAME then
        return { name = ki[id].en, long_name = '' }
    end

    if item_names[id] == nil then
        local item = AshitaCore:GetResourceManager():GetItemById(id)
        -- print(item.Name[1] .. ' ' .. "IN GET ITEM NAMES BY ID");
        if not item then
            item_names[id] = { name='Unknown item with ID ' .. id, long_name='Unknown item with ID ' .. id }
        else
            item_names[id] = { name=item.Name[1] or '', long_name=item.LogNameSingular[0] or '' }
        end
    end

    return item_names[id]
end


function log(method, message)
    print(message)
end


function warn(method, message)
    print('WARN(' .. method .. '): ' .. message)
end


function error(method, message)
    print('ERR(' .. method .. '): ' .. message)
end


function encase_key(key)
    if type(key) == 'number' then
        return '[' .. tostring(key) .. ']'
    elseif type(key) == 'string' then
        return '["' .. key .. '"]'
    end

    return tostring(key)
end


function make_table(tab, tab_offset)
    -- Won't work for circular references or keys containing double quotes
    local offset = string.rep(" ", tab_offset)
    local ret = "{\n"
    for id, v in pairs(tab) do
        ret = ret .. offset .. encase_key(id) .. ' = '
        if type(v) == 'table' then
            ret = ret .. make_table(v, tab_offset + 2) .. ',\n'
        else
            ret = ret .. tostring(v) .. ',\n'
        end
    end

    return ret .. offset .. '}'
end


function get_player_name()
    local player = GetPlayerEntity()
    if player ~= nil then
        return player.Name
    end
    return nil
end


-- function get_files_in_dir(path, filter)
--     dir = ashita.fs.get_dir(path, '.*');
       
--     return dir;
-- end

function get_files_in_dir(path, filter)
    local dir = ashita.fs.get_dir(path, '.*')

    -- Filter out .gitignore files
    local filtered_dir = {}
    for _, filename in ipairs(dir) do
        if not string.match(filename, "%.gitignore$") then
            table.insert(filtered_dir, filename)
        end
    end

    return filtered_dir
end

function get_storage_path()
    return addon.path.. '\\data';
end


function create_storage_dir()
    if not ashita.fs.dir_exists(get_storage_path()) then
        ashita.fs.create_dir(get_storage_path())
    end
end


function is_bit_set(slip_inv_entry, bit)
    local byte = slip_inv_entry.Extra[math.floor((bit - 1) / 8)]
    if byte < 0 then
        byte = byte + 256;
    end

    -- this computes the value of the bit for its byte as 2^0 to 2^7
    local bit_value = 2 ^ ((bit - 1) % 8)

    return byte % (2 * bit_value) >= bit_value
end


function update_slip_storage(storage, inv_entry, item)
    if slips.items[inv_entry.Id] ~= nil then
        local slip_name = item.Name[0]
        storage[slip_name] = {}

        for slip_index, slip_item_id in ipairs(slips.items[inv_entry.Id]) do
            if (is_bit_set(inv_entry, slip_index)) then
                storage[slip_name][slip_item_id] = 1
            end
        end
    end
end

function escapeBackslashes(input)
    return input:gsub("\\\\", "\\");
end

function update_keyitem_storage(storage)
    local ki_storage = {}
    for _, key_item in pairs(ki) do
        if (AshitaCore:GetMemoryManager():GetPlayer():HasKeyItem(key_item.id)) then
            ki_storage[key_item.id] = 1
        end
    end
    storage[KEY_ITEM_STORAGE_NAME] = ki_storage
end


function update_player_storages()
    local player_name = get_player_name()
    if player_name == nil then
        error('update_player_storages', 'Couldnt determine player name')
        return
    end

    local storages = {}

    -- TODO
    -- storages.gil = items.gil

    update_keyitem_storage(storages)

    for container_name, container_id in pairs(Containers) do
        local current_storage = {}

        for i = 0, AshitaCore:GetMemoryManager():GetInventory():GetContainerCountMax(container_id), 1 do
            local inv_entry = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(container_id, i);

            if (inv_entry.Id ~= 0 and inv_entry.Id ~= 65535) then
                local item = AshitaCore:GetResourceManager():GetItemById(inv_entry.Id);

                if item then
                    local quantity = 1;
                    if inv_entry.Count and item.StackSize > 1 then
                        quantity = inv_entry.Count;
                    end
                    current_storage[inv_entry.Id] = (current_storage[inv_entry.Id] or 0) + quantity
                end

                update_slip_storage(storages, inv_entry, item)
            end
        end

        storages[container_name] = current_storage
    end

    global_storages[player_name] = storages
end


function load_global_storages()
    local storagePath = get_storage_path();
    -- print(escapeBackslashes(storagePath));
    storagePath = escapeBackslashes(storagePath);
    -- print('Loading global storages from ' .. storagePath);
    local files = get_files_in_dir(storagePath, '*.lua');
    -- print(files.Count);
    -- print(files);
    if not files or #files == 0 then
        return
    end

    for _, f in pairs(files) do
        local char_name = string.sub(f, 1, -5)
        -- print(char_name)
        local success, result = pcall(dofile, storagePath .. '/' .. f)
        if success then
            global_storages[char_name] = result
        else
            warn('load_global_storages', string.format('Unable to retrieve item storage for %s.', char_name))
        end
    end
end


function save_player_storages()
    local player_name  = get_player_name()
    if player_name == nil then
        error('save_player_storages', 'Couldnt determine player name')
        return
    end

    local self_storage = io.open(get_storage_path() .. '/' .. player_name .. '.lua', 'w+')

    io.output(self_storage):write('return ' .. make_table(global_storages[player_name], 0) .. '\n')
    io.close(self_storage)
end


function update_player()
    update_player_storages()
    save_player_storages()
end

local function containsValue(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

function print_help()
    local help = {
        { '/findall',                  '- Forces a list update and prints this help.' },
        { '/findall',           '' },
        { '    [:<character1> [:...]]',             '- the names of the characters to use for the search.' },
        { '    [!<character1> [!...]]',             '- the names of the characters to exclude from the search.' },
        { '    [<query>]',                          '- the word you are looking for.' },
        { '    [-d|--duplicates]',                  '- list only items which are found in more than one container.' },
        { '    [-e<filename>|--export=<filename>]', '- exports the results to a csv file in the data folder.' },
        { '    [-s|--stackables]',                  '- list only items which can stack.' },
    }
    local examples = {
        { '/findall thaumas',              '- Search for "thaumas" on all your characters.' },
        { '/findall :alpha :beta thaumas', '- Search for "thaumas" on "alpha" and "beta" characters.' },
        { '/findall :omega',               '- Show all the items stored on "omega".' },
        { '/findall !alpha thaumas',       '- Search for "thaumas" on all your characters except "alpha".' },
    }

    print('\31\200[\31\05' .. _addon.name .. '\31\200]\30\01' .. ' Version ' .. _addon.version)
    for k, v in pairs(help) do
        print('\31\200[\31\05' .. _addon.name .. '\31\200]\30\01 ' .. '\30\68Syntax:\30\02 ' .. v[1] .. '\30\71 ' .. v[2]);
    end
    print('\31\200[\31\05' .. _addon.name .. '\31\200]\30\01' .. ' Examples')
    for k, v in pairs(examples) do
        print('\31\200[\31\05' .. _addon.name .. '\31\200]\30\02 ' .. v[1] .. '\30\71 ' .. v[2])
    end
end


local do_auto_update = false
local next_sequence = nil
function handle_incoming_packet(id, original)
    local seq = string.byte(original, 3) + (string.byte(original, 4) * 256)
    if (next_sequence and seq >= next_sequence) and do_auto_update then
        update_player()
        next_sequence = nil
    end

    if id == 0x00B then -- Last packet of an old zone
        do_auto_update = false
    elseif id == 0x00A then -- First packet of a new zone, redundant because someone could theoretically load findAll between the two
        do_auto_update = false
    elseif id == 0x01D and not do_auto_update then
        -- This packet indicates that the temporary item structure should be copied over to
        -- the real item structure, accessed with get_items(). Thus we wait one packet and
        -- then trigger an update.
        do_auto_update = true
        next_sequence = (seq+22)%0x10000 -- 128 packets is about 1 minute. 22 packets is about 10 seconds.
    elseif (id == 0x1E or id == 0x1F or id == 0x20) and do_auto_update then
        -- Inventory Finished packets aren't sent for trades and such, so this is more
        -- of a catch-all approach. There is a subtantial delay to avoid spam writing.
        -- The idea is that if you're getting a stream of incoming item packets (like you're gear swapping in an intense fight),
        -- then it will keep putting off triggering the update until you're not.
        next_sequence = (seq+22)%0x10000
    end
end


function determine_query_elements(searchparams)
    local char_include = {}
    local char_exclude = {}
    local search_terms = {}
    local export = nil
    local duplicates = false
    local stackables = false

    for _, query_element in pairs(searchparams) do
        -- character specifiers must start with a '!' or a ':'
        local char_search = string.match(query_element, '^([:!]%a+)$')
        if char_search then
            local char_name = string.gsub(string.lower(string.sub(char_search, 2)), "^%l", string.upper)
            if string.sub(char_search, 1, 1) == '!' then
                table.insert(char_exclude, char_name)
            else
                table.insert(char_include, char_name)
            end
        elseif string.match(query_element, '^--export=(.+)$') or string.match(query_element, '^-e(.+)$') then
            export = string.match(query_element, '^--export=(.+)$') or
                     string.match(query_element, '^-e(.+)$')

            if export then
                export = string.gsub(export, '%.csv$', '') .. '.csv'
    
                if string.match(export, '[' .. string.escape('\\/:*?"<>|') .. ']') then
                    export = nil
    
                    error('determine_query_elements', 'The filename cannot contain any of the following characters: \\ / : * ? " < > |')
                end
            end
        elseif string.match(query_element, '^--duplicates$') or string.match(query_element, '^-d$') then
            duplicates = true
        elseif string.match(query_element, '^--stackables') or string.match(query_element, '^-s$') then
            stackables = true
        else
            table.insert(search_terms, query_element)
        end
    end

    return char_include, char_exclude, table.concat(search_terms,' '), export, duplicates, stackables
end


function build_search_pattern(terms)
    local terms_pattern = ''

    if terms ~= '' then
        terms_pattern = string.gsub(string.escape(terms), '%a',
            function(char) return string.format("[%s%s]", string.lower(char), string.upper(char)) end)
    end

    return terms_pattern
end


function search(char_include, char_exclude, terms)
    local results       = {};
    local currentPlayer = get_player_name();
    log('search', 'Searching: ' .. terms);

    local terms_pattern = build_search_pattern(terms)

    for char_name, char_storage in pairs(global_storages) do
        -- print(char_name .. ' ' .. char_include[1]);
        if (#char_include == 0 or containsValue(char_include, char_name)) and
        not containsValue(char_exclude, char_name) then
            for storage_name, storage_content in pairs(char_storage) do
                for item_id, quantity in pairs(storage_content) do
                    -- print(item_id);
                    -- print(storage_name .. item_id);
                    local names = get_item_names_by_id(storage_name, item_id)

                    if terms_pattern == ''
                        or string.find(names.name, terms_pattern)
                        or string.find(names.long_name, terms_pattern)
                    then
                        results[char_name] = results[char_name] or {}
                        results[char_name][storage_name] = results[char_name][storage_name] or {}
                        results[char_name][storage_name][item_id] = quantity
                    end
                end
            end
        end
    end

    return results
end


function filter_duplicates(search_result)
    for char_name, storage_list in pairs(search_result) do
        storage_list[KEY_ITEM_STORAGE_NAME] = nil
    end

    local counts_by_itemid = {}
    for char_name, storage_list in pairs(search_result) do
        for storage_name, item_list in pairs(storage_list) do
            for item_id, quantity in pairs(item_list) do
                counts_by_itemid[item_id] = (counts_by_itemid[item_id] or 0) + 1
            end
        end
    end

    for char_name, storage_list in pairs(search_result) do
        for storage_name, item_list in pairs(storage_list) do
            for item_id, quantity in pairs(item_list) do
                if counts_by_itemid[item_id] == 1 then
                    item_list[item_id] = nil
                end
            end
        end
    end
    return search_result
end


function filter_stackables(search_result)
    for char_name, storage_list in pairs(search_result) do
        storage_list[KEY_ITEM_STORAGE_NAME] = nil
    end

    for char_name, storage_list in pairs(search_result) do
        for storage_name, item_list in pairs(storage_list) do
            for item_id, quantity in pairs(item_list) do
                local item = AshitaCore:GetResourceManager():GetItemById(item_id);
                if not item or item.StackSize <= 1 then
                    item_list[item_id] = nil
                end
            end
        end
    end
    return search_result
end


function display_search_results(result, from_all_chars, terms, duplicates)
    local terms_pattern = build_search_pattern(terms)

    local total_quantity = 0
    local results = {}
    for char_name, storage_list in pairs(result) do
        for storage_name, item_list in pairs(storage_list) do
            for item_id, quantity in pairs(item_list) do
                local names = get_item_names_by_id(storage_name, item_id)

                if terms_pattern ~= '' then
                    total_quantity = total_quantity + quantity
                end

                local prefix = '\30\03' .. char_name .. '/' .. storage_name .. '\30\01'
                local suffix = (quantity > 1 and ' \30\03' .. '(' .. quantity .. ')\30\01' or '')

                local item_name
                if terms_pattern ~= '' then
                    item_name = string.gsub(names.name, '(' .. terms_pattern .. ')', '\30\02%1\30\01')
                    if not names.name:match(terms_pattern) then
                        item_name = item_name .. ' [' ..
                            string.gsub(names.long_name, '(' .. terms_pattern .. ')', '\30\02%1\30\01') ..
                        ']'
                    end
                else
                    item_name = names.name
                end
                if duplicates then
                    table.insert(results, item_name .. ': ' .. prefix .. suffix)
                 else
                    table.insert(results, prefix .. '\30\03: \30\01' .. item_name .. suffix)
                end
            end
        end
    end

    table.sort(results)

    for _, result_string in pairs(results) do
        log('display_search_results', result_string)
    end

    if total_quantity > 0 then
        log('display_search_results', 'Total: ' .. total_quantity)
    end

    if #results == 0 then
        if search_pattern ~= '' then
            if from_all_chars then
                log('display_search_results', 'You have no items that match \'' .. terms .. '\'.')
            else
                log('display_search_results', 'You have no items that match \'' .. terms .. '\' on the specified characters.')
            end
        else
            log('display_search_results', 'You have no items on the specified characters.')
        end
    end
end


function export_to_file(result, export)
    local export_file = io.open(get_storage_path() .. '/' .. export, 'w')

    if not export_file then
        error('export_to_file', 'The file "' .. export .. '" cannot be created.')
        return
    end

    export_file:write('"char";"storage";"item";"quantity"\n')

    for char_name, storage_list in pairs(result) do
        for storage_name, item_list in pairs(storage_list) do
            for item_id, quantity in pairs(item_list) do
                local names = get_item_names_by_id(storage_name, item_id)
                export_file:write('"' .. char_name .. '";"' .. storage_name .. '";"' .. names.name .. '";"' .. quantity .. '"\n')
            end
        end
    end

    export_file:close()

    log('export_to_file', 'The results have been saved to "' .. export .. '"')
end


function handle_command(args)
    local char_include, char_exclude, terms, export, duplicates, stackables = determine_query_elements(args)
    if #char_include == 0 then
        -- If char_include is empty, restrict the search to the currentPlayer's file
        char_include[1] = get_player_name()
    end
    local result = search(char_include, char_exclude, terms)
    if duplicates then
        result = filter_duplicates(result)
    end
    if stackables then
        result = filter_stackables(result)
    end
    local all_chars = #char_include == 0 and #char_exclude == 0
    display_search_results(result, all_chars, terms, duplicates)
    if export ~=nil then
        export_to_file(result, export)
    end
end

-- function hasvalue(table, value)
--     for _, v in pairs(table) do
--         if v == value then
--             return true
--         end
--     end
--     return false
-- end

------------------------------------------------------------------------------------------------
-- Event Handler
------------------------------------------------------------------------------------------------

ashita.events.register('load', 'load_cb', function()
    load_global_storages()
end)

ashita.events.register('incoming_packet', 'incoming_packet_cb', function(id, size, packet, packet_modified, blocked)
    handle_incoming_packet(id, packet)
    return false
end)

ashita.events.register('command', 'command_cb', function(e)

    local cmd = e.command;
    -- print(tostring(cmd))
    if not string.match(cmd, '^/findall') then
        return false
    end

    local args = {}
    for arg in string.gmatch(cmd, '([^%s]+)') do args[#args + 1] = arg end

    update_player()
    if #args > 1 then
        table.remove(args, 1)
        handle_command(args)
    else
        print_help()
    end

    return true
end)
