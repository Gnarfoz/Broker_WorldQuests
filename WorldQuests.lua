
local ITEM_QUALITY_COLORS, WORLD_QUEST_QUALITY_COLORS = ITEM_QUALITY_COLORS, WORLD_QUEST_QUALITY_COLORS

local BWQ = CreateFrame("Frame", "Broker_WorldQuests", UIParent)
BWQ:SetFrameStrata("HIGH")
BWQ:EnableMouse(true)
BWQ:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground", 
		edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
		tile = false,
		tileSize = 0, 
		edgeSize = 2, 
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
BWQ:SetBackdropColor(0,0,0,.85)
BWQ:SetBackdropBorderColor(0,0,0,.75)
BWQ:Hide()

-- local Block_OnEnter = function(self)
	
-- end
local Block_OnLeave = function(self)
	if not BWQ:IsMouseOver() then
		BWQ:Hide()
	end
end

--BWQ:SetScript("OnEnter", Block_OnEnter)
BWQ:SetScript("OnLeave", Block_OnLeave)

local continentId = 8
local mapZones = {
	GetMapNameByID(1015), 1015,  -- Aszuna
	GetMapNameByID(1018), 1018,  -- Val'sharah
	GetMapNameByID(1024), 1024,  -- Highmountain
	GetMapNameByID(1017), 1017,  -- Stormheim
	GetMapNameByID(1033), 1033,  -- Suramar
}

local needsRefreshForItemUpdate = false
local buttonCache = {}
local zoneSepCache = {}

--42652 (some world quest id)

local RetrieveWorldQuests = function(mapId)

	local quests = {}

	SetMapByID(mapId)
	local questList = C_TaskQuest.GetQuestsForPlayerByMapID(mapId)
	-- quest object fields are: x, y, floor, numObjectives, questId, inProgress
	for i = 1, #questList do

		--[[
		local tagID, tagName, worldQuestType, isRare, isElite, tradeskillLineIndex = GetQuestTagInfo(v);
		
		tagId = 116
		tagName = Blacksmithing World Quest
		worldQuestType = 
			2 -> profession, 
			3 -> pve?
			4 -> pvp
			5 -> battle pet
			7 -> dungeon
		isRare = 
			1 -> normal
			2 -> rare
			3 -> epic
		isElite = true/false
		tradeskillLineIndex = some number, no idea of meaning atm
		]]
		local tagId, tagName, worldQuestType, isRare, isElite, tradeskillLineIndex = GetQuestTagInfo(questList[i].questId);
		if worldQuestType ~= nil then
			local quest = {}
			-- GetQuestsForPlayerByMapID fields
			quest.questId = questList[i].questId
			quest.numObjectives = questList[i].numObjectives

			-- GetQuestTagInfo fields
			quest.tagId = tagId
			quest.tagName = tagName
			quest.worldQuestType = worldQuestType
			quest.isRare = isRare
			quest.isElite = isElite
			quest.tradeskillLineIndex = tradeskillLineIndex

			local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(quest.questId)
			quest.title = title
			if factionId then
				quest.faction = GetFactionInfoByID(factionId)
			end
			quest.timeLeft = C_TaskQuest.GetQuestTimeLeftMinutes(quest.questId)

			quests[#quests+1] = quest
		end
	end

	return quests
end

local FormatTimeLeftString = function(timeLeft)
	local timeLeftStr = ""
	-- if timeLeft >= 60 * 24 then -- at least 1 day
	-- 	timeLeftStr = string.format("%.0fd", timeLeft / 60 / 24)
	-- end
	if timeLeft >= 60 then -- hours
		timeLeftStr = string.format("%.0fh", timeLeft / 60)
	end
	timeLeftStr = string.format("%s%s%sm", timeLeftStr, timeLeftStr ~= "" and " " or "", timeLeft % 60) -- always show minutes

	if timeLeft < 180 then -- highlight less then 3 hours
		timeLeftStr = string.format("|cffe6c800%s|r", timeLeftStr)
	end
	return timeLeftStr
end

local ShowQuestObjectiveTooltip = function(row)
	GameTooltip:SetOwner(row, "ANCHOR_CURSOR", 0, -5)
	local color = WORLD_QUEST_QUALITY_COLORS[row.quest.isRare]
	GameTooltip:AddLine(row.quest.title, color.r, color.g, color.b, true)

	for objectiveIndex = 1, row.quest.numObjectives do
		local objectiveText, objectiveType, finished = GetQuestObjectiveInfo(row.questId, objectiveIndex, false);
		if ( objectiveText and #objectiveText > 0 ) then
			color = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
			GameTooltip:AddLine(QUEST_DASH .. objectiveText, color.r, color.g, color.b, true);
		end
	end

	local percent = C_TaskQuest.GetQuestProgressBarInfo(row.questId);
	if ( percent ) then
		GameTooltip_InsertFrame(GameTooltip, WorldMapTaskTooltipStatusBar);
		WorldMapTaskTooltipStatusBar.Bar:SetValue(percent);
		WorldMapTaskTooltipStatusBar.Bar.Label:SetFormattedText(PERCENTAGE_STRING, percent);
		WorldMapTaskTooltipStatusBar:SetHeight(10)
		WorldMapTaskTooltipStatusBar:SetPoint("BOTTOM", GameTooltip, "BOTTOM")
	end

	GameTooltip:Show()
end

local Row_OnClick = function(self)
	ShowUIPanel(WorldMapFrame)
	SetMapByID(self.mapId)
	SetSuperTrackedQuestID(self.questId)
end

local UpdateBlock = function()
	local originalMap = GetCurrentMapAreaID()
	local buttonIndex = 1
	local titleMaxWidth, factionMaxWidth, rewardMaxWidth, timeLeftMaxWidth = 0, 0, 0, 0
	for mapIndex = 1, #mapZones do

		if mapIndex % 2 == 1 then -- uneven are zone names, even are ids
			
			if mapIndex > #zoneSepCache then
				zoneNameFS = BWQ:CreateFontString("BWQzoneNameFS", "OVERLAY", "SystemFont_Shadow_Med1")
				zoneNameFS:SetJustifyH("LEFT")
				zoneNameFS:SetTextColor(.9, .8, 0)
				zoneSepCache[mapIndex] = zoneNameFS

				local zoneSep = BWQ:CreateTexture()
				zoneSep:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
				zoneSep:SetHeight(8)
				zoneSepCache[mapIndex+1] = zoneSep
			end

		else

			local quests = RetrieveWorldQuests(mapZones[mapIndex])

			local firstRowInZone = true
			if mapIndex == 2 then
				zoneSepCache[mapIndex-1]:SetPoint("TOP", BWQ, "TOP", 10, -10)
				zoneSepCache[mapIndex]:SetPoint("TOP", BWQ, "TOP", 0, -13)
			else
				zoneSepCache[mapIndex-1]:SetPoint("TOP", buttonCache[buttonIndex-1], "BOTTOM", 0, -5)
				zoneSepCache[mapIndex]:SetPoint("TOP", buttonCache[buttonIndex-1], "BOTTOM", 0, -8)
			end
			zoneSepCache[mapIndex-1]:SetText(mapZones[mapIndex-1])

			for questIndex = 1, #quests do

				local button
				if buttonIndex > #buttonCache then

					button = CreateFrame("Button", nil, BWQ)
					button:RegisterForClicks("AnyUp")

					button.highlight = button:CreateTexture()
					button.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
					button.highlight:SetBlendMode("ADD")
					button.highlight:SetAlpha(0)
					button.highlight:SetAllPoints(button)

					button:SetScript("OnLeave", function(self)
						Block_OnLeave()
						self.highlight:SetAlpha(0)
						GameTooltip:Hide()
					end)
					button:SetScript("OnEnter", function(self)
						self.highlight:SetAlpha(1)
						ShowQuestObjectiveTooltip(self)
					end)

					button:SetScript("OnClick", Row_OnClick)


					-- create font strings
					button.titleFS = button:CreateFontString("BWQtitleFS", "OVERLAY", "SystemFont_Shadow_Med1")
					button.titleFS:SetJustifyH("LEFT")
					button.titleFS:SetTextColor(1, 1, 1)
					button.titleFS:SetWordWrap(false)

					button.factionFS = button:CreateFontString("BWQfactionFS", "OVERLAY", "SystemFont_Shadow_Med1")
					button.factionFS:SetJustifyH("LEFT")
					button.factionFS:SetTextColor(1, 1, 1)

					button.reward = CreateFrame("Button", nil, button)
					button.reward:SetScript("OnClick", Row_OnClick)

					button.rewardFS = button.reward:CreateFontString("BWQrewardFS", "OVERLAY", "SystemFont_Shadow_Med1")
					button.rewardFS:SetJustifyH("LEFT")
					button.rewardFS:SetTextColor(1, 1, 1)

					button.timeLeftFS = button:CreateFontString("BWQtimeLeftFS", "OVERLAY", "SystemFont_Shadow_Med1")
					button.timeLeftFS:SetJustifyH("LEFT")
					button.timeLeftFS:SetTextColor(1, 1, 1)

					buttonCache[buttonIndex] = button
				else
					button = buttonCache[buttonIndex]
				end

				-- set data for button (this is messy :( maybe improve this later? values needed in click listeners on self)
				button.mapId = mapZones[mapIndex]
				button.reward.mapId = button.mapId
				button.quest = quests[questIndex]
				button.reward.questId = button.quest.questId
				button.questId = button.quest.questId

				
				if firstRowInZone then
					button:SetPoint("TOP", zoneSepCache[mapIndex-1], "BOTTOM", 0, -5)
				else
					button:SetPoint("TOP", buttonCache[buttonIndex-1], "BOTTOM", 0, 0)
				end
				firstRowInZone = false
				
				button.titleFS:SetText(string.format("%s%s%s|r", button.quest.isElite and "|cffe6c800ELITE |r" or "", WORLD_QUEST_QUALITY_COLORS[button.quest.isRare].hex, button.quest.title))
				local titleWidth = button.titleFS:GetStringWidth()
				if titleWidth > titleMaxWidth then titleMaxWidth = titleWidth end

				button.factionFS:SetText(button.quest.faction)
				local factionWidth = button.factionFS:GetStringWidth()
				if factionWidth > factionMaxWidth then factionMaxWidth = factionWidth end

				button.timeLeftFS:SetText(FormatTimeLeftString(button.quest.timeLeft))
				local timeLeftWidth = button.factionFS:GetStringWidth()
				if timeLeftWidth > timeLeftMaxWidth then timeLeftMaxWidth = timeLeftWidth end


				local rewardText = ""
				if GetNumQuestLogRewards(button.quest.questId) > 0 then
					local itemName, itemTexture, quantity, quality, isUsable, itemId = GetQuestLogRewardInfo(1, button.quest.questId)
					if itemName then
						button.reward.itemName = itemName
						button.reward.itemTexture = itemTexture
						button.reward.itemId = itemId
						button.reward.itemQuality = quality
						button.reward.itemQuantity = quantity
					
						rewardText = string.format(
							"|T%s$s:14:14|t %s[%s]\124r%s",
							button.reward.itemTexture,
							ITEM_QUALITY_COLORS[button.reward.itemQuality].hex,
							button.reward.itemName,
							button.reward.itemQuantity > 1 and " x" .. button.reward.itemQuantity or ""
						)

						button.reward:SetScript("OnEnter", function(self)
							button.highlight:SetAlpha(1)

							GameTooltip:SetOwner(self, "ANCHOR_CURSOR", 0, -5)
							GameTooltip:SetQuestLogItem("reward", 1, self.questId)
							--GameTooltip:SetHyperlink(string.format("item:%d:0:0:0:0:0:0:0", self.itemId))
							GameTooltip:Show()
						end)

						button.reward:SetScript("OnLeave", function(self)
							button.highlight:SetAlpha(0)

							GameTooltip:Hide()
							Block_OnLeave()
						end)

					else
						needsRefreshForItemUpdate = true
					end
				else
					button.reward:SetScript("OnEnter", function(self)
						ShowQuestObjectiveTooltip(button)
					end)
					button.reward:SetScript("OnLeave", function(self)
						GameTooltip:Hide()
						Block_OnLeave()
					end)
				end

				local money = GetQuestLogRewardMoney(button.quest.questId);
				if money > 0 then
					local moneyText = GetCoinTextureString(money)

					rewardText = string.format(
						"%s%s%s",
						rewardText,
						rewardText ~= "" and "   " or "", -- insert some space between rewards
						moneyText
					)
				end

				local numQuestCurrencies = GetNumQuestLogRewardCurrencies(button.quest.questId)
				for i = 1, numQuestCurrencies do
					local name, texture, numItems = GetQuestLogRewardCurrencyInfo(i, button.quest.questId)
					local currencyText = string.format(
						"|T%1$s:14:14|t %2$d %3$s",
						texture,
						numItems,
						name
					)

					rewardText = string.format(
						"%s%s%s",
						rewardText,
						rewardText ~= "" and "   " or "", -- insert some space between rewards
						currencyText
					)
				end


				button.rewardFS:SetText(rewardText)

				local rewardWidth = button.rewardFS:GetStringWidth()
				if rewardWidth > rewardMaxWidth then rewardMaxWidth = rewardWidth end
				button.reward:SetHeight(button.rewardFS:GetStringHeight())
				button.reward:SetWidth(button.rewardFS:GetStringWidth())

				button.titleFS:SetPoint("LEFT", button, "LEFT", 0, 0)
				button.factionFS:SetPoint("LEFT", button.titleFS, "RIGHT", 10, 0)
				button.rewardFS:SetPoint("LEFT", button.factionFS, "RIGHT", 10, 0)
				button.reward:SetPoint("LEFT", button.rewardFS, "LEFT", 0, 0)
				button.timeLeftFS:SetPoint("LEFT", button.rewardFS, "RIGHT", 10, 0)

				buttonCache[buttonIndex] = button -- save all changes back into the array of buttons

				buttonIndex = buttonIndex + 1

			end -- quest loop
		end -- mapzone/id if
	end -- maps loop
	
	titleMaxWidth = titleMaxWidth > 250 and 250 or titleMaxWidth
	for i = 1, (buttonIndex - 1) do
		buttonCache[i]:SetHeight(15)
		buttonCache[i]:SetWidth(titleMaxWidth + factionMaxWidth + rewardMaxWidth + timeLeftMaxWidth)
		buttonCache[i].titleFS:SetWidth(titleMaxWidth)
		buttonCache[i].factionFS:SetWidth(factionMaxWidth)
		buttonCache[i].reward:SetWidth(rewardMaxWidth)
		buttonCache[i].rewardFS:SetWidth(rewardMaxWidth)
		buttonCache[i].timeLeftFS:SetWidth(timeLeftMaxWidth)
	end

	local totalWidth = titleMaxWidth + factionMaxWidth + rewardMaxWidth + timeLeftMaxWidth + 10
	for i = 1, #mapZones do
		zoneSepCache[i]:SetWidth(totalWidth)
	end

	BWQ:SetWidth(totalWidth)
	BWQ:SetHeight((buttonIndex - 1) * 15 + ((#mapZones / 2) * 20) + 25)

	SetMapByID(originalMap) -- set map back to original map before updating
end

--BWQ:RegisterEvent("GET_ITEM_INFO_RECEIVED")
BWQ:RegisterEvent("QUEST_LOG_UPDATE")
BWQ:SetScript("OnEvent", function(self, event)
	UpdateBlock()
end)

-- data broker object
local ldb = LibStub("LibDataBroker-1.1")
BWQ.WorldQuestsBroker = ldb:NewDataObject("WorldQuests", {
	type = "launcher",
	label = "World Quests",
	icon = nil,
	OnEnter = function(self)
		BWQ:SetPoint("TOP", self, "BOTTOM", 0, 0)
		BWQ:Show()
	end,
	OnLeave = Block_OnLeave,
	OnClick = function(self, button)
		UpdateBlock()
	end,
})