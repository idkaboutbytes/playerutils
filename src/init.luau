--!strict
--!optimize 2
--[=[
	@library PlayerUtils
]=]

const LocalizationService = game:GetService("LocalizationService")
const Players = game:GetService("Players")
const TextChatService = game:GetService("TextChatService")
const VoiceChatService = game:GetService("VoiceChatService")

const Promise = require("./roblox_packages/Promise")

export type UserInfo = {
	Username: string,
	DisplayName: string,
	HasVerifiedBadge: boolean,
}

export type FriendData = {
	Id: number,
	Username: string,
	DisplayName: string,
	IsOnline: boolean,
}

const PlayerUtils = {}

--[=[
	Clears all tools from a player's backpack.

	@param player Player -- The player whose tools to clear
]=]
@checked
function PlayerUtils.clearTools(player: Player)
	local backpack = player.Backpack

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end
end

--[=[
	Safely connects to PlayerAdded event and calls the callback for existing players.
	This ensures the callback is called for all players, even those who joined before
	the connection was made.

	@param Callback function -- Function to call for each player
	@return RBXScriptConnection -- The PlayerAdded connection
]=]
@checked
function PlayerUtils.safePlayerAdded(Callback: (Player) -> nil): RBXScriptConnection
	assert(typeof(Callback) == "function", "Exception on safePlayerAdded: Callback must be type function")

	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Callback, Player)
	end

	return Players.PlayerAdded:Connect(Callback)
end

--[=[
	Finds a player by matching the beginning of their username or display name.
	Case-insensitive search.

	@param text string -- The text to search for
	@return Player? -- The matching player, or nil if not found
]=]
@checked
function PlayerUtils.fzyFindPlayerFromText(text: string): Player?
	for _, player in ipairs(Players:GetPlayers()) do
		local username = player.Name:lower()
		local displayName = player.DisplayName:lower()

		if username:sub(1, #text):lower() == text:lower() or displayName:sub(1, #text):lower() == text:lower() then
			return player
		end
	end

	return nil
end

--[=[
	Formats a player's name with their display name.
	If the name and display name are the same, returns just the display name.
	Otherwise returns "DisplayName (@Username)".

	@param player Player -- The player to format the name for
	@return string -- Formatted name
]=]
@checked
function PlayerUtils.formatNameWithDisplay(player: Player): string
	local name = player.Name :: string
	local displayName = player.DisplayName :: string

	if name:lower() == displayName:lower() then
		return displayName
	else
		return ("%s (@%s)"):format(displayName, name)
	end
end

--[=[
	Human-readable version of a player name. If the player's name is the same
	as the display name, then returns that player's name. Otherwise returns
	a formatted name with the player's name like this "oot (@martxn)" which
	lets you know the username and the display name.

	Note this is not localized, although most languages should be ok. Great for
	output for dev logs and command services which are less picky.

	@param player Player
	@return string -- Formatted name
]=]
@checked
function PlayerUtils.formatName(player: Player): string
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	local name = player.Name
	local displayName = player.DisplayName

	return PlayerUtils.formatDisplayName(name, displayName)
end

--[=[
	Human-readable version of a player name. If the player's name is the same
	as the display name, then returns that player's name. Otherwise returns
	a formatted name with the player's name like this "oot (@martxn)" which
	lets you know the username and the display name.

	Note this is not localized, although most languages should be ok. Great for
	output for dev logs and command services which are less picky.

	@param name string
	@param displayName string
	@return string -- Formatted name
]=]
@checked
function PlayerUtils.formatDisplayName(name: string, displayName: string): string
	if string.lower(name) == string.lower(displayName) then
		return displayName
	else
		return string.format("%s (@%s)", displayName, name)
	end
end

--[=[
	Formats the display name from the user info
	@param userInfo UserInfo
	@return string
]=]
@checked
function PlayerUtils.formatDisplayNameFromUserInfo(userInfo: UserInfo): string
	assert(type(userInfo) == "table", "Bad userInfo")
	assert(type(userInfo.Username) == "string", "Bad userInfo.Username")
	assert(type(userInfo.DisplayName) == "string", "Bad userInfo.DisplayName")

	local result = PlayerUtils.formatDisplayName(userInfo.Username, userInfo.DisplayName)

	if userInfo.HasVerifiedBadge then
		return PlayerUtils.addVerifiedBadgeToName(result)
	end

	return result
end

--[=[
	Adds verified badges to the name

	@param name string
	@return string
]=]
@checked
function PlayerUtils.addVerifiedBadgeToName(name: string): string
	return string.format("%s %s", name, utf8.char(0xE000))
end

--[=[
	Gets the country/region code for a player asynchronously.

	@param player Player -- The player to get the region for
	@return Promise<string> -- Promise that resolves with the region code
]=]
@checked
function PlayerUtils.getPlayerRegionAsync(player: Player)
	local success, response = pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)

	if success then
		return Promise.resolve(response)
	else
		return Promise.rejected(response)
	end
end

--[=[
	Gets all friends of a player who are currently in the server.

	@param player Player -- The player to check friends for
	@return {Player} -- Array of friend players in the server
]=]
@checked
function PlayerUtils.getFriendsInServer(player: Player): { Player }
	local friends = {}
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player and player:IsFriendsWithAsync(otherPlayer.UserId) then
			table.insert(friends, otherPlayer)
		end
	end
	return friends
end

--[=[
	Checks if a user can use chat asynchronously.

	@param player Player -- The player to check chat permissions for
	@return Promise<boolean> -- Promise that resolves with whether the player can chat
]=]
@checked
function PlayerUtils.promiseCanUserChatAsync(player: Player)
	return Promise.new(function(resolve, reject)
		local success, canChat = pcall(TextChatService.CanUserChatAsync, TextChatService, player.UserId)

		if success then
			resolve(canChat)
		else
			reject(canChat)
		end
	end)
end

--[=[
	Checks if two users can direct chat with each other asynchronously.

	@param player1 Player -- The first player
	@param player2 Player -- The second player
	@return Promise<boolean> -- Promise that resolves with whether the players can direct chat
]=]
@checked
function PlayerUtils.promiseCanUsersDirectChatAsync(player1: Player, player2: Player)
	return Promise.new(function(resolve, reject)
		local success, canDirectChat =
			pcall(TextChatService.CanUsersDirectChatAsync, TextChatService, player1.UserId, player2.UserId)

		if success then
			resolve(canDirectChat)
		else
			reject(canDirectChat)
		end
	end)
end

--[=[
	Reports whether voice chat is enabled for a player.

	@param player Player
	@return Promise<boolean>
]=]
@checked
function PlayerUtils.promiseIsVoiceEnabledForPlayer(player: Player): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerUtils.PromiseIsVoiceEnabledForUserId(player.UserId)
end

--[=[
	Reports whether voice chat is enabled for a user ID.

	@param userId number
	@return Promise<boolean>
]=]
@checked
function PlayerUtils.promiseIsVoiceEnabledForUserId(userId: number): Promise.Promise<boolean>
	assert(type(userId) == "number", "Bad userId")

	return Promise.new(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = VoiceChatService:IsVoiceEnabledForUserIdAsync(userId)
		end)

		if not ok then
			warn(err)
			return reject(err)
		end
		if type(result) ~= "boolean" then
			return reject("Result was not a boolean")
		end

		return resolve(result)
	end)
end

--[=[
	Promises the userId from a given name.

	@param name string -- The username to look up
	@return Promise<number> -- Promise that resolves with the user ID
]=]
@checked
function PlayerUtils.promiseUserIdFromName(name: string): Promise.Promise
	assert(type(name) == "string", "Bad name")

	return Promise.new(function(resolve, reject)
		local userId
		local ok, err = pcall(function()
			userId = Players:GetUserIdFromNameAsync(name)
		end)

		if not ok then
			return reject(err)
		end

		if type(userId) ~= "number" then
			return reject("UserId returned was not a number")
		end

		return resolve(userId)
	end)
end

--[=[
	Promises the username from a given userId.

	@param userId number -- The user ID to look up
	@return Promise<string> -- Promise that resolves with the username
]=]
@checked
function PlayerUtils.promiseNameFromUserId(userId: number): Promise.Promise
	assert(type(userId) == "number", "Bad userId")

	return Promise.new(function(resolve, reject)
		local username
		local ok, err = pcall(function()
			username = Players:GetNameFromUserIdAsync(userId)
		end)

		if not ok then
			return reject(err)
		end

		if type(username) ~= "string" then
			return reject("Username returned was not a string")
		end

		return resolve(username)
	end)
end

--[=[
	Calls :LoadCharacterAsync() in a Promise

	@param player Player
	@return Promise<Model>
]=]
function PlayerUtils.promiseLoadCharacter(player: Player): Promise.Promise<Model>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			player:LoadCharacterAsync()
		end)
		if not ok then
			return reject(err or "Failed to load character")
		end

		return resolve()
	end)
end

return PlayerUtils
