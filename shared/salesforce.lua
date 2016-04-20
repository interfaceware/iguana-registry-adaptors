local salesforce = {}

local store2 = require 'store2'

require 'net.http.cache'

local Store = store2.connect(iguana.project.guid().."salesforce")
 
local function GetCache(Key, CacheTimeout)
   if (CacheTimeout == 0) then
      return nil
   end
   local CacheTime = Store:get(Key.."T")
   if (os.ts.difftime(os.ts.time(), CacheTime) < CacheTimeout) then
      local CachedData = Store:get(Key)
      local R = json.parse{data=CachedData}
      return R
   end
   return nil
end

local function PutCache(Key, Value)
   Store:put(Key, Value)
   Store:put(Key.."T", os.ts.time())
end


local function GetAccessTokenViaHTTP(CacheKey,T)
   local Url = 'https://login.salesforce.com/services/oauth2/token'
   local Auth = {grant_type = 'password',
      client_id = T.consumer_key,
      client_secret = T.consumer_secret,
      username = T.username,
      password = T.password}
   local J = net.http.post{url=Url,
      parameters = Auth,
      live=true}
   PutCache(CacheKey, J)
   local AccessInfo = json.parse(J)
   return AccessInfo
end

local function CheckClearCache(DoClear)
   if DoClear then
      Store:reset()
   end
end

local function queryObjects(S, T)
   if (T.where) then
      T.query = T.query.." WHERE "..T.where
   end
   if (T.limit) then
      T.query = T.query.." LIMIT "..T.limit
   end
   local P ={parameters={q=T.query}, url=S.instance_url..T.path,
             headers={Authorization="Bearer ".. S.access_token}, cache_time=T.cache_time, live=true}
  
   local R=net.http.get(P)
   R = json.parse{data=R}
   if #R > 0 and R[1].errorCode then
      error(R[1].message,4)
   end
   return R
end


local function selectQuery(T)
   local R = 'SELECT Id';
   for K,V in pairs(T.fields) do
      R = R..","..K
   end
   R = R.." FROM "..T.object
   return R
end

local function listObjects(S,T,D)
   T = T or {}
   T.query = selectQuery(D)
   T.path = '/services/data/v20.0/query' 
   return queryObjects(S,T)   
end

local salesmethods = {}
local MetaTable = {}
MetaTable.__index = salesmethods;

local function GenerateListMethod(Name, Info)
   local FName = Name..'List'
   salesmethods[FName] = function(S,T) return listObjects(S,T,Info) end;
   local F = salesmethods[FName]
   local Help = {}
   Help.Desc = "Query list of "..Name
   Help.ParameterTable = true
   Help.Parameters = {}
   Help.Parameters[1] = {limit={Opt=true, Desc="Limit the number of results - default is no limit."}}
   Help.Parameters[2] = {where={Opt=true, Desc="Give a WHERE clause."}}
   Help.Parameters[3] = {cache_time={Opt=true, Desc="Specific time to cache results (seconds). Default is 0 seconds."}}
   help.set{input_function=F, help_data=Help}         
end

local function deleteObject(S, T, ObjectName)
   local Live = not iguana.isTest() or T.live
   local Path = S.instance_url..
       '/services/data/v20.0/sobjects/'..ObjectName..'/'..T.id
   local Headers={}
   Headers['Content-Type']='application/json'
   Headers.Authorization ="Bearer ".. S.access_token        
   local Returned = net.http.put{data=json.serialize{data=T}, method='DELETE',headers=Headers, 
      url=Path,live=Live}
   return ParseResult(Returned)   
end

local function GenerateDeleteMethod(Name, Info)
   local FName = Name..'Delete'
   salesmethods[FName] = function (S,T) return deleteObject(S,T,Info.object) end
   local F = salesmethods[FName]
   local Help = {}
   Help.Desc = "Delete a "..Name
   Help.ParameterTable = true
   Help.Parameters = {}
   Help.Parameters[1] = {id={Desc="Unique id of "..Name.." that will be deleted."}}
   Help.Parameters[2] = {live={Opt=true, Desc="Set to true to make this command work in the editor.  Default is false."}}
   help.set{input_function=F, help_data=Help}      
end


local function ParseResult(Returned)
   if #Returned == 0 then
      return {}
   end
   local R = json.parse{data=Returned}
   if #R > 0 and R[1].errorCode then
      error(R[1].message,4)
   end
   return R
end

local function patchObject(S, T, ObjectName)
   local Live = not iguana.isTest() or T.live
   local Path = S.instance_url..
       '/services/data/v20.0/sobjects/'..ObjectName..'/'
   local Method
   if T.Id then T.id = T.Id T.Id = nil end
   if (T.id) then
      trace("Updating");
      Method = 'PATCH'
      Path = Path..T.id
      T.id = nil;
   else  
      trace("New record");
      Method = 'POST'
   end
   trace(Path)
   T.live = nil;
   local Headers={}
   Headers['Content-Type']='application/json'
   Headers.Authorization ="Bearer ".. S.access_token 
   local Returned = net.http.put{data=json.serialize{data=T}, method=Method,headers=Headers, 
      url=Path,live=Live}
   return ParseResult(Returned)
end

local function GenerateModifierMethod(Name, Info)
   local FName = Name..'Modify'
   salesmethods[FName] = function (S,T) return patchObject(S, T, Info.object) end
   local F = salesmethods[FName]
   local Help = {}
   Help.Desc = "Create or update a "..Name
   Help.ParameterTable = true
   Help.Parameters = {}
   Help.Parameters[1] = {id={Opt=true, Desc="Unique id of "..Name..". If not present a new field will be created."}}
   Help.Parameters[2] = {live={Opt=true, Desc="Set to true to make this command work in the editor.  Default is false."}}
   for K,V in pairs(Info.fields) do
      Help.Parameters[#Help.Parameters+1] = {}
      Help.Parameters[#Help.Parameters][K] = {Opt=true, Desc=V}  
   end 
   help.set{input_function=F, help_data=Help}   
end

local function BuildMethods(Objects)
   for K,V in pairs(Objects) do
      GenerateListMethod(K,V)
      GenerateModifierMethod(K,V)
      GenerateDeleteMethod(K,V)
   end
end

function salesforce.connect(T)
   BuildMethods(T.objects)
   CheckClearCache(T.clear_cache)
   local P = GetCache(T.consumer_key, 1800) or
             GetAccessTokenViaHTTP(T.consumer_key, T) 
   
   P.objects = T.objects
   setmetatable(P, MetaTable)
   return P
end

local helpinfo = {}

local HelpConnect = [[{"SeeAlso":[{"Title":"Salesforce","Link":"http://www.salesforce.com"}],
                "Returns":[{"Desc":"The salesforce.com website."}],
                "Title":"salesforce.connect",
         "Parameters":[{"username":{"Desc":"User ID to login with."}},
                       {"password":{"Desc":"Password of that user ID"}},
                       {"consumer_key":{"Desc":"Consumer key for this connected app."}},
                       {"consumer_secret":{"Desc":"Consumer secret for this connected app."}},
                       {"objects":{"Desc":"Salesforce object definitions for this app."}},  
                       {"clear_cache":{"Opt" : true,"Desc":"If this is set to true then then the SQLite cache used to improve performace will be cleared."}},],
         "ParameterTable": true,
         "Usage":" local C = salesforce.connect{clear_cache=false,
                      objects=salesforce_objects,
                      username='sales@interfaceware.com', 
                      password='mypassword', 
                      consumer_secret='585519048400883388', 
                      consumer_key='3MVG9KI2HHAq33RyfdfRmZyEybpy7b_bZtwCyJW7e._mxrVtsrbM.g5n3.fIwK3vPGRl2Ly2u7joju3yYpPeO' }",
         "Desc":"Returns a connection object to salesforce instance"}]]

help.set{input_function=salesforce.connect, help_data=json.parse{data=HelpConnect}}


function salesmethods:describe(Object)
   local S = self;
   local Url = S.instance_url..'/services/data/v20.0/sobjects/'..Object..'/describe/'
   trace(Url)
   local Headers={}
   Headers['Content-Type']='application/json'
   Headers.Authorization ="Bearer ".. S.access_token 
   local R = net.http.get{headers=Headers, live=true, url=Url, parameters={}} 
   return json.parse{data=R}
end

-- Used to generate API set
local function PrettyPrint(List, Name)
   local Def = List[Name]
   local R = "objectDefs."..Name.." = {"
   R = R.."object='"..Def.object.."', fields={\n"   
   for K,V in pairs(Def.fields) do
      R = R..'                      '..K..'="'..V..'",\n'
   end
   R = R:sub(1, #R-2).."}}\n\n"
   return R
end

local function ObjectName(Name)
   return Name:sub(1,1):lower()..Name:sub(2)
end


local function GenerateAPI(S, Object)
   local Info = S:describe(Object)
   local CName = ObjectName(Object)
   local Def = {}
   Def.object = Object
   Def.fields ={}
   for i=1, #Info.fields do
      local Name = Info.fields[i].name
      trace(Name)
      trace(Info.fields[i])
      if Name ~= 'Id' then
         if (S.objects[CName] and S.objects[CName].fields[Name] ) then
            Def.fields[Name] = S.objects[CName].fields[Name]
         else
            Def.fields[Name] = "?" 
         end
      end
   end
   return Def
end

-- Example objects QueueSobject, Account, Community, Contact, ContentDocument, Document, Product2, Event, Group, Note, Profile, Task, TaskPriority, TaskStatus, User
-- See https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_list.htm

function salesmethods.apiDefinition(S, Name)
   local Def = {}
   local DefName = ObjectName(Name)
   Def[DefName] = GenerateAPI(S, Name)
   return PrettyPrint(Def, DefName)
end


return salesforce