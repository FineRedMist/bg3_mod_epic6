---List of entities that are client controlled. Cached for performance on both client and server.
---@type table<GUIDSTRING, boolean>
local clientControlledCharacters = {}

---Gets the locally controlled entity for the client side.
---@return EntityHandle? The entity under client control.
function GetLocallyControlledCharacter()
    if Ext.IsClient() then
        for entityId, _ in pairs(clientControlledCharacters) do
            return Ext.Entity.Get(entityId)
        end
    else
        _E6Error("GetLocallyControlledCharacter called on server!")
    end
    return nil
end

--- Handles updating the cache of client controlled characters when they are created.
--- @param entity EntityHandle The entity that was created.
local function ConditionalRegisterEntity(entity)
    if not entity then
        return
    end

    if not entity.UserReservedFor then
        return
    end

    local entityId = GetEntityID(entity)
    if entityId then
        --_E6P("Registering client controlled character: " .. tostring(entityId) .. " with name: " .. GetCharacterName(entity))
        clientControlledCharacters[entityId] = true
    end
end

--- Handles updating the cache of client controlled characters when they are created.
--- @param entity EntityHandle The entity that was created.
--- @param ct ComponentHandle The component handle.
--- @param c any The component data.
local function OnClientControlledEntityCreated(entity, ct, c)
    ConditionalRegisterEntity(entity)
end

--- Handles updating the cache of client controlled characters when they are destroyed.
--- @param entity EntityHandle The entity that was created.
--- @param ct ComponentHandle The component handle.
--- @param c any The component data.
local function OnClientControlledEntityDestroyed(entity, ct, c)
    if not entity.UserReservedFor then
        return
    end
    local entityId = GetEntityID(entity)
    if entityId then
        --_E6P("Unregistering client controlled character: " .. tostring(entityId) .. " with name: " .. GetCharacterName(entity))
        clientControlledCharacters[entityId] = nil
    end
end

---@param e EclLuaGameStateChangedEvent
local function E6_ManageClientControlledCharacters(e)
    if e.ToState == Ext.Enums.ClientGameState.Running then
        -- Gather any already existing entities.
        for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl")) do
            ConditionalRegisterEntity(entity)
        end
    end
end

--- Gather client controlled characters on entity creation and destruction. 
--- Iterating through all entities with the component was too inefficient.
--- From https://discord.com/channels/98922182746329088/771869529528991744/1345184473460899976
function RegisterClientControlHandlers()
    Ext.Events.GameStateChanged:Subscribe(E6_ManageClientControlledCharacters)

    Ext.Entity.OnCreate("ClientControl", OnClientControlledEntityCreated)
    Ext.Entity.OnDestroy("ClientControl", OnClientControlledEntityDestroyed)
end

---Returns the entities that correspond with the client controlled characters.
---@return EntityHandle[] The list of client controlled character entities.
local function GetClientControlledEntities()
    local result = {}
    for entityId, _ in pairs(clientControlledCharacters) do
        local entity = Ext.Entity.Get(entityId)
        if entity == nil or not entity.UserReservedFor then
            clientControlledCharacters[entityId] = nil
        else
            table.insert(result, entity)
        end
    end
    return result
end

---Whether the current player id is for the host.
---@param playerId GUIDSTRING The player id to check if they are the host
---@return boolean Whether the current character is the host
function IsHost(playerId)
    for _, entity in pairs(GetClientControlledEntities()) do
        if entity.UserReservedFor.UserID == 65537 and GetEntityID(entity) == playerId then
            return true
        end
    end

    return false
end

---Gather the entities with client controls. This is for the server to gather all instances of clients playing.
---@return EntityHandle[] The list of entity handles that are clients.
function GetClientEntities()
    local entities = {}
    for _, entity in pairs(GetClientControlledEntities()) do
        if GetEntityID(entity) then
            table.insert(entities, entity)
        end
    end

    return entities
end

