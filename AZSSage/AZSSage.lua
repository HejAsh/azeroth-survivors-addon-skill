-- AZSSage 4.2b: TOOLTIP strata fix for 1.12 benilla/browser
-- (FULLSCREEN_DIALOG may not exist in all 1.12 builds)
-- All other features remain: History Window, Alerts, Synergies

AZSSageDB = AZSSageDB or {};
local MAXRUNS = 100;
local MINLOSS = 20;
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground";
local FONT = "Fonts\\FRIZQT__.TTF";
local WIDTH = 230;
local ROW_HEIGHT = 18;
local TITLE_HEIGHT = 24;
local MAXROWS = 16;
local MAXTITLES = 4;

local GOLD = { 1.00, 0.82, 0.00 };
local GREEN = { 0.40, 1.00, 0.40 };
local WHITE = { 0.92, 0.92, 0.92 };
local ORANGE = { 1.00, 0.55, 0.10 };
local PURPLE = { 0.72, 0.32, 1.00 };
local AMBER = { 1.00, 0.76, 0.08 };
local RED = { 0.90, 0.25, 0.25 };
local GRAY = { 0.60, 0.60, 0.60 };

local frame = CreateFrame("Frame");
local elapsed = 0;
local enabled = true;
local loaded = false;
local firstPoll = true;
local recorded = false;
local panel;

local function say(msg, c)
    c = c or GOLD;
    DEFAULT_CHAT_FRAME:AddMessage("AZS Sage: " .. msg, c[1], c[2], c[3]);
end

local function pct(x)
    return math.floor(100 * (x or 0) + 0.5) .. "%";
end

local function round(x)
    return math.floor((x or 0) + 0.5);
end

local function Short(value)
    value = value or 0;
    local short, suffix;
    if (value >= 1000000) then
        short, suffix = value / 1000000, "m";
    elseif (value >= 1000) then
        short, suffix = value / 1000, "k";
    else
        return math.floor(value + 0.5);
    end
    local text = string.format("%.1f", short);
    text = string.gsub(text, "%.0$", "");
    return text .. suffix;
end

local function pretty(key)
    key = string.gsub(key or "", "_", " ");
    key = string.gsub(key, "(%a)([%w]*)", function(a, b) return string.upper(a) .. b; end);
    return key;
end

local function squash(s)
    s = string.lower(s or "");
    s = string.gsub(s, "[^%w]", "");
    return s;
end

local function upgradeable()
    local n = 0;
    if (AZS_SPELLS) then n = table.getn(AZS_SPELLS); end
    if (n > 0) then n = n - 1; end
    return n;
end

local function currentClass()
    if (AZS_ZONE and AZS_ZONE.class and AZS_ZONE.class ~= "") then
        return AZS_ZONE.class;
    end
    return nil;
end

local function currentRace()
    if (AZS_ZONE and AZS_ZONE.race and AZS_ZONE.race ~= "") then
        return AZS_ZONE.race;
    end
    return nil;
end

-- The game's full new-spell deck per class, extracted from the client
-- (see references/card-system.md). Keys match AZS_SPELLS.key.
local CLASS_POOLS = {
    warrior = { "cleave", "whirlwind", "thunder_clap", "mortal_strike", "execute", "demo_shout", "battle_shout", "bloodthirst", "rend", "shield_slam", "bloodrage" },
    paladin = { "consecration", "exorcism", "hammer_of_wrath", "holy_shock", "holy_wrath", "judgement", "hammer_of_justice", "holy_light", "divine_shield", "holy_shield", "redemption" },
    hunter = { "auto_shot", "arcane_shot", "multi_shot", "serpent_sting", "volley", "explosive_trap", "concussive_shot", "aimed_shot", "immolation_trap", "frost_trap", "hunters_mark" },
    rogue = { "sinister_strike", "eviscerate", "blade_flurry", "rupture", "kidney_shot", "gouge", "ghostly_strike", "adrenaline_rush", "backstab", "slice_and_dice", "seal_fate" },
    priest = { "smite", "sw_pain", "mind_blast", "holy_nova", "pw_shield", "renew", "holy_fire", "mind_flay", "psychic_scream", "devouring_plague" },
    shaman = { "lightning_bolt", "chain_lightning", "earth_shock", "flame_shock", "frost_shock", "lightning_shield", "magma_totem", "searing_totem", "fire_nova", "healing_wave", "call_of_flame" },
    mage = { "fireball", "frostbolt", "arcane_missiles", "frost_nova", "arcane_explosion", "blizzard", "flamestrike", "fire_blast", "cone_of_cold", "blast_wave", "pyroblast", "ice_barrier", "polymorph" },
    warlock = { "shadow_bolt", "corruption", "immolate", "curse_of_agony", "rain_of_fire", "hellfire", "death_coil", "searing_pain", "drain_life", "fear", "soul_fire" },
    druid = { "wrath", "moonfire", "starfire", "hurricane", "insect_swarm", "entangling_roots", "rejuvenation", "regrowth", "thorns", "swipe", "faerie_fire" },
};

local SPELL_SLOTS = 6;

-- New spells the game can still offer: class pool minus owned (racial last,
-- never in the pool). Returns remaining keys in pool order and slot usage.
local function poolRemaining()
    local cls = currentClass();
    local pool = cls and CLASS_POOLS[cls];
    if (not pool) then return nil; end
    local owned = {};
    local n = upgradeable();
    for i = 1, n do
        owned[squash(AZS_SPELLS[i].key)] = true;
    end
    local left = {};
    for i = 1, table.getn(pool) do
        if (not owned[squash(pool[i])]) then
            table.insert(left, pool[i]);
        end
    end
    return left, n, SPELL_SLOTS;
end

local histCache = {};

local function migrate()
    if (AZSSageDB.wins) then
        for i = 1, table.getn(AZSSageDB.wins) do
            local w = AZSSageDB.wins[i];
            local sp = {};
            local old = w.spells or {};
            for j = 1, table.getn(old) do
                if (type(old[j]) == "string") then
                    local _, _, k, r = string.find(old[j], "^(.-) r(%d+)$");
                    if (k) then
                        table.insert(sp, { k = k, r = tonumber(r) or 0, f = 0 });
                    end
                end
            end
            table.insert(AZSSageDB.runs, {
                out = "win",
                class = w.class,
                zone = w.zone,
                lvl = w.lvl,
                time = w.time,
                spells = sp,
                top = w.top or {},
                procs = w.procs or {}
            });
        end
        AZSSageDB.wins = nil;
    end
    while (table.getn(AZSSageDB.runs) > MAXRUNS) do
        table.remove(AZSSageDB.runs, 1);
    end
    histCache = {};
end

local function classHist(class, race)
    if (not class or not AZSSageDB.runs) then return nil; end
    local ck = class .. "/" .. (race or "");
    if (histCache[ck]) then return histCache[ck]; end
    local h = { n = 0, spells = {}, last = nil };
    for i = 1, table.getn(AZSSageDB.runs) do
        local r = AZSSageDB.runs[i];
        if (r.out == "win" and r.class == class and (not race or r.race == race)) then
            h.n = h.n + 1;
            h.last = r;
            for j = 1, table.getn(r.spells) do
                local s = r.spells[j];
                local e = h.spells[s.k];
                if (not e) then
                    e = { n = 0, rsum = 0, fsum = 0 };
                    h.spells[s.k] = e;
                end
                e.n = e.n + 1;
                e.rsum = e.rsum + (s.r or 0);
                e.fsum = e.fsum + (s.f or 0);
            end
        end
    end
    histCache[ck] = h;
    return h;
end

local function findSynergies()
    local class = currentClass();
    if (not class or not AZSSageDB.runs) then return {}, 0; end
    local combos = {};
    local totalWins = 0;
    for i = 1, table.getn(AZSSageDB.runs) do
        local r = AZSSageDB.runs[i];
        if (r.out == "win" and r.class == class) then
            totalWins = totalWins + 1;
            local inRun = {};
            for j = 1, table.getn(r.spells) do
                inRun[r.spells[j].k] = true;
            end
            local keys = {};
            for k, _ in pairs(inRun) do table.insert(keys, k); end
            table.sort(keys);
            for a = 1, table.getn(keys) do
                for b = a + 1, table.getn(keys) do
                    local pair = keys[a] .. "|" .. keys[b];
                    combos[pair] = (combos[pair] or 0) + 1;
                end
            end
        end
    end
    local result = {};
    for pair, count in pairs(combos) do
        if (count >= 2) then
            local _, _, k1, k2 = string.find(pair, "^(.-)|(.+)$");
            if (k1 and k2) then
                table.insert(result, { k1 = k1, k2 = k2, count = count, pct = count / totalWins });
            end
        end
    end
    table.sort(result, function(a, b) return a.count > b.count; end);
    return result, totalWins;
end

local seen = {};
local scanned = false;
local function resetRun()
    seen = {};
    scanned = false;
end

local function scanSeen()
    if (not AZS_SPELLS or table.getn(AZS_SPELLS) == 0) then return; end
    local t = AZS_GetRunTime() or 0;
    for i = 1, upgradeable() do
        local k = AZS_SPELLS[i].key;
        if (seen[k] == nil) then
            if (scanned) then seen[k] = t; else seen[k] = 0; end
        end
    end
    scanned = true;
end

local function findLine(lines, key)
    local k = squash(key);
    if (k == "") then return nil; end
    local sub = nil;
    for i = 1, table.getn(lines) do
        local n = squash(lines[i].name);
        if (n == k) then return lines[i]; end
        if (not sub and string.len(k) >= 4 and string.len(n) >= 4) then
            if (string.find(n, k, 1, true) or string.find(k, n, 1, true)) then
                sub = lines[i];
            end
        end
    end
    return sub;
end

local function ownedList()
    local out = {};
    if (not AZS_SPELLS) then return out; end
    scanSeen();
    local lines = AZS_GetMeter() or {};
    local t = AZS_GetRunTime() or 0;
    for i = 1, upgradeable() do
        local s = AZS_SPELLS[i];
        local e = findLine(lines, s.key);
        local ent = {
            key = s.key,
            rank = s.rank or 0,
            spell = s.spell,
            cdmax = s.cdmax or 0,
            matched = false,
            dmg = 0,
            share = 0,
            odps = 0
        };
        if (e) then
            ent.matched = true;
            ent.dmg = e.dmg or 0;
            ent.share = e.share or 0;
            local owned = t - (seen[s.key] or 0);
            if (owned < 15) then owned = 15; end
            ent.odps = ent.dmg / owned;
        end
        table.insert(out, ent);
    end
    return out;
end

local function rankOwned()
    local list = ownedList();
    local total = 0;
    for i = 1, table.getn(list) do
        total = total + list[i].odps;
    end
    local h = classHist(currentClass());
    for i = 1, table.getn(list) do
        local e = list[i];
        e.frac = 0;
        if (total > 0) then e.frac = e.odps / total; end
        e.hw = 0;
        e.hh = nil;
        e.score = e.frac;
        if (h and h.n > 0) then
            local hh = h.spells[e.key];
            if (hh) then
                e.hh = hh;
                e.hw = hh.n;
                e.score = e.frac * (1 + 0.3 * hh.n / h.n);
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.score ~= b.score) then return a.score > b.score; end
        return a.key < b.key;
    end);
    return list, h;
end

local function newPicks(h)
    local picks = {};
    if (not h or h.n == 0) then return picks; end
    local have = {};
    if (AZS_SPELLS) then
        for i = 1, table.getn(AZS_SPELLS) do
            have[AZS_SPELLS[i].key] = true;
        end
    end
    for k, e in pairs(h.spells) do
        if (not have[k]) then
            table.insert(picks, { key = k, n = e.n, e = e });
        end
    end
    table.sort(picks, function(a, b)
        if (a.n ~= b.n) then return a.n > b.n; end
        return a.key < b.key;
    end);
    return picks;
end

local function savePanelPos()
    AZSSageDB.bx = panel:GetLeft();
    AZSSageDB.by = panel:GetBottom();
end

local function placePanel()
    panel:ClearAllPoints();
    if (AZSSageDB.bx and AZSSageDB.by) then
        panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", AZSSageDB.bx, AZSSageDB.by);
    else
        -- Default: pinned to the very top of the screen.
        panel:SetPoint("TOP", UIParent, "TOP", 0, -10);
    end
end

panel = CreateFrame("Frame", "AZSSagePanel", UIParent);
panel:SetWidth(WIDTH + 16);
panel:SetHeight(TITLE_HEIGHT + 8);
panel:SetBackdrop({ bgFile = FLAT });
panel:SetBackdropColor(0.04, 0.04, 0.07, 0.88);
panel:SetFrameStrata("TOOLTIP");
panel:SetFrameLevel(32764);
panel:SetMovable(true);
panel:Hide();
placePanel();

local function MakeTitle()
    local handle = CreateFrame("Frame", nil, panel);
    handle:SetWidth(WIDTH - 46);
    handle:SetHeight(TITLE_HEIGHT - 6);
    handle:EnableMouse(true);
    handle:RegisterForDrag("LeftButton");
    handle:SetScript("OnDragStart", function()
        if (IsAltKeyDown()) then panel:StartMoving(); end
    end);
    handle:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing();
        savePanelPos();
    end);
    handle:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT");
        GameTooltip:SetText(this.text:GetText(), 1, 0.82, 0);
        GameTooltip:AddLine("Hold Alt and drag to move.", 1, 1, 1);
        if (this.tipText) then
            GameTooltip:AddLine(this.tipText, 0.7, 0.7, 0.7, 1);
        end
        GameTooltip:Show();
    end);
    handle:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    handle.text = handle:CreateFontString(nil, "OVERLAY");
    handle.text:SetFont(FONT, 11, "OUTLINE");
    handle.text:SetPoint("LEFT", handle, "LEFT", 4, 0);
    handle.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
    handle.note = panel:CreateFontString(nil, "OVERLAY");
    handle.note:SetFont(FONT, 9, "OUTLINE");
    handle.note:SetTextColor(GRAY[1], GRAY[2], GRAY[3]);
    handle:Hide();
    return handle;
end

local TIP_WIDTH = 200;
local TIP_ROW = 16;
local card = CreateFrame("Frame", "AZSSageCard", UIParent);
card:SetFrameStrata("TOOLTIP");
card:SetFrameLevel(32765);
card:SetWidth(TIP_WIDTH + 16);
card:Hide();
card.edge = card:CreateTexture(nil, "BACKGROUND");
card.edge:SetTexture(FLAT);
card.edge:SetPoint("TOPLEFT", card, "TOPLEFT", -1, 1);
card.edge:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 1, -1);
card.fill = card:CreateTexture(nil, "BORDER");
card.fill:SetTexture(FLAT);
card.fill:SetVertexColor(0.05, 0.05, 0.07, 0.97);
card.fill:SetAllPoints(card);
card.title = card:CreateFontString(nil, "OVERLAY");
card.title:SetFont(FONT, 12, "OUTLINE");
card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8);
card.lines = {};

local function CardLine(index, kind, label, value, color)
    local line = card.lines[index];
    if (not line) then
        line = CreateFrame("Frame", nil, card);
        line:SetWidth(TIP_WIDTH);
        line:SetHeight(TIP_ROW);
        line.rule = line:CreateTexture(nil, "ARTWORK");
        line.rule:SetTexture(FLAT);
        line.rule:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 0, 0);
        line.rule:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 0);
        line.label = line:CreateFontString(nil, "OVERLAY");
        line.label:SetFont(FONT, 10);
        line.label:SetPoint("LEFT", line, "LEFT", 2, 0);
        line.value = line:CreateFontString(nil, "OVERLAY");
        line.value:SetFont(FONT, 11, "OUTLINE");
        line.value:SetPoint("RIGHT", line, "RIGHT", -2, 0);
        card.lines[index] = line;
    end
    line:ClearAllPoints();
    line:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -26 - (index - 1) * TIP_ROW);
    line.label:SetText(label);
    line.value:SetText(value or "");
    line.rule:SetHeight(1);
    if (kind == "head") then
        line.label:SetTextColor(color[1], color[2], color[3]);
        line.rule:SetVertexColor(color[1], color[2], color[3], 0.75);
    else
        line.label:SetTextColor(0.80, 0.80, 0.80);
        line.value:SetTextColor(1, 1, 1);
        line.rule:SetVertexColor(color[1], color[2], color[3], 0.22);
    end
    line:Show();
end

local cardRow = nil;
local function ShowCard(row)
    local tip = row and row.tip;
    if (not tip) then
        card:Hide();
        return;
    end
    local color = tip.color;
    card.edge:SetVertexColor(color[1], color[2], color[3], 0.8);
    card.title:SetText(tip.title);
    card.title:SetTextColor(color[1], color[2], color[3]);
    local count = table.getn(tip.lines);
    for i = 1, count do
        local l = tip.lines[i];
        CardLine(i, l[1], l[2], l[3], color);
    end
    for i = count + 1, table.getn(card.lines) do
        card.lines[i]:Hide();
    end
    card:SetHeight(26 + count * TIP_ROW + 8);
    card:ClearAllPoints();
    local left = row:GetLeft() or 0;
    if (left > GetScreenWidth() / 2) then
        card:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", -14, -4);
    else
        card:SetPoint("BOTTOMLEFT", row, "BOTTOMRIGHT", 14, -4);
    end
    card:SetFrameStrata("TOOLTIP");
    card:Show();
end

local function MakeRow()
    local row = CreateFrame("Frame", nil, panel);
    row:SetWidth(WIDTH);
    row:SetHeight(ROW_HEIGHT);
    row.wash = row:CreateTexture(nil, "BACKGROUND");
    row.wash:SetTexture(FLAT);
    row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1);
    row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1);
    row.rule = row:CreateTexture(nil, "BORDER");
    row.rule:SetTexture(FLAT);
    row.rule:SetHeight(1);
    row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0);
    row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0);
    row.label = row:CreateFontString(nil, "OVERLAY");
    row.label:SetFont(FONT, 10, "OUTLINE");
    row.label:SetPoint("LEFT", row, "LEFT", 5, 0);
    row.label:SetWidth(WIDTH - 70);
    row.label:SetHeight(11);
    row.label:SetJustifyH("LEFT");
    row.value = row:CreateFontString(nil, "OVERLAY");
    row.value:SetFont(FONT, 11, "OUTLINE");
    row.value:SetPoint("RIGHT", row, "RIGHT", -5, 0);
    row:EnableMouse(true);
    row:SetScript("OnEnter", function()
        cardRow = this;
        ShowCard(this);
    end);
    row:SetScript("OnLeave", function()
        cardRow = nil;
        card:Hide();
    end);
    row:Hide();
    return row;
end

local function Paint(row, color)
    row.label:SetTextColor(color[1], color[2], color[3]);
    row.value:SetTextColor(color[1], color[2], color[3]);
    row.wash:SetVertexColor(color[1], color[2], color[3], 0.07);
    row.rule:SetVertexColor(color[1], color[2], color[3], 0.28);
end

local titles = {};
for i = 1, MAXTITLES do titles[i] = MakeTitle(); end
local rows = {};
for i = 1, MAXROWS do rows[i] = MakeRow(); end

local function T(text, note, tip)
    return { kind = "title", text = text, note = note, tipText = tip };
end

local function R(label, value, color, tip)
    return { kind = "row", label = label, value = value or "", color = color, tip = tip };
end

local function layout(items)
    local y = -4;
    local ti, ri = 0, 0;
    for i = 1, table.getn(items) do
        local it = items[i];
        if (it.kind == "title") then
            ti = ti + 1;
            local t = titles[ti];
            if (t) then
                if (ti > 1) then y = y - 6; end
                t.tipText = it.tipText;
                t.text:SetText(it.text);
                t:ClearAllPoints();
                t:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y);
                t:Show();
                t.note:SetText(it.note or "");
                t.note:ClearAllPoints();
                t.note:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y - 5);
                y = y - TITLE_HEIGHT;
            end
        else
            ri = ri + 1;
            local row = rows[ri];
            if (row) then
                row.label:SetText(it.label);
                row.value:SetText(it.value);
                Paint(row, it.color or WHITE);
                row.tip = it.tip;
                row:ClearAllPoints();
                row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y);
                row:Show();
                y = y - ROW_HEIGHT;
            end
        end
    end
    for i = ti + 1, MAXTITLES do
        titles[i]:Hide();
        titles[i].note:SetText("");
    end
    for i = ri + 1, MAXROWS do
        rows[i].tip = nil;
        rows[i]:Hide();
    end
    panel:SetHeight(-y + 8);
    if (cardRow) then
        if (cardRow:IsVisible() and cardRow.tip) then
            ShowCard(cardRow);
        else
            cardRow = nil;
            card:Hide();
        end
    end
end

local function rankTip(e, h, color)
    local lines = {};
    table.insert(lines, { "head", "This run", " " });
    table.insert(lines, { "row", "Rank", e.rank });
    if (e.matched) then
        table.insert(lines, { "row", "Share of spell damage", pct(e.frac) });
        table.insert(lines, { "row", "Damage / sec owned", Short(e.odps) });
        table.insert(lines, { "row", "Damage dealt", Short(e.dmg) });
    else
        table.insert(lines, { "row", "Nothing on the meter", " " });
    end
    if (h and h.n > 0) then
        table.insert(lines, { "head", "Your wins", h.n });
        if (e.hh) then
            table.insert(lines, { "row", "Won with it", e.hh.n .. "/" .. h.n });
            table.insert(lines, { "row", "Average rank", string.format("%.1f", e.hh.rsum / e.hh.n) });
            table.insert(lines, { "row", "Average share", pct(e.hh.fsum / e.hh.n) });
        else
            table.insert(lines, { "row", "In none of them", " " });
        end
    end
    return { title = pretty(e.key), color = color, lines = lines };
end

local function pickTip(p, h)
    local lines = {};
    table.insert(lines, { "head", "Your wins", h.n });
    table.insert(lines, { "row", "Won with it", p.n .. "/" .. h.n });
    table.insert(lines, { "row", "Average rank", string.format("%.1f", p.e.rsum / p.n) });
    table.insert(lines, { "row", "Average share", pct(p.e.fsum / p.n) });
    return { title = pretty(p.key), color = PURPLE, lines = lines };
end

local function lastWinTip(w)
    local lines = {};
    table.insert(lines, { "head", "Last win", " " });
    table.insert(lines, { "row", "Level", w.lvl or 0 });
    local tm = w.time or 0;
    table.insert(lines, { "row", "Time", string.format("%d:%02d", math.floor(tm / 60), math.mod(tm, 60)) });
    if (table.getn(w.spells) > 0) then
        table.insert(lines, { "head", "Spells", "share" });
        for i = 1, table.getn(w.spells) do
            if (i > 8) then break; end
            local s = w.spells[i];
            table.insert(lines, { "row", pretty(s.k) .. " r" .. (s.r or 0), pct(s.f) });
        end
    end
    return { title = pretty(w.class or "?"), color = AMBER, lines = lines };
end

-- Rarity weights recovered from the client's deal tables (0x58fb420 / 0x58fb490):
-- four tiers at ~0.92-0.96 / 0.05 / 0.02 / 0.02. Ordering is inferred
-- (common / rare / epic / legendary), pending decompiler confirmation.
local function oddsTip()
    local lines = {
        { "head", "Rarity odds", "inferred" },
        { "row", "Common", "~92-96%" },
        { "row", "Rare", "~5%" },
        { "row", "Epic", "~2%" },
        { "row", "Legendary", "~2%" },
        { "head", "How to play it", " " },
        { "row", "Weak common card", "skip it for gold" },
        { "row", "Rare or better", "take it now" },
        { "row", "Rank-up of your carry", "always good" },
    };
    return { title = "Card rarity odds", color = AMBER, lines = lines };
end

local lastRanked = nil;

local function choosingItems()
    local items = {};
    local ranked, h = rankOwned();
    lastRanked = ranked;
    local n = table.getn(ranked);
    local anyMatched = false;
    for i = 1, n do
        if (ranked[i].matched) then anyMatched = true; end
    end
    local note = nil;
    if (AZS_RUN and AZS_RUN.owed and AZS_RUN.owed > 1) then
        note = AZS_RUN.owed .. " choices";
    end
    table.insert(items, T("Rank-ups", note,
        "Your spells, best upgrade first: damage per second while owned, nudged up for spells in your past wins."));
    if (n > 0) then
        for i = 1, n do
            if (i > 4) then break; end
            local e = ranked[i];
            local c = WHITE;
            if (not e.matched) then
                c = GRAY;
            elseif (i == 1) then
                c = GREEN;
            end
            local value = "-";
            if (e.matched) then value = pct(e.frac); end
            table.insert(items, R(i .. ". " .. pretty(e.key) .. " r" .. e.rank, value, c, rankTip(e, h, c)));
        end
        if (not anyMatched) then
            table.insert(items, R("Waiting for damage data", " ", GRAY));
        end
    else
        if (AZS_SPELLS and table.getn(AZS_SPELLS) > 0) then
            table.insert(items, R("Only racial owned", " ", GRAY));
        else
            table.insert(items, R("No spells yet", " ", GRAY));
        end
        table.insert(items, R("Skip commons unless strong", " ", GRAY));
    end
    table.insert(items, T("New spell", nil, "Spells from your past wins as this class that you do not own yet."));
    local picks = newPicks(h);
    if (picks[1]) then
        for i = 1, 2 do
            local p = picks[i];
            if (p) then
                table.insert(items, R(pretty(p.key), p.n .. "/" .. h.n, PURPLE, pickTip(p, h)));
            end
        end
    else
        table.insert(items, R("AoE first, heal if dying", "", GRAY));
    end
    local left, slots, maxSlots = poolRemaining();
    if (left) then
        if (table.getn(left) == 0) then
            table.insert(items, R("Nothing left to learn", slots .. "/" .. maxSlots, AMBER,
                "Every spell of this class is owned. New-spell cards stop appearing."));
        else
            table.insert(items, R("Pool left", table.getn(left) .. " · slots " .. slots .. "/" .. maxSlots, PURPLE,
                "New spells the game can still offer, in deck order: " .. pretty(table.concat(left, ", ")) .. "."));
        end
    end
    table.insert(items, T("Card odds", nil,
        "Rarity weights recovered from the client's deal tables. Most offers are commons."));
    table.insert(items, R("Common · rare", "92% · 5%", AMBER, oddsTip()));
    table.insert(items, R("Epic · legendary", "2% · 2%", AMBER, oddsTip()));
    table.insert(items, R("Play", "skip weak commons", GREEN, oddsTip()));
    if (h and h.n > 0 and h.last) then
        table.insert(items, T("Past wins", nil, "Wins recorded as this class. Hover the row for the last one."));
        table.insert(items, R(pretty(currentClass()), h.n .. " won", AMBER, lastWinTip(h.last)));
    end
    local syn, totalWins = findSynergies();
    if (table.getn(syn) > 0) then
        table.insert(items, T("Synergies", totalWins .. " wins", "Spells that frequently appear together in your wins."));
        for i = 1, math.min(2, table.getn(syn)) do
            local s = syn[i];
            table.insert(items, R(pretty(s.k1) .. " + " .. pretty(s.k2), s.count .. "/" .. totalWins, AMBER));
        end
    end
    return items;
end

-- Rank-up marker over the game's spell bar: a gold glow + "»" over the
-- button holding the spell Sage says to feed next. Markers live on UIParent
-- at TOOLTIP strata (anchored to the button) so they render above the
-- choosing screen's dim overlay, and follow SurvivorUI's relaid-out buttons.
-- Bar slots map to AZS_SPELLS order (racial last, excluded); a running
-- cooldown pins the true slot when it disagrees with the order guess.
-- Bar-slot recommendation: the card screen's cards are native Bevy UI,
-- so there's no ActionButton* frame to anchor to. Use a floating banner:
-- a single line at screen top with the feed-target spell's key in green
-- (visible over cards and during play; hides automatically out of run).
local recBanner = CreateFrame("Frame", "AZSSageRecBanner", UIParent);
recBanner:SetHeight(28);
recBanner:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 260, -6);
recBanner:SetFrameStrata("TOOLTIP");
recBanner:SetFrameLevel(32762);
recBanner:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } });
local recBack = recBanner:CreateTexture(nil, "BORDER");
recBack:SetTexture(FLAT);
recBack:SetVertexColor(0.06, 0.06, 0.08, 0.92);
recBack:SetPoint("TOPLEFT", recBanner, "TOPLEFT", 1, -1);
recBack:SetPoint("BOTTOMRIGHT", recBanner, "BOTTOMRIGHT", -1, 1);
local recAccent = recBanner:CreateTexture(nil, "OVERLAY");
recAccent:SetTexture(FLAT);
recAccent:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1);
recAccent:SetWidth(4);
recAccent:SetPoint("TOPLEFT", recBanner, "TOPLEFT", 0, 0);
recAccent:SetPoint("BOTTOMLEFT", recBanner, "BOTTOMLEFT", 0, 0);
local recText = recBanner:CreateFontString(nil, "OVERLAY");
recText:SetFont(FONT, 13, "OUTLINE");
recText:SetPoint("CENTER", recBanner, "CENTER", 0, 0);
recText:SetJustifyH("CENTER");
local markers = {};

local function MarkerFor(slot)
    if (markers[slot]) then return markers[slot]; end
    local btn = getglobal("ActionButton" .. slot);
    if (not btn) then return nil; end
    local m = CreateFrame("Frame", "AZSSageBarMarker" .. slot, UIParent);
    m:SetWidth(40);
    m:SetHeight(40);
    m:SetFrameStrata("TOOLTIP");
    m:SetFrameLevel(32760);
    m:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2);
    local outline = m:CreateTexture(nil, "OVERLAY");
    outline:SetTexture(FLAT);
    outline:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1);
    outline:SetPoint("CENTER", m, "CENTER", 0, 0);
    outline:SetWidth(40);
    outline:SetHeight(40);
    local inner = m:CreateTexture(nil, "BORDER");
    inner:SetTexture(FLAT);
    inner:SetVertexColor(0, 0, 0, 0.8);
    inner:SetPoint("CENTER", m, "CENTER", 0, 0);
    inner:SetWidth(34);
    inner:SetHeight(34);
    local mg = m:CreateTexture(nil, "OVERLAY");
    mg:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight");
    mg:SetBlendMode("ADD");
    mg:SetAllPoints(m);
    mg:SetAlpha(0.4);
    m.tag = m:CreateFontString(nil, "OVERLAY");
    m.tag:SetFont(FONT, 18, "THICKOUTLINE");
    m.tag:SetPoint("CENTER", m, "CENTER", 0, -2);
    m.tag:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
    m.tag:SetText("\194\187");
    m:SetScript("OnUpdate", function()
        -- Gentle pulse; the flat gold outline is always visible, the glow breathes.
        local a = 0.65 + 0.35 * math.abs(math.sin(GetTime() * 4));
        mg:SetAlpha(a);
        this.tag:SetAlpha(a);
    end);
    m:Hide();
    markers[slot] = m;
    return m;
end

local function HideRankMarkers()
    for _, m in pairs(markers) do m:Hide(); end
end

local function UpdateRecBanner(ranked)
    local target = ranked and ranked[1];
    if (not enabled) then
        recBanner:Hide();
        return;
    end
    if (not target) then
        recBanner:Hide();
        return;
    end
    local msg = (currentPhase == "choosing")
        and ("Cards open · feed: " .. pretty(target.key) .. " r" .. target.rank)
        or ("While playing · feed: " .. pretty(target.key) .. " r" .. target.rank);
    recText:SetText(msg);
    recBanner:SetWidth(math.max(260, recText:GetStringWidth() + 30));
    recText:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
    recBanner:Show();
end

local function UpdateRankMarkers(ranked)
    local target = ranked and ranked[1];
    if (not enabled) then
        for _, m in pairs(markers) do m:Hide(); end
        recBanner:Hide();
        return;
    end
    if (not target) then
        for _, m in pairs(markers) do m:Hide(); end
        recBanner:Hide();
        return;
    end
    -- Banner text always reflects the recommendation; no phase gate needed.
    -- Recommendation banner: visible regardless of phase (cards hide the panel
    -- but the user wants it present); text switches between card/build context.
    if (currentPhase == "choosing") then
        local picks = newPicks(classHist(currentClass()));
        if (table.getn(picks) > 0) then
            recText:SetText("Cards open · feed: " .. pretty(target.key) .. " r" .. target.rank);
        else
            recText:SetText("Cards open · feed: " .. pretty(target.key) .. " r" .. target.rank);
        end
    else
        recText:SetText("While playing · feed: " .. pretty(target.key) .. " r" .. target.rank);
    end
    recBanner:SetWidth(math.max(180, recText:GetStringWidth() + 30));
    recText:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
    recText:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
    recBack:SetTexture(FLAT);
    recBack:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.15);  -- faint gold wash
    recBack:SetPoint("TOPLEFT", recBanner, "TOPLEFT", 2, -1);
    recBack:SetPoint("BOTTOMRIGHT", recBanner, "BOTTOMRIGHT", -2, 1);
    recAccent:SetTexture(FLAT);
    recAccent:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1);
    recAccent:SetPoint("LEFT", recBanner, "LEFT", 0, 0);
    recAccent:SetPoint("TOP", recBanner, "TOP", 0, 0);
    recAccent:SetPoint("BOTTOM", recBanner, "BOTTOM", 0, 0);
    recAccent:SetWidth(4);
    recText:SetPoint("CENTER", recBanner, "CENTER", 0, 0);
    recBanner:Show();
    -- The bar-slot marker: only attempt if the button exists; otherwise
    -- leave banner-only. Never hide banner when recommendation exists.
    local key = squash(target.key);
    local slot = nil;
    local n = upgradeable();
    if (n > 6) then n = 6; end
    for i = 1, n do
        if (AZS_SPELLS[i] and squash(AZS_SPELLS[i].key) == key) then
            slot = i;
            break;
        end
    end
    if (slot) then
        local m = MarkerFor(slot);
        if (m) then m:Show(); else HideRankMarkers(); end
    else
        HideRankMarkers();
    end
    -- Hide any leftover markers for non-target slots.
    for s, m in pairs(markers) do
        local btn = getglobal("ActionButton" .. s);
        if (m:IsShown() and btn and not (target and squash(target.key) == squash(AZS_SPELLS[s] and AZS_SPELLS[s].key or ""))) then
            m:Hide();
        end
    end
end

local function playingItems()
    local items = {};
    local ranked, h = rankOwned();
    lastRanked = ranked;
    local weak, carry, burst = nil, nil, nil;
    local matched = 0;
    for i = 1, table.getn(ranked) do
        local e = ranked[i];
        if (e.matched) then
            matched = matched + 1;
            if (not weak or e.frac < weak.frac) then weak = e; end
            if (not carry or e.frac > carry.frac) then carry = e; end
        end
        if (e.cdmax > 0 and (not burst or e.cdmax > burst.cdmax)) then
            burst = e;
        end
    end
    table.insert(items, T("Live build", nil,
        "Where your damage comes from right now, and which spell to rank up next."));
    if (table.getn(ranked) == 0) then
        table.insert(items, R("Only racial owned", " ", GRAY));
    elseif (matched == 0) then
        table.insert(items, R("Waiting for damage data", " ", GRAY));
    else
        table.insert(items, R("Next rank-up", pretty(ranked[1].key) .. " r" .. ranked[1].rank, GREEN,
            rankTip(ranked[1], h, GREEN)));
        table.insert(items, R("Carry", pretty(carry.key) .. "  " .. pct(carry.frac), WHITE,
            rankTip(carry, h, WHITE)));
        if (weak ~= carry) then
            table.insert(items, R("Weak", pretty(weak.key) .. "  " .. pct(weak.frac), GRAY,
                rankTip(weak, h, GRAY)));
        end
    end
    if (burst) then
        table.insert(items, R("Burst", pretty(burst.key) .. "  " .. math.floor(burst.cdmax) .. "s", ORANGE));
    end
    local left, slots, maxSlots = poolRemaining();
    if (left) then
        if (table.getn(left) == 0) then
            table.insert(items, R("New pool", "learned out", AMBER));
        else
            table.insert(items, R("New pool", table.getn(left) .. " left · " .. slots .. "/" .. maxSlots, PURPLE,
                "Still unowned: " .. pretty(table.concat(left, ", ")) .. "."));
        end
    end
    local lines = AZS_GetMeter() or {};
    for i = 1, table.getn(lines) do
        if (lines[i].proc == 1) then
            table.insert(items, R("Talent", lines[i].name .. "  " .. Short(lines[i].dps or 0) .. "/s", PURPLE));
            break;
        end
    end
    if (AZS_BUFFS and AZS_SPELLS) then
        local shown = 0;
        for i = 1, table.getn(AZS_BUFFS) do
            local b = AZS_BUFFS[i];
            for j = 1, upgradeable() do
                if (AZS_SPELLS[j].spell == b.spell) then
                    table.insert(items,
                        R("Buff", pretty(AZS_SPELLS[j].key) .. "  " .. math.floor(b.left or 0) .. "s", GRAY));
                    shown = shown + 1;
                    break;
                end
            end
            if (shown >= 2) then break; end
        end
    end
    return items;
end

local function refresh()
    local lines;
    -- Always update both the card-mode content (for choices) and the banner.
    if (currentPhase == "choosing") then
        lines = choosingItems();
    else
        lines = playingItems();
    end
    layout(lines);
    UpdateRecBanner(lastRanked);
    UpdateRankMarkers(lastRanked);
    -- Banner = recommendation (primary, visible regardless of phase);
    -- bar marker = best-effort secondary (no ActionButton* on this client).
    -- Re-assert strata: the game's choice overlay (same TOOLTIP strata,
    -- higher level) must not bury the recommendation.
    panel:SetFrameStrata("TOOLTIP");
    panel:SetFrameLevel(32764);
    panel:Show();
end

local function hide()
    panel:Hide();
    card:Hide();
    cardRow = nil;
    HideRankMarkers();
end

-- Alert System
local alertFrame = CreateFrame("Frame", "AZSSageAlert", UIParent);
alertFrame:SetFrameStrata("TOOLTIP");
alertFrame:SetFrameLevel(32766);
alertFrame:SetWidth(250);
alertFrame:SetHeight(40);
alertFrame:SetPoint("TOP", UIParent, "TOP", 0, -150);
alertFrame:SetBackdrop({ bgFile = FLAT });
alertFrame:SetBackdropColor(0.8, 0.2, 0.8, 0.8);
alertFrame:Hide();
alertFrame.text = alertFrame:CreateFontString(nil, "OVERLAY");
alertFrame.text:SetFont(FONT, 14, "OUTLINE");
alertFrame.text:SetPoint("CENTER", alertFrame, "CENTER", 0, 0);
alertFrame.text:SetTextColor(1, 1, 1);

local alertElapsed = 0;
alertFrame:SetScript("OnUpdate", function()
    alertElapsed = alertElapsed + arg1;
    if (alertElapsed > 2.5) then
        this:Hide();
    else
        local alpha = 1 - (alertElapsed / 2.5);
        this:SetAlpha(alpha);
    end
end);

local function ShowAlert(msg, color)
    alertFrame.text:SetText(msg);
    if (color) then
        alertFrame:SetBackdropColor(color[1], color[2], color[3], 0.85);
    end
    alertElapsed = 0;
    alertFrame:SetAlpha(1);
    alertFrame:SetFrameStrata("TOOLTIP");
    alertFrame:Show();
    PlaySound("igSpellBookOpen");
end

local alertState = { choosing = false, lastCd = {} };

-- History Window
local histFrame = CreateFrame("Frame", "AZSSageHistoryFrame", UIParent);
histFrame:SetFrameStrata("TOOLTIP");
histFrame:SetFrameLevel(32763);
histFrame:SetWidth(450);
histFrame:SetHeight(480);
histFrame:SetBackdrop({ bgFile = FLAT });
histFrame:SetBackdropColor(0.05, 0.05, 0.07, 0.95);
histFrame:SetMovable(true);
histFrame:EnableMouse(true);
histFrame:RegisterForDrag("LeftButton");
histFrame:SetScript("OnDragStart", function() histFrame:StartMoving(); end);
histFrame:SetScript("OnDragStop", function() histFrame:StopMovingOrSizing(); end);
histFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
histFrame:Hide();

local hTitle = histFrame:CreateFontString(nil, "OVERLAY");
hTitle:SetFont(FONT, 14, "OUTLINE");
hTitle:SetPoint("TOP", histFrame, "TOP", 0, -10);
hTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
hTitle:SetText("Run History & Synergies");

local hClose = CreateFrame("Button", nil, histFrame);
hClose:SetWidth(24);
hClose:SetHeight(24);
hClose:SetPoint("TOPRIGHT", histFrame, "TOPRIGHT", -5, -5);
hClose:SetBackdrop({ bgFile = FLAT });
hClose:SetBackdropColor(0.8, 0.2, 0.2, 0.8);
hClose:SetScript("OnClick", function() histFrame:Hide(); end);
hClose:SetScript("OnEnter", function() this:SetBackdropColor(1, 0.4, 0.4, 1); end);
hClose:SetScript("OnLeave", function() this:SetBackdropColor(0.8, 0.2, 0.2, 0.8); end);
local hCloseText = hClose:CreateFontString(nil, "OVERLAY");
hCloseText:SetFont(FONT, 12, "OUTLINE");
hCloseText:SetPoint("CENTER", hClose, "CENTER", 0, 0);
hCloseText:SetText("X");

local histFilter = "ALL";
local histRows = {};
local ROW_H = 22;

local function UpdateHistoryWindow()
    local runs = AZSSageDB.runs or {};
    local class = currentClass();
    local filtered = {};
    for i = table.getn(runs), 1, -1 do
        local r = runs[i];
        if (histFilter == "ALL" or (histFilter == "CLASS" and r.class == class)) then
            table.insert(filtered, r);
        end
    end
    for i = 1, 12 do
        local row = histRows[i];
        if (row) then
            local r = filtered[i];
            if (r) then
                local color = (r.out == "win") and GREEN or RED;
                row.text:SetText(string.format("%s | %s/%s | Lvl %d | %ds", string.upper(r.out), r.class or "?",
                    r.zone or "?", r.lvl or 0, r.time or 0));
                row.text:SetTextColor(color[1], color[2], color[3]);
                row:Show();
            else
                row:Hide();
            end
        end
    end
    local syn, totalWins = findSynergies();
    if (table.getn(syn) > 0) then
        local lines = {};
        for i = 1, math.min(5, table.getn(syn)) do
            local s = syn[i];
            table.insert(lines, string.format("%s + %s (%d/%d wins)", pretty(s.k1), pretty(s.k2), s.count, totalWins));
        end
        histFrame.synText:SetText(table.concat(lines, "\n"));
    else
        histFrame.synText:SetText("No synergies found yet. Win more games!");
    end
end

local function makeFilterBtn(text, filterVal, x, y)
    local btn = CreateFrame("Button", nil, histFrame);
    btn:SetWidth(100);
    btn:SetHeight(20);
    btn:SetPoint("TOPLEFT", histFrame, "TOPLEFT", x, y);
    btn:SetBackdrop({ bgFile = FLAT });
    btn:SetBackdropColor(0.2, 0.2, 0.2, 0.8);
    btn.text = btn:CreateFontString(nil, "OVERLAY");
    btn.text:SetFont(FONT, 10, "OUTLINE");
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0);
    btn.text:SetText(text);
    btn:SetScript("OnClick", function()
        histFilter = filterVal;
        UpdateHistoryWindow();
    end);
    return btn;
end

makeFilterBtn("All Runs", "ALL", 10, -35);
makeFilterBtn("Current Class", "CLASS", 120, -35);

-- Clear run history: two-step confirm, disarmed whenever the window closes.
local hClearArmed = false;
local hClear = CreateFrame("Button", nil, histFrame);
hClear:SetWidth(100);
hClear:SetHeight(20);
hClear:SetPoint("TOPLEFT", histFrame, "TOPLEFT", 240, -35);
hClear:SetBackdrop({ bgFile = FLAT });
hClear:SetBackdropColor(0.2, 0.2, 0.2, 0.8);
hClear.text = hClear:CreateFontString(nil, "OVERLAY");
hClear.text:SetFont(FONT, 10, "OUTLINE");
hClear.text:SetPoint("CENTER", hClear, "CENTER", 0, 0);
hClear.text:SetText("Clear History");
hClear:SetScript("OnClick", function()
    if (hClearArmed) then
        AZSSageDB.runs = {};
        histCache = {};
        hClearArmed = false;
        hClear.text:SetText("Clear History");
        hClear:SetBackdropColor(0.2, 0.2, 0.2, 0.8);
        say("run history cleared");
        UpdateHistoryWindow();
    else
        hClearArmed = true;
        hClear.text:SetText("Really clear?");
        hClear:SetBackdropColor(0.8, 0.2, 0.2, 0.8);
    end
end);
hClear:SetScript("OnEnter", function()
    if (hClearArmed) then this:SetBackdropColor(1, 0.3, 0.3, 1); end
end);
hClear:SetScript("OnLeave", function()
    this:SetBackdropColor(hClearArmed and 0.8 or 0.2, 0.2, 0.2, 0.8);
end);
histFrame:SetScript("OnHide", function()
    -- Closing the window disarms the clear button.
    hClearArmed = false;
    hClear.text:SetText("Clear History");
    hClear:SetBackdropColor(0.2, 0.2, 0.2, 0.8);
end);

for i = 1, 12 do
    local row = CreateFrame("Button", nil, histFrame);
    row:SetWidth(430);
    row:SetHeight(ROW_H);
    row:SetPoint("TOPLEFT", histFrame, "TOPLEFT", 10, -65 - (i - 1) * ROW_H);
    row:SetBackdrop({ bgFile = FLAT });
    row:SetBackdropColor(0, 0, 0, 0);
    row.text = row:CreateFontString(nil, "OVERLAY");
    row.text:SetFont(FONT, 10);
    row.text:SetPoint("LEFT", row, "LEFT", 5, 0);
    row.text:SetJustifyH("LEFT");
    row.text:SetWidth(420);
    row:SetScript("OnEnter", function() this:SetBackdropColor(1, 1, 1, 0.1); end);
    row:SetScript("OnLeave", function() this:SetBackdropColor(0, 0, 0, 0); end);
    histRows[i] = row;
end

local synTitle = histFrame:CreateFontString(nil, "OVERLAY");
synTitle:SetFont(FONT, 12, "OUTLINE");
synTitle:SetPoint("TOPLEFT", histFrame, "TOPLEFT", 10, -340);
synTitle:SetTextColor(AMBER[1], AMBER[2], AMBER[3]);
synTitle:SetText("Top Synergies:");

histFrame.synText = histFrame:CreateFontString(nil, "OVERLAY");
histFrame.synText:SetFont(FONT, 10);
histFrame.synText:SetPoint("TOPLEFT", histFrame, "TOPLEFT", 10, -360);
histFrame.synText:SetWidth(430);
histFrame.synText:SetJustifyH("LEFT");
histFrame.synText:SetTextColor(WHITE[1], WHITE[2], WHITE[3]);

histFrame:SetScript("OnShow", function() UpdateHistoryWindow(); end);

-- Recording
local function recordRun(outcome)
    local t = AZS_GetRunTime() or 0;
    if (outcome == "loss" and t < MINLOSS) then return; end
    local lines, total, dps = AZS_GetMeter();
    lines = lines or {};
    local list = rankOwned();
    local spells = {};
    for i = 1, table.getn(list) do
        local e = list[i];
        table.insert(spells, {
            k = e.key,
            r = e.rank,
            f = math.floor(e.frac * 1000 + 0.5) / 1000,
            d = round(e.odps)
        });
    end
    local top, procs = {}, {};
    for i = 1, table.getn(lines) do
        if (table.getn(top) < 3) then
            table.insert(top, lines[i].name .. "  " .. pct(lines[i].share));
        end
        if (lines[i].proc == 1 and table.getn(procs) < 3) then
            table.insert(procs, lines[i].name);
        end
    end
    local at = "";
    if (date) then at = date("%Y-%m-%d %H:%M"); end
    table.insert(AZSSageDB.runs, {
        out = outcome,
        at = at,
        class = currentClass() or "?",
        race = currentRace() or "?",
        zone = (AZS_ZONE and AZS_ZONE.zone) or "?",
        mods = (AZS_ZONE and AZS_ZONE.mods) or "",
        lvl = (AZS_RUN and AZS_RUN.lvl) or 0,
        time = math.floor(t),
        dealt = round(total),
        dps = round(dps),
        taken = round(AZS_RUN and AZS_RUN.taken),
        spells = spells,
        top = top,
        procs = procs
    });
    while (table.getn(AZSSageDB.runs) > MAXRUNS) do
        table.remove(AZSSageDB.runs, 1);
    end
    histCache = {};
    local c = GREEN;
    if (outcome ~= "win") then c = RED; end
    say(string.upper(outcome) .. " recorded as " .. (currentClass() or "?")
        .. " (" .. table.getn(AZSSageDB.runs) .. " kept).", c);
end

local function printRuns()
    if (histFrame:IsVisible()) then
        histFrame:Hide();
    else
        histFrame:SetFrameStrata("TOOLTIP");
        histFrame:Show();
    end
end

local function printBest()
    local class, race = currentClass(), currentRace();
    if (not class) then
        say("Start a run first: best spells use your current class/race.");
        return;
    end
    local label = class;
    local h = nil;
    if (race) then
        h = classHist(class, race);
        label = race .. " " .. class;
    end
    if (not h or h.n == 0) then
        h = classHist(class);
        if (race and h and h.n > 0) then
            say("No wins as " .. label .. " yet: showing all " .. class .. " wins.", GRAY);
        end
        label = class;
    end
    if (not h or h.n == 0) then
        say("No wins recorded as " .. label .. " yet.");
        return;
    end
    say(label .. ": " .. h.n .. " win(s). Spells by how often they won:");
    local arr = {};
    for k, e in pairs(h.spells) do
        table.insert(arr, { key = k, e = e });
    end
    table.sort(arr, function(a, b)
        if (a.e.n ~= b.e.n) then return a.e.n > b.e.n; end
        return a.key < b.key;
    end);
    for i = 1, table.getn(arr) do
        if (i > 10) then break; end
        local e = arr[i].e;
        say("   " .. arr[i].key .. "   " .. e.n .. "/" .. h.n
            .. "  avg rank " .. string.format("%.1f", e.rsum / e.n)
            .. "  avg dmg share " .. pct(e.fsum / e.n), WHITE);
    end
end

-- Minimap button
local mmBtn, mmMenu;
local mmItems = {};
local mmDragged = false;

local function mmShape()
    if (AZSSageDB.mmShape) then return AZSSageDB.mmShape; end
    if (GetMinimapShape) then
        if (GetMinimapShape() == "ROUND") then return "round"; end
        return "square";
    end
    return "round";
end

local function mmPlace()
    local a = AZSSageDB.mmAngle or (math.pi * 1.25);
    local w = Minimap:GetWidth();
    if (not w or w < 20) then w = 140; end
    local r = w / 2 + 2;
    local x, y = math.cos(a), math.sin(a);
    if (mmShape() == "square") then
        x = x * r * 1.4143;
        y = y * r * 1.4143;
        if (x > r) then x = r; elseif (x < -r) then x = -r; end
        if (y > r) then y = r; elseif (y < -r) then y = -r; end
    else
        x = x * r;
        y = y * r;
    end
    mmBtn:ClearAllPoints();
    mmBtn:SetPoint("CENTER", Minimap, "CENTER", x, y);
end

local function toggleEnabled()
    enabled = not enabled;
    if (not enabled) then hide(); end
    say((enabled and "on") or "off");
end

local function toggleShape()
    if (mmShape() == "square") then
        AZSSageDB.mmShape = "round";
    else
        AZSSageDB.mmShape = "square";
    end
    mmPlace();
    say("minimap button: " .. AZSSageDB.mmShape);
end

local function resetPositions()
    AZSSageDB.mmAngle = nil;
    AZSSageDB.mmShape = nil;
    AZSSageDB.bx = nil;
    AZSSageDB.by = nil;
    mmPlace();
    placePanel();
    say("positions reset");
end

local MENU_ROW = 18;
local function mmRefreshMenu()
    for i = 1, table.getn(mmItems) do
        mmItems[i].text:SetText(mmItems[i].label());
    end
end

local function mmToggleMenu()
    if (mmMenu:IsVisible()) then
        mmMenu:Hide();
        return;
    end
    mmRefreshMenu();
    mmMenu:ClearAllPoints();
    local _, cy = mmBtn:GetCenter();
    if (cy and cy < GetScreenHeight() / 2) then
        mmMenu:SetPoint("BOTTOMRIGHT", mmBtn, "TOPRIGHT", 0, 4);
    else
        mmMenu:SetPoint("TOPRIGHT", mmBtn, "BOTTOMRIGHT", 0, -4);
    end
    mmMenu:SetFrameStrata("TOOLTIP");
    mmMenu:Show();
end

local function mmEntry(index, labelFn, fn)
    local b = CreateFrame("Button", nil, mmMenu);
    b:SetWidth(134);
    b:SetHeight(MENU_ROW);
    b:SetPoint("TOPLEFT", mmMenu, "TOPLEFT", 8, -8 - (index - 1) * MENU_ROW);
    b.wash = b:CreateTexture(nil, "BACKGROUND");
    b.wash:SetTexture(FLAT);
    b.wash:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.12);
    b.wash:SetAllPoints(b);
    b.wash:Hide();
    b.text = b:CreateFontString(nil, "OVERLAY");
    b.text:SetFont(FONT, 10, "OUTLINE");
    b.text:SetPoint("LEFT", b, "LEFT", 5, 0);
    b.text:SetTextColor(WHITE[1], WHITE[2], WHITE[3]);
    b:SetScript("OnEnter", function() this.wash:Show(); end);
    b:SetScript("OnLeave", function() this.wash:Hide(); end);
    b:SetScript("OnClick", function()
        mmMenu:Hide();
        fn();
    end);
    table.insert(mmItems, { text = b.text, label = labelFn });
end

local function mmMakeMenu()
    mmMenu = CreateFrame("Frame", "AZSSageMinimapMenu", UIParent);
    mmMenu:SetFrameStrata("TOOLTIP");
    mmMenu:SetFrameLevel(32762);
    mmMenu:SetWidth(150);
    mmMenu:SetHeight(16 + 6 * MENU_ROW);
    local edge = mmMenu:CreateTexture(nil, "BACKGROUND");
    edge:SetTexture(FLAT);
    edge:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.8);
    edge:SetPoint("TOPLEFT", mmMenu, "TOPLEFT", -1, 1);
    edge:SetPoint("BOTTOMRIGHT", mmMenu, "BOTTOMRIGHT", 1, -1);
    local fill = mmMenu:CreateTexture(nil, "BORDER");
    fill:SetTexture(FLAT);
    fill:SetVertexColor(0.05, 0.05, 0.07, 0.97);
    fill:SetAllPoints(mmMenu);
    mmEntry(1, function() return "Sage: " .. ((enabled and "on") or "off"); end, toggleEnabled);
    mmEntry(2, function() return "History Window"; end, printRuns);
    mmEntry(3, function() return "Best spells"; end, printBest);
    mmEntry(4, function() return "Minimap: " .. mmShape(); end, toggleShape);
    mmEntry(5, function() return "Reset positions"; end, resetPositions);
    mmMenu:Hide();
end

local function mmMake()
    mmBtn = CreateFrame("Button", "AZSSageMinimapButton", Minimap);
    mmBtn:SetWidth(24);
    mmBtn:SetHeight(24);
    mmBtn:SetFrameStrata("MEDIUM");
    mmBtn:SetFrameLevel(Minimap:GetFrameLevel() + 6);
    mmBtn.edge = mmBtn:CreateTexture(nil, "BACKGROUND");
    mmBtn.edge:SetTexture(FLAT);
    mmBtn.edge:SetVertexColor(0, 0, 0, 1);
    mmBtn.edge:SetPoint("TOPLEFT", mmBtn, "TOPLEFT", -1, 1);
    mmBtn.edge:SetPoint("BOTTOMRIGHT", mmBtn, "BOTTOMRIGHT", 1, -1);
    local fill = mmBtn:CreateTexture(nil, "BORDER");
    fill:SetTexture(FLAT);
    fill:SetVertexColor(0.05, 0.05, 0.07, 0.97);
    fill:SetAllPoints(mmBtn);
    local glyph = mmBtn:CreateFontString(nil, "OVERLAY");
    glyph:SetFont(FONT, 13, "OUTLINE");
    glyph:SetPoint("CENTER", mmBtn, "CENTER", 0, 0);
    glyph:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
    glyph:SetText("S");
    mmBtn:SetPoint("CENTER", Minimap, "CENTER", 0, 0);
    mmBtn:RegisterForDrag("LeftButton");
    mmBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp");
    mmBtn:SetScript("OnDragStart", function()
        mmDragged = false;
        this:SetScript("OnUpdate", function()
            mmDragged = true;
            local mx, my = Minimap:GetCenter();
            local px, py = GetCursorPosition();
            local s = Minimap:GetEffectiveScale();
            AZSSageDB.mmAngle = math.atan2(py / s - my, px / s - mx);
            mmPlace();
        end);
    end);
    mmBtn:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil); end);
    mmBtn:SetScript("OnClick", function()
        if (mmDragged) then
            mmDragged = false;
            return;
        end
        if (arg1 == "RightButton") then
            mmToggleMenu();
        else
            toggleEnabled();
        end
    end);
    mmBtn:SetScript("OnEnter", function()
        this.edge:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.8);
        GameTooltip:SetOwner(this, "ANCHOR_LEFT");
        GameTooltip:SetText("AZS Sage", 1, 0.82, 0);
        GameTooltip:AddLine("Left-click: on/off", 1, 1, 1);
        GameTooltip:AddLine("Right-click: menu", 1, 1, 1);
        GameTooltip:AddLine("Drag: move button", 0.7, 0.7, 0.7);
        GameTooltip:Show();
    end);
    mmBtn:SetScript("OnLeave", function()
        this.edge:SetVertexColor(0, 0, 0, 1);
        GameTooltip:Hide();
    end);
end

-- Wiring
mmMakeMenu();
mmMake();

local function onLoaded()
    AZSSageDB = AZSSageDB or {};
    AZSSageDB.runs = AZSSageDB.runs or {};
    migrate();
    placePanel();
    mmPlace();
    loaded = true;
end

frame:RegisterEvent("VARIABLES_LOADED");
frame:RegisterEvent("CHAT_MSG_ADDON");
frame:SetScript("OnEvent", function()
    if (event == "VARIABLES_LOADED") then
        onLoaded();
        return;
    end
    if (not loaded) then return; end
    if (arg1 == "AZSZONE") then
        recorded = false;
        resetRun();
        return;
    end
    if (not enabled) then return; end
    if (arg1 == "AZSMETER" and panel:IsVisible()) then
        refresh(AZS_GetPhase());
    end
end);

frame:SetScript("OnUpdate", function()
    if (not loaded) then return; end
    elapsed = elapsed + arg1;
    if (elapsed < 0.25) then return; end
    elapsed = 0;
    local ph = AZS_GetPhase();

    if (firstPoll) then
        firstPoll = false;
        if (ph == "victory" or ph == "dead") then recorded = true; end
    end
    if (ph == "ready") then recorded = false; end
    if (not recorded) then
        local won = AZS_RUN and AZS_RUN.won == 1;
        if (ph == "victory" or (won and (ph == "playing" or ph == "choosing"))) then
            recorded = true;
            recordRun("win");
        elseif (ph == "dead" and not won) then
            recorded = true;
            recordRun("loss");
        end
    end
    if (not enabled) then
        HideRankMarkers();
        return;
    end

    -- Panel content: card mode during choices; build mode when playing.
    -- Always visible (no phase gate) so the recommendation is present regardless.
    local currentPhase = AZS_GetPhase();
    if (currentPhase == "choosing") then
        layout(choosingItems());
    else
        layout(playingItems());
    end
    -- Update banner (primary recommendation) and bar markers (secondary,
    -- no ActionButton* frame available on this client) regardless of phase.
    UpdateRecBanner(lastRanked);
    UpdateRankMarkers(lastRanked);

    -- Alert logic: on-cooldown -> ready transition only. Level-up choice
    -- screens (ph == "choosing") do not reset the latch, and defensive
    -- casts that sit at cd == 0 stay silent; only the first 0-cooldown
    -- arrival after a running cooldown triggers it.
    if (ph == "playing" and AZS_SPELLS) then
        -- Alert on the on-cooldown -> ready transition only. A spell that
        -- merely sits ready (defensive casts) stays silent, and level-up
        -- choice screens do not reset the latch.
        local seen = {};
        for i = 1, upgradeable() do
            local s = AZS_SPELLS[i];
            if (s.cdmax and s.cdmax > 30) then
                seen[s.key] = true;
                local cd = s.cd or 0;
                local last = alertState.lastCd[s.key];
                if (last and last > 0 and cd == 0) then
                    ShowAlert(pretty(s.key) .. " Ready!", ORANGE);
                end
                alertState.lastCd[s.key] = cd;
            end
        end
        for k in pairs(alertState.lastCd) do
            if (not seen[k]) then alertState.lastCd[k] = nil; end
        end
    else
        alertState.lastCd = {};
    end

    if (ph == "choosing") then
        refresh("choosing");
    elseif (ph == "playing" and AZS_GetRunTime() ~= nil) then
        refresh("playing");
    else
        -- Keep panel visible for phases like paused/dead/victory/ready;
        -- only refresh content, never hide (user wants the recommendation
        -- present regardless, including during choice screens).
        refresh(AZS_GetPhase());
    end
end);

SLASH_SAGE1 = "/sage";
SlashCmdList["SAGE"] = function(msg)
    msg = string.lower(msg or "");
    local _, _, cmd = string.find(msg, "^(%S+)");
    cmd = cmd or "";
    if (cmd == "on") then
        enabled = true;
        say("on");
    elseif (cmd == "off") then
        enabled = false;
        say("off");
    elseif (cmd == "wins" or cmd == "runs" or cmd == "history") then
        printRuns();
    elseif (cmd == "best") then
        printBest();
    elseif (cmd == "shape") then
        toggleShape();
    elseif (cmd == "reset") then
        resetPositions();
    elseif (cmd == "clear") then
        AZSSageDB.runs = {};
        histCache = {};
        say("run history cleared");
    elseif (cmd == "bar") then
        -- Spell-bar ground truth: what the client exposes per action slot.
        for slot = 1, 12 do
            local btn = getglobal("ActionButton" .. slot);
            local ok, has, txt, cs, cd = pcall(function()
                return HasAction(slot), GetActionText(slot), GetActionCooldown(slot);
            end);
            if (not ok) then
                say(slot .. ": API error");
            elseif (not btn) then
                say(slot .. ": no ActionButton");
            else
                local label = (has and (txt ~= "" and txt or "spell")) or "empty";
                say(slot .. ": " .. label .. " cd=" .. string.format("%.1f", cd or -1));
            end
        end
        if (AZS_SPELLS) then
            for i = 1, table.getn(AZS_SPELLS) do
                local s = AZS_SPELLS[i];
                say(i .. ". " .. (s.key or "?") .. " cdmax=" .. string.format("%.1f", s.cdmax or 0));
            end
        end
    else
        say((enabled and "on" or "off") .. " - /sage on|off|wins|best|shape|reset|clear|bar");
    end
end;
