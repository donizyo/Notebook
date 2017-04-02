--------------------------------------------------------------------------
--Server interface
--------------------------------------------------------------------------

local function OnPagesChanged(parent, data)
    local notebook = parent.components.notebook
    for page, text in pairs(data.newpages) do
        notebook.pages[page] = text
    end
end

--------------------------------------------------------------------------
--Client interface
--------------------------------------------------------------------------

local function OnRemoveEntity(inst)
    if inst._parent ~= nil then
        inst._parent.notebook_classified = nil
    end
end

local function OnEntityReplicated(inst)
    inst._parent = inst.entity:GetParent()
    if inst._parent == nil then
        print("Unable to initialize classified data for notebook")
    elseif inst._parent.replica.notebook ~= nil then
        inst._parent.replica.notebook:AttachClassified(inst)
    else
        inst._parent.notebook_classified = inst
        inst.OnRemoveEntity = OnRemoveEntity
    end
end

local function OnPagesDirty(inst)
    if inst._parent ~= nil then
        local pages = inst.pages:value()
        local data =
        {
            newpages = pages,
        }
        inst._parent:PushEvent("pageschanged", data)
    end
end

local function SendRPC(namespace, name, ...)
    local id_table = { namespace = namespace, id = MOD_RPC[namespace][name].id }
    print("KK-TEST> SendRPC:", ...)
    SendModRPCToServer(id_table, ...)
end

local function SetPages(inst, doer, pages)
    local book = inst._parent
    assert(book ~= nil and book:IsValid() and book.prefab and book.prefab == "book_notebook", "Invalid inst parent!")
    local json = require("json")
    pages = json.encode(pages)
    assert(type(pages) == "string", "Error occurred while encoding json string!")
    SendRPC("NOTEBOOK", "SetPages", book, pages)
end

local function BeginWriting(inst)
    local book = inst._parent
    assert(book ~= nil and book:IsValid() and book.prefab and book.prefab == "book_notebook", "Invalid inst parent!")
    SendRPC("NOTEBOOK", "BeginWriting", book)
end

local function EndWriting(inst)
    local book = inst._parent
    assert(book ~= nil and book:IsValid() and book.prefab and book.prefab == "book_notebook", "Invalid inst parent!")
    SendRPC("NOTEBOOK", "EndWriting", book)
end

--------------------------------------------------------------------------
--Common interface
--------------------------------------------------------------------------


--------------------------------------------------------------------------

local function RegisterNetListeners(inst)
    if TheWorld.ismastersim then
        -- server
        inst._parent = inst.entity:GetParent()
        inst:ListenForEvent("pageschanged", OnPagesChanged, inst._parent)
    else
        -- client
        inst:ListenForEvent("pagesdirty", OnPagesDirty)
    end
    -- common
end

--------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()
    
    inst.entity:AddNetwork()
    inst.entity:Hide()
    inst:AddTag("CLASSIFIED")
    
    --Net variables
    inst.pages = net_entity(inst.GUID, "notebook.pages", "pagesdirty")
    -- Initialize net variables
    inst.pages:set_local({}) -- FIXME useless?
    print("Prefab 'notebook_classified' instance (".. tostring(inst.GUID) .. ") is initialized.")
    
    --Delay net listeners until after initial values are deserialized
    inst:DoTaskInTime(0, RegisterNetListeners)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        --Client interface
        inst.OnEntityReplicated = OnEntityReplicated
        inst.SetPages = SetPages
        inst.BeginWriting = BeginWriting
        inst.EndWriting = EndWriting

        return inst
    end

    --Server interface
    
    inst.persists = false

    return inst
end

return Prefab("notebook_classified", fn)
