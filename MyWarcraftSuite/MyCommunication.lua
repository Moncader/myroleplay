-- MyCommunication v0.9


-- Timeout for joining channels; if we haven't already joined a channel by the time this many seconds
-- has elapsed, force joining them anyway (in case of /console reloadui or having no zonechannels open)
-- NOTE: Addon communication channels may appear as \1 if this timeout is too low (if your computer
--       takes >60 sec to enter the world from when you hit Enter World, you may wish to increase it).
MCO_JOIN_CHANNEL_TIMEOUT = 60;

-- The minimum amount of time in seconds between sending subsequent messages on any given channel, 
-- to prevent chatflooding.
MCO_MESSAGE_TIMER = 0.2;

-- The minimum amount of time in seconds between sending ANY messages AT ALL, to prevent chatflooding.
-- If this timer is higher than MCO_MESSAGE_TIMER (as it currently is by default), this takes precedence.
-- Experimentally set to a very low 2 per second, to counteract a Blizzard issue with the handling of 
-- chat throttling in moderated channels.
MCO_MESSAGE_TIMER_GLOBAL = 0.5;

----------------------------------------------------------------------------------------------------------
--			LOCALE										--
----------------------------------------------------------------------------------------------------------
if (GetLocale() == "enUS") then
	MCO_LOCALE_MYTIME_MISSING_ERROR				= "ERROR: MyTime addon missing.";
	MCO_LOCALE_FREE_CHANNEL_ERROR				= "Please free a channel if you would like to join ";
	MCO_LOCALE_CHANNEL_INITIALIZED				= " Channel Initialized.";
	MCO_LOCALE_DATAID_MISSING_ERROR				= "ERROR: Data Id is missing in function mcoSendMessage.";
	MCO_LOCALE_CHANNELNAME_TOOLONG_ERROR			= "Cannot join a channel with more than 12 characters.";
	MCO_LOCALE_DATA_MISSING_ERROR				= "ERROR: Data is missing in function mcoSendMessage.";
	MCO_LOCALE_CHANNEL_DOESNOT_EXIST_ERROR			= "ERROR: The following channel does not exist. ";
	MCO_LOCALE_JOIN_CHANNEL_TIMEOUT				= "Now joining communication channels (forced, client took more than " .. tostring(MCO_JOIN_CHANNEL_TIMEOUT) .. "s to join any channels - if this isn't a reloadui, consider increasing MCO_JOIN_CHANNEL_TIMEOUT).";
	--MCO_LOCALE_DATA_MISSING_ERROR				= "ERROR: Data is missing in function mcoSendMessage.";
	--MCO_LOCALE_DATA_MISSING_ERROR				= "ERROR: Data is missing in function mcoSendMessage.";
	--MCO_LOCALE_DATA_MISSING_ERROR				= "ERROR: Data is missing in function mcoSendMessage.";
	--MCO_LOCALE_DATA_MISSING_ERROR				= "ERROR: Data is missing in function mcoSendMessage.";
else
	MCO_LOCALE_MYTIME_MISSING_ERROR				= "ERROR: MyTime addon missing.";
	MCO_LOCALE_FREE_CHANNEL_ERROR				= "Please free a channel if you would like to join ";
	MCO_LOCALE_CHANNEL_INITIALIZED				= " Channel Initialized.";
	MCO_LOCALE_DATAID_MISSING_ERROR				= "ERROR: Data Id is missing in function mcoSendMessage.";
	MCO_LOCALE_CHANNELNAME_TOOLONG_ERROR			= "Cannot join a channel with more than 12 characters.";
	MCO_LOCALE_DATA_MISSING_ERROR				= "ERROR: Data is missing in function mcoSendMessage.";
	MCO_LOCALE_CHANNEL_DOESNOT_EXIST_ERROR			= "ERROR: The following channel does not exist. ";
	MCO_LOCALE_JOIN_CHANNEL_TIMEOUT				= "Now joining communication channels (forced, client took more than " .. tostring(MCO_JOIN_CHANNEL_TIMEOUT) .. "s to join any channels - if this isn't a reloadui, consider increasing MCO_JOIN_CHANNEL_TIMEOUT).";
end


----------------------------------------------------------------------------------------------------------
--			HEADER										--
----------------------------------------------------------------------------------------------------------
MCO_NAME = "MyCommunications";
MCO_VERSION = 0.92;

MyCommunication = {};
MyCommunication.System = {};
MyCommunication.System.Channels = {};

mcoJoinedChannelList = {};

mcoMessagesToSend = {};

mcoEventList = {};

MCO_DATA_TYPE_NIL = 0;
MCO_DATA_TYPE_STRING = 1;
MCO_DATA_TYPE_NUMBER = 2;
MCO_DATA_TYPE_TABLE = 3;
MCO_DATA_TYPE_FUNCTION = 4;
MCO_DATA_TYPE_BOOLEAN = 5;

MCO_NEWLINE_CHARACTER = "\r";
--MCO_ZERO_CHARACTER = string.char(1, 2, 4);
MCO_BACKSLASH_CHARACTER = string.char(2);
--MCO_PERCENT_CHARACTER = string.char(1, 2, 2, 2, 4);
MCO_BAR_CHARACTER = string.char(1);
MCO_H_CHARACTER = string.char(3);
MCO_DOTDOTDOT_CHARACTER = string.char(4);

mcoAbleToSendData = {};
mcoChannelTimerId = {};
mcoStartupChannelList = {};
---------------------------------------------------------
--			FUNCTIONS                       --
----------------------------------------------------------

function mcoGlobalTimerEnable()
	if (mtiGetTimerTime(mcoGlobalTimer.id) >= MCO_MESSAGE_TIMER_GLOBAL) then
		mcoGlobalTimer.isAble = true;
	end
end

-- A global timer to prevent chat throttling. Across ALL channels. Yes. Even /say.
function mcoBeginGlobalTimer()
	if (not mcoGlobalTimer or mcoGlobalTimer == nil) then
		mcoGlobalTimer = {};
		mcoGlobalTimer.id = mtiCreateNewTimer(1, .1, mcoGlobalTimerEnable);
	else
		mtiResetTimer(mcoGlobalTimer.id);
	end
	mtiStartTimer(mcoGlobalTimer.id);
	mcoGlobalTimer.isAble = false;
end

-- Hooks literally every single Chat message sent by anything. I'm so sorry - but needs must.
-- We have to reset our timer every time we send something to any channel that affects the
-- global chat throttle. The following as of 28th October 2007 are (apparently) not affected *by* the
-- throttle, but do still affect its timer:
-- PARTY, RAID, GUILD, and CHANNEL if <= 25 people in it (but how are we to know that?)
function mcoHooked_SendChatMessage(msg, chatType, language, channel)
	mcoBeginGlobalTimer();
	return mcoBlizzard_SendChatMessage(msg, chatType, language, channel);
end


function mcoOnLoad()
	ChatTypeInfo["CHANNEL"].sticky = 1; -- EM: As much as I like sticky channels, should we really be doing this in MRP?

	if (not MTI_VERSION) then
		mduDisplayMessage(MCO_LOCALE_MYTIME_MISSING_ERROR, MCO_NAME, .8, .8, 0, 1, 0, 0);
	end

	--[[this:RegisterEvent("CHAT_MSG_CHANNEL");
	this:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE");
	this:RegisterEvent("CHAT_MSG_CHANNEL_JOIN");
	this:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE");
	this:RegisterEvent("CHAT_MSG_CHANNEL_LIST");
	this:RegisterEvent("CHAT_MSG_EMOTE");
	this:RegisterEvent("CHAT_MSG_GUILD");
	this:RegisterEvent("CHAT_MSG_OFFICER");
	this:RegisterEvent("CHAT_MSG_PARTY");
	this:RegisterEvent("CHAT_MSG_RAID");
	this:RegisterEvent("CHAT_MSG_RAID_LEADER");
	this:RegisterEvent("CHAT_MSG_RAID_WARNING");
	this:RegisterEvent("CHAT_MSG_SAY");
	this:RegisterEvent("CHAT_MSG_SYSTEM");
	this:RegisterEvent("CHAT_MSG_TEXT_EMOTE");
	this:RegisterEvent("CHAT_MSG_WHISPER");
	this:RegisterEvent("CHAT_MSG_WHISPER_INFORM");
	this:RegisterEvent("CHAT_MSG_YELL");
	this:RegisterEvent("CHAT_MSG_TEXT_EMOTE");]]

	--mcoJoinChannelId = mtiRegisterEvent(10, mcoJoinChannel, false);
	--mcoJoinChannelWatcherId = mtiRegisterEvent(1, mcoJoinChannelWatcher, false, "CHAT_MSG_CHANNEL_NOTICE");
	mcoRegisterEvent("MCO_CHANNEL_JOINED", mcoChannelJoined);
	mcoRegisterEvent("CHAT_MSG_CHANNEL", mcoRecieveMessage);

	mtiRegisterEvent(0, mcoTransmitData);

	--mcoRegisterAddonStartupChannel("MyWarcraftComm", "MyRolePlay", "sub2", "sub3");

	--mcoRegisterChannel("MyWarcraftComm", "MyRolePlay", "sub2", "sub3");
	--mcoRegisterDataId(7, mcoTest, "MyWarcraftComm", "MyRolePlay", "sub2");
	
	-- EM: Hi, I'm the world's dirtiest hook. If something breaks, it was probably me.
	-- WTB a less horrific way of doing this, but until then, if it works...
	mcoBeginGlobalTimer();
	if (not mcoBlizzard_SendChatMessage) then
		mcoBlizzard_SendChatMessage = SendChatMessage;
		SendChatMessage = mcoHooked_SendChatMessage;
	end
end

function mcoChannelJoined(arg1)
	mduDisplayMessage(arg1 .. MCO_LOCALE_CHANNEL_INITIALIZED, MCO_NAME, .8, .8, 0, 1, 0, 0);
	mcoBeginTimer(nil, nil, nil, nil, nil, nil, nil, nil, arg1);
end

function mcoRegisterAddonStartupChannel(masterChannel, subChannelOne, subChannelTwo, subChannelThree)
	local newSize = table.maxn(mcoStartupChannelList) + 1;

	table.insert(mcoStartupChannelList, newSize, {});
	mcoStartupChannelList[newSize].masterChannel = masterChannel;
	mcoStartupChannelList[newSize].subChannelOne = subChannelOne;
	mcoStartupChannelList[newSize].subChannelTwo = subChannelTwo;
	mcoStartupChannelList[newSize].subChannelThree = subChannelThree;

	mcoJoinChannelId = mtiRegisterEvent(MCO_JOIN_CHANNEL_TIMEOUT, mcoJoinChannel, false);
	mcoJoinChannelWatcherId = mtiRegisterEvent(0, mcoJoinChannelWatcher, false, "CHAT_MSG_CHANNEL_NOTICE");
end

-- Normal initialisation for addon-startup channels (fires when we join any other channel for the first time, e.g., /1)
function mcoJoinChannelWatcher()
	if (arg1 == "YOU_JOINED") then
		for i = 1, table.maxn(mcoStartupChannelList) do
			mcoRegisterChannel(mcoStartupChannelList[i].masterChannel, mcoStartupChannelList[i].subChannelOne, mcoStartupChannelList[i].subChannelTwo, mcoStartupChannelList[i].subChannelThree);
		end

		mtiUnregisterEvent(mcoJoinChannelId);
		mtiUnregisterEvent(mcoJoinChannelWatcherId);
	end
end

-- Emergency initialisation for addon-startup channels - fires after MCO_JOIN_CHANNEL_TIMEOUT if the normal one doesn't first
function mcoJoinChannel()
	-- EM: UnitOnTaxi fix - if player's on taxi, extend timeout (or until we land and join and JoinChannelWatcher fires).
	if (UnitOnTaxi("player")) then
		mtiUnregisterEvent(mcoJoinChannelId);
		mcoJoinChannelId = mtiRegisterEvent(5, mcoJoinChannel, false);				-- Check again in 5s
		return;
	end
	
	-- EM: Cinematic fix - during opening cinematic, extend timeout by 20s (or until it finishes and we join channels).
	if (InCinematic()) then
		mtiUnregisterEvent(mcoJoinChannelId);
		mcoJoinChannelId = mtiRegisterEvent(20, mcoJoinChannel, false);				-- Check again in 20s
		return;
	end
	
	-- Tell the user we're doing an emergency join.
	mduDisplayMessage(MCO_LOCALE_JOIN_CHANNEL_TIMEOUT, MCO_NAME, .8, .8, 0, 1, 0, 0);
	
	for i = 1, table.maxn(mcoStartupChannelList) do
		mcoRegisterChannel(mcoStartupChannelList[i].masterChannel, mcoStartupChannelList[i].subChannelOne, mcoStartupChannelList[i].subChannelTwo, mcoStartupChannelList[i].subChannelThree);
	end

	mtiUnregisterEvent(mcoJoinChannelId);
	mtiUnregisterEvent(mcoJoinChannelWatcherId);
end

function mcoRegisterEvent(event, eventFunction)
	if (not mcoEventList[event]) then
		table.insert(mcoEventList, event);
		mcoEventList[event] = {};
		mcoEventList[event].eventFunctions = {};
		mcoManager:RegisterEvent(event);
	end

	table.insert(mcoEventList[event].eventFunctions, table.maxn(mcoEventList[event].eventFunctions) + 1);
	mcoEventList[event].eventFunctions[table.maxn(mcoEventList[event].eventFunctions)] = eventFunction;
end

function mcoUnregisterEvent(event, eventFunction)
	for i, eventFunctionToTest in ipairs(mcoEventList[event].eventFunctions) do
		if (eventFunctionToTest == eventFunction) then
			table.remove(mcoEventList[event].eventFunctions, i);

			for j, eventName in ipairs(mcoEventList) do
				if (eventName == event and table.maxn(mcoEventList[event].eventFunctions) == 0) then
					table.remove(mcoEventList, j);
					mcoManager:UnregisterEvent(event);
				end
			end

			return;
		end
	end
end

function mcoOnEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	for i, eventFunction in ipairs(mcoEventList) do
		if (event == eventFunction) then
			for j = 1, table.maxn(mcoEventList[event].eventFunctions) do
				mcoEventList[event].eventFunctions[j](arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9);
			end
		end
	end
end

function mcoRegisterChannel(masterChannel, subChannelOne, subChannelTwo, subChannelThree)
	if ((subChannelOne and string.len(subChannelOne) > 12) or (subChannelTwo and string.len(subChannelTwo) > 12) or (subChannelThree and string.len(subChannelThree) > 12)) then
		mduDisplayMessage(MCO_LOCALE_CHANNELNAME_TOOLONG_ERROR, MCO_NAME, .8, .8, 0, 1, 0, 0);
		return;
	end

	if (GetChannelName(masterChannel) == 0) then
		local index = JoinChannelByName(masterChannel, MDU_EMPTY_STRING, nil);

		if (index == nil) then
			mduDisplayMessage(MCO_LOCALE_FREE_CHANNEL_ERROR .. masterChannel .. ".", MCO_NAME, .8, .8, 0, 1, 0, 0);
		end
	end

	if (GetChannelName(masterChannel) > 0) then
		if (not mcoJoinedChannelList[masterChannel] or mcoJoinedChannelList[masterChannel] == nil) then
			table.insert(mcoJoinedChannelList, masterChannel);
			mcoJoinedChannelList[masterChannel] = {};
			mcoJoinedChannelList[masterChannel].DataId = {};
		end

		if (subChannelOne) then
			if (not mcoJoinedChannelList[masterChannel][subChannelOne]) then
				table.insert(mcoJoinedChannelList[masterChannel], subChannelOne);
				mcoJoinedChannelList[masterChannel][subChannelOne] = {};
				mcoJoinedChannelList[masterChannel][subChannelOne].DataId = {};
			end

			if (subChannelTwo) then
				if (not mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo]) then
					table.insert(mcoJoinedChannelList[masterChannel][subChannelOne], subChannelTwo);
					mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo] = {};
					mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo].DataId = {};
				end

				if (subChannelThree) then
					if (not mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo][subChannelThree]) then
						table.insert(mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo], subChannelThree);
						mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo][subChannelThree] = {};
						mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo][subChannelThree].DataId = {};
					end
				end
			end
		end

		mcoOnEvent("MCO_CHANNEL_JOINED", masterChannel);
		mduSendEvent("MCO_CHANNEL_JOINED", masterChannel, subChannelOne, subChannelTwo, subChannelThree);
	end
end

function mcoUnregisterChannel(masterChannel, subChannelOne, subChannelTwo, subChannelThree)
	if (mcoJoinedChannelList[masterChannel] or mcoJoinedChannelList[masterChannel] ~= nil) then
		if (subChannelOne and (mcoJoinedChannelList[masterChannel][subChannelOne] or mcoJoinedChannelList[masterChannel][subChannelOne] ~= nil)) then
			if (subChannelTwo and (mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo] or mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo] ~= nil)) then
				if (subChannelThree and (mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo][subChannelThree] or mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo][subChannelThree] ~= nil)) then
					local index = mduGetIndexOfTable(mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo], subChannelThree);
					table.remove(mcoJoinedChannelList[masterChannel][subChannelOne][subChannelTwo], index);
					mduSendEvent("MCO_CHANNEL_UNREGISTERED", masterChannel, subChannelOne, subChannelTwo, subChannelThree);

					return;
				end

				local index = mduGetIndexOfTable(mcoJoinedChannelList[masterChannel][subChannelOne], subChannelTwo);
				table.remove(mcoJoinedChannelList[masterChannel][subChannelOne], index);
				mduSendEvent("MCO_CHANNEL_UNREGISTERED", masterChannel, subChannelOne, subChannelTwo);

				return;
			end

			local index = mduGetIndexOfTable(mcoJoinedChannelList[masterChannel], subChannelOne);
			table.remove(mcoJoinedChannelList[masterChannel], index);
			mduSendEvent("MCO_CHANNEL_UNREGISTERED", masterChannel, subChannelOne);

			return;
		end

		local index = mduGetIndexOfTable(mcoJoinedChannelList, masterChannel);
		table.remove(mcoJoinedChannelList, index);
		LeaveChannelByName(masterChannel);
		mduSendEvent("MCO_CHANNEL_UNREGISTERED", masterChannel);

		return;
	end
end

function mcoListChannelByName(channelName, subChannelOne, subChannelTwo, subChannelThree)

end

function mcoRegisterDataId(dataId, dataIdFunction, masterChannel, subChannelOne, subChannelTwo, subChannelThree)
	dataId = tonumber(dataId);

	for i, channelLevelZero in ipairs(mcoJoinedChannelList) do
		if (masterChannel == channelLevelZero) then
			if (subChannelOne) then
				for j, channelLevelOne in ipairs(mcoJoinedChannelList[channelLevelZero]) do
					if (subChannelOne == channelLevelOne) then
						if (subChannelTwo) then
							for j, channelLevelTwo in ipairs(mcoJoinedChannelList[channelLevelZero][channelLevelOne]) do
								if (subChannelTwo == channelLevelTwo) then
									if (subChannelThree) then
										for j, channelLevelThree in ipairs(mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo]) do
											if (subChannelThree == channelLevelThree) then
												table.insert(mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo][channelLevelThree].DataId, dataId);
												mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo][channelLevelThree].DataId[dataId] = {};
												mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo][channelLevelThree].DataId[dataId].dataIdFunction = dataIdFunction;

												return;
											end
										end
									end

									table.insert(mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo].DataId, dataId);
									mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo].DataId[dataId] = {};
									mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo].DataId[dataId].dataIdFunction = dataIdFunction;

									return;
								end
							end
						end

						table.insert(mcoJoinedChannelList[channelLevelZero][channelLevelOne].DataId, dataId);
						mcoJoinedChannelList[channelLevelZero][channelLevelOne].DataId[dataId] = {};
						mcoJoinedChannelList[channelLevelZero][channelLevelOne].DataId[dataId].dataIdFunction = dataIdFunction;

						return;
					end
				end
			end

			table.insert(mcoJoinedChannelList[channelLevelZero].DataId, dataId);
			mcoJoinedChannelList[channelLevelZero].DataId[dataId] = {};
			mcoJoinedChannelList[channelLevelZero].DataId[dataId].dataIdFunction = dataIdFunction;

			return;
		end
	end
end

function mcoUnregisterDataId(dataId, masterChannel, subChannelOne, subChannelTwo, subChannelThree)

end

function mcoSendMessage(data, masterChannel, subChannelOne, subChannelTwo, subChannelThree, dataId, target)
	if (data == nil) then
		mduDisplayMessage(MCO_LOCALE_DATA_MISSING_ERROR, MCO_NAME, .8, .8, 0, 1, 0, 0);
		return;
	end

	if (dataId == nil) then
		mduDisplayMessage(MCO_LOCALE_DATAID_MISSING_ERROR, MCO_NAME, .8, .8, 0, 1, 0, 0);
		return;
	end

	if (subChannelOne == nil) then
		subChannelOne = "0";
	end

	if (subChannelTwo == nil) then
		subChannelTwo = "0";
	end

	if (subChannelThree == nil) then
		subChannelThree = "0";
	end

	if (target == nil) then
		target = "0";
	end

	local dataType = type(data);
	local dataTypeIndex = MCO_DATA_TYPE_NIL;

	if (dataType == "string") then
		dataTypeIndex = MCO_DATA_TYPE_STRING;
	end

	if (dataType == "number") then
		dataTypeIndex = MCO_DATA_TYPE_NUMBER;
	end

	if (dataType == "table") then
		dataTypeIndex = MCO_DATA_TYPE_TABLE;
	end

	if (dataType == "function") then
		dataTypeIndex = MCO_DATA_TYPE_FUNCTION;
	end

	if (dataType == "boolean") then
		dataTypeIndex = MCO_DATA_TYPE_BOOLEAN;
	end

	if (dataType == "nil") then
		dataTypeIndex = MCO_DATA_TYPE_NIL;
	end


	if (not mcoMessagesToSend[masterChannel]) then
		table.insert(mcoMessagesToSend, masterChannel);
		mcoMessagesToSend[masterChannel] = {};
	end

	data = mcoEncodeMessage(data);

	local dataLength = string.len(data);

	if (dataLength == 0) then
		dataLength = 1;
	end

	for i = 1, ceil(dataLength / 178) do
		local tempIndex = table.maxn(mcoMessagesToSend[masterChannel]) + 1;

		local tempData = string.sub(data, ((178 * (i - 1))) + 1, (178 * i));

		table.insert(mcoMessagesToSend[masterChannel], tempIndex);
		mcoMessagesToSend[masterChannel][tempIndex] = {};
		mcoMessagesToSend[masterChannel][tempIndex].data = tempData;
		mcoMessagesToSend[masterChannel][tempIndex].masterChannel = masterChannel;
		mcoMessagesToSend[masterChannel][tempIndex].subChannelOne = subChannelOne;
		mcoMessagesToSend[masterChannel][tempIndex].subChannelTwo = subChannelTwo;
		mcoMessagesToSend[masterChannel][tempIndex].subChannelThree = subChannelThree;
		mcoMessagesToSend[masterChannel][tempIndex].dataId = dataId;
		mcoMessagesToSend[masterChannel][tempIndex].target = target;
		mcoMessagesToSend[masterChannel][tempIndex].dataTypeIndex = dataTypeIndex;
		mcoMessagesToSend[masterChannel][tempIndex].dataLength = string.len(data);
		mcoMessagesToSend[masterChannel][tempIndex].dataVersion = i;
		mcoMessagesToSend[masterChannel][tempIndex].isHardMessage = false;
	end
end
-- /script mduDisplayMessage(gcinfo());
-- /script mduDisplayMessage(mcoAbleToSendData[3].channelName);
function mcoTransmitData()
	if ((UnitIsAFK("player") ~= 1) and (mcoGlobalTimer.isAble)) then
		for i = 1, table.maxn(mcoAbleToSendData) do
			local canContinue = true;

			if (mcoAbleToSendData[i].isAble == true) then
				if ((not mcoMessagesToSend[mcoAbleToSendData[i].channelName]) or (not mcoMessagesToSend[mcoAbleToSendData[i].channelName][1])) then
					canContinue = false;
				end

				if (canContinue == true) then
					local mcoIndexOfChannel = GetChannelName(mcoAbleToSendData[i].channelName);

					if (mcoIndexOfChannel ~= nil) then
						if (mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].isHardMessage == false) then
							SendChatMessage("<mco" .. mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].subChannelOne .. "." .. mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].subChannelTwo .. "." .. mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].subChannelThree .. ">[" .. mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].target .. "]{" .. mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].dataId .. "}:" .. mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].dataTypeIndex .. ":`" .. mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].dataLength .. "`*" .. mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].dataVersion .. "*" .. mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].data, "CHANNEL", GetDefaultLanguage("player"), mcoIndexOfChannel);
						elseif (mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].isHardMessage == true) then
							SendChatMessage(mcoMessagesToSend[mcoAbleToSendData[i].channelName][1].data, "CHANNEL", GetDefaultLanguage("player"), mcoIndexOfChannel);
						end

					else
						mduDisplayMessage(MCO_LOCALE_CHANNEL_DOESNOT_EXIST_ERROR .. mcoAbleToSendData[i].channelName, MCO_NAME, .8, .8, 0, 1, 0, 0);
					end

					table.remove(mcoMessagesToSend[mcoAbleToSendData[i].channelName], 1);
					mcoCleanMessagesToSend(mcoAbleToSendData[i].channelName);
				end

				mcoBeginTimer(nil, nil, nil, nil, nil, nil, nil, nil, mcoAbleToSendData[i].channelName);
				return -- EM: We *can't* send more than one in a cycle anymore. The global timer, remember? /cry
			end
		end
	end
end

function mcoSendHardMessage(data, channel, encodeFunction)
	if (not mcoMessagesToSend[channel]) then
		table.insert(mcoMessagesToSend, channel);
		mcoMessagesToSend[channel] = {};
	end

	if (encodeFunction ~= nil and encodeFunction ~= 0) then
		data = encodeFunction(data);

	elseif (encodeFunction == 0) then
		data = data;
	elseif (encodeFunction == nil) then
		data = mcoEncodeMessage(data);
	end

	local dataLength = string.len(data);

	for i = 1, ceil(dataLength / 255) do
		local tempIndex = table.maxn(mcoMessagesToSend[channel]) + 1;

		local tempData = string.sub(data, ((255 * (i - 1))) + 1, (255 * i));

		table.insert(mcoMessagesToSend[channel], tempIndex);
		mcoMessagesToSend[channel][tempIndex] = {};
		mcoMessagesToSend[channel][tempIndex].data = tempData;
		mcoMessagesToSend[channel][tempIndex].masterChannel = channel;
		mcoMessagesToSend[channel][tempIndex].dataLength = string.len(data);
		mcoMessagesToSend[channel][tempIndex].dataVersion = i;
		mcoMessagesToSend[channel][tempIndex].isHardMessage = true;
	end
end

function mcoCleanMessagesToSend(channelName)
	for i, indexName in ipairs(mcoMessagesToSend) do
		if (indexName == channelName and table.maxn(mcoMessagesToSend[channelName]) == 0) then
			table.remove(mcoMessagesToSend, i);
		end
	end
end

function mcoRecieveMessage(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	local masterChannel = arg9;

	mcoBeginTimer(nil, nil, nil, nil, nil, nil, nil, nil, arg9);

	for i, channelLevelZero in ipairs(mcoJoinedChannelList) do
		if (channelLevelZero == masterChannel) then
			local subChannelOne, subChannelTwo, subChannelThree, target, dataId, dataType, dataLength, dataVersion, data = string.match(arg1, "<mco([^%.]+)%.([^%.]+)%.([^>]+)>%[([^%]]+)%]{(%d+)}:(%d+):`(%d+)`%*(%d+)%*(.*)");

			if (subChannelOne == nil) then
				return;
			end

			dataLength = tonumber(dataLength);
			dataVersion = tonumber(dataVersion);
			dataId = tonumber(dataId);

			data = mcoDecodeMessage(data);
			data = mcoConvertData(data, tonumber(dataType));

			if (subChannelOne ~= "0") then
				for j, channelLevelOne in ipairs(mcoJoinedChannelList[channelLevelZero]) do
					if (subChannelOne == channelLevelOne) then
						if (subChannelTwo ~= "0") then
							for j, channelLevelTwo in ipairs(mcoJoinedChannelList[channelLevelZero][channelLevelOne]) do
								if (subChannelTwo == channelLevelTwo) then
									if (subChannelThree ~= "0") then
										for j, channelLevelThree in ipairs(mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo]) do
											if (subChannelThree == channelLevelThree) then
												if (mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo][channelLevelThree].DataId[dataId]) then
													mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo][channelLevelThree].DataId[dataId].dataIdFunction(data, dataVersion, dataLength, target, arg2);
												end

												return;
											end
										end
									end

									if (mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo].DataId[dataId]) then
										mcoJoinedChannelList[channelLevelZero][channelLevelOne][channelLevelTwo].DataId[dataId].dataIdFunction(data, dataVersion, dataLength, target, arg2);
									end

									return;
								end
							end
						end

						if (mcoJoinedChannelList[channelLevelZero][channelLevelOne].DataId[dataId]) then
							mcoJoinedChannelList[channelLevelZero][channelLevelOne].DataId[dataId].dataIdFunction(data, dataVersion, dataLength, target, arg2);
						end

						return;
					end
				end
			end

			if (mcoJoinedChannelList[channelLevelZero].DataId[dataId]) then
				mcoJoinedChannelList[channelLevelZero].DataId[dataId].dataIdFunction(data, dataVersion, dataLength, target, arg2);
			end

			return;
		end
	end
end

function mcoConvertData(data, dataType)
	if (dataType == MCO_DATA_TYPE_NIL) then
		return (nil);
	end

	if (dataType == MCO_DATA_TYPE_STRING) then
		return (tostring(data));
	end

	if (dataType == MCO_DATA_TYPE_NUMBER) then
		return (tonumber(data));
	end

	if (dataType == MCO_DATA_TYPE_TABLE) then
		return (data);
	end

	if (dataType == MCO_DATA_TYPE_FUNCTION) then
		return (data);
	end

	if (dataType == MCO_DATA_TYPE_BOOLEAN) then
		if (data == "0" or data == "false") then
			return (false);
		end

		if (data >= "1" or data == "true") then
			return (true);
		end
	end
end

function mcoEncodeMessage(data)
	data = string.gsub(data, "\n", MCO_NEWLINE_CHARACTER);
	--data = string.gsub(data, "%%", MCO_PERCENT_CHARACTER);
	--data = string.gsub(data, "\0", MCO_ZERO_CHARACTER);
	data = string.gsub(data, "|", MCO_BAR_CHARACTER);
	data = string.gsub(data, "\\", MCO_BACKSLASH_CHARACTER);
	data = string.gsub(data, "%.%.%.hic!", MCO_DOTDOTDOT_CHARACTER);
	data = string.gsub(data, "h", MCO_H_CHARACTER);

	return (data);
end

function mcoDecodeMessage(data)
	--data = string.gsub(data, MCO_PERCENT_CHARACTER, "%%");
	--data = string.gsub(data, MCO_ZERO_CHARACTER, "\0");
	data = string.gsub(data, MCO_BAR_CHARACTER, "|");
	data = string.gsub(data, MCO_BACKSLASH_CHARACTER, "\\");
	data = string.gsub(data, "sh", "s");
	data = string.gsub(data, "Sh", "S");
	data = string.gsub(data, MCO_H_CHARACTER, "h");
	data = string.gsub(data, "%.%.%.hic!", "");
	data = string.gsub(data, MCO_DOTDOTDOT_CHARACTER, "...hic!");


	return (data);
end

function mcoChannelTimerEnable(_, _, _, _, _, _, _, _, arg9)
	for i = 1, table.maxn(mcoChannelTimerId) do
		if (mtiGetTimerTime(mcoChannelTimerId[i].id) >= MCO_MESSAGE_TIMER) then
			mcoAbleToSendData[mcoGetIndexOfAbleToSend(mcoChannelTimerId[i].channelName)].isAble = true;
		end
	end
end

function mcoBeginTimer(_, _, _, _, _, _, _, _, channelName)
	local index = mcoGetIndexOfChannelTimer(channelName);
	local ableToSendIndex = mcoGetIndexOfAbleToSend(channelName);

	if (not index or index == nil) then
		local newSize = table.maxn(mcoChannelTimerId) + 1;

		table.insert(mcoChannelTimerId, newSize, {});
		mcoChannelTimerId[newSize].id = mtiCreateNewTimer(1, .1, mcoChannelTimerEnable);
		mcoChannelTimerId[newSize].channelName = channelName;

		mtiStartTimer(mcoChannelTimerId[newSize].id);

		if (not ableToSendIndex or ableToSendIndex == nil) then
			local newAbleToSendSize = table.maxn(mcoAbleToSendData) + 1;

			table.insert(mcoAbleToSendData, newAbleToSendSize, {});
			mcoAbleToSendData[newAbleToSendSize].isAble = false;
			mcoAbleToSendData[newAbleToSendSize].channelName = channelName;
		end

		ableToSendIndex = mcoGetIndexOfAbleToSend(channelName);
		mcoAbleToSendData[ableToSendIndex].isAble = false;
	else
		if (not ableToSendIndex or ableToSendIndex == nil) then
			local newAbleToSendSize = table.maxn(mcoAbleToSendData) + 1;

			table.insert(mcoAbleToSendData, newAbleToSendSize, {});
			mcoAbleToSendData[newAbleToSendSize].isAble = false;
			mcoAbleToSendData[newAbleToSendSize].channelName = channelName;
		end

		mtiResetTimer(mcoChannelTimerId[index].id);
		mtiStartTimer(mcoChannelTimerId[index].id);

		ableToSendIndex = mcoGetIndexOfAbleToSend(channelName);
		mcoAbleToSendData[ableToSendIndex].isAble = false;
	end
end

function mcoGetIndexOfChannelTimer(channelName)
	for i = 1, table.maxn(mcoChannelTimerId) do
		if (mcoChannelTimerId[i].channelName == channelName) then
			return i;
		end
	end
end

function mcoGetIndexOfAbleToSend(channelName)
	for i = 1, table.maxn(mcoAbleToSendData) do
		if (mcoAbleToSendData[i].channelName == channelName) then
			return i;
		end
	end
end
----------------------------------------------------------
--			UTILITY FUNCTIONS               --
----------------------------------------------------------
