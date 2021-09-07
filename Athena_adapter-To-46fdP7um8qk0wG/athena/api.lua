require 'net.http.cache'
local AthenaSource = require 'athena.athena_source'
local store2 = require 'store2'
local store = store2.connect('athena.db')
local appType = 'Preview'   -- type of AthenaHealth app (Preview or Production)

local Key
local Config

local athena = {}
local token = {}
local api = {}
local Url = { root = '', repository = 'preview1/', tokenPath = '', scope = '' }


local function CheckClearCache(DoClear)
   if DoClear then
      store:reset()
   end
end

local function GetAccessTokenViaHTTP(CacheKey, Parameters)
   trace(Parameters, Url)
   local J = net.http.post{url=Url.root..Url.tokenPath, auth=Parameters.auth,
      live=true, parameters= {grant_type = 'client_credentials', 
      scope = Url.scope} }
   store:put(CacheKey, J)
   store:put(CacheKey..'_time', os.ts.time())
   return json.parse{data=J}  
end

local function CheckTokenValid(CacheKey, T)
   local Time = store:get(CacheKey..'_time')
   local CacheData = store:get(CacheKey)
   CacheData = json.parse{data = CacheData}   
   trace(os.ts.difftime(os.ts.time(), Time))
   if os.ts.difftime(os.ts.time(), Time) > tonumber(CacheData.expires_in) then
      CheckClearCache(true)
      GetAccessTokenViaHTTP(CacheKey, T)
   end
end

local function GetAccessTokenCached(CacheKey, T)
   local S = store:get(CacheKey)
   if(S) then
      S = json.parse{data=S}
      if(S.error) then
         return nil
      else 
         CheckTokenValid(CacheKey, T)
         return S
      end
   end
   return nil
end

----------------------------------------------------------------------------------
-- This function checks if there has been a call recently made to this get function
-- in order to save time.
-- @params Data: the Api being called
-- @params P: Parameters necessary for the api call
   -- 2 sub tables : web, body
   -- web : parameter substitutes for api path variables
   -- body : paramters added to end of path
-- @calltype : the type of AJAX call being made (get, post, put, or delete)
----------------------------------------------------------------------------------
local function checkCache(Api, P, calltype)    
   if not iguana.isTest() then
      -- no caching when running in production
      return api.call(Api, P, calltype)
   end
   local Time = os.ts.time()
   local Key = json.serialize{data=P, compact=true}:gsub('["{}:,%]\[]', "")
   if store:get(Key..'_time') and calltype == 'read'
      and Time - store:get(Key .. '_time') < 400000 then
      return json.parse{data=store:get(Key)}
   end
   local R = api.call(Api, P, calltype)
   if iguana.isTest() and calltype=='read' then
      store:put(Key, json.serialize{data=R})
      store:put(Key.."_time", os.ts.time())
   end
   return R
end

local function ApiCall(UserParams, Path, Data, typeof)
   local ExpectedParams = Data.parameters
   trace(UserParams, ExpectedParams, typeof)
   local Params = {path = {}, web = {}}
   local hasContentType = false
   for i=1,#ExpectedParams do
      local param = ExpectedParams[i]
      trace(param.name)
      if(param.name ~= 'Authorization' and param.name ~= 'Content-Type') then
         if param['in'] ~= 'path' then 
            Params.web[param.name] = UserParams[param.name]            
         elseif param['in'] == 'path' then            
            Params.path[param.name] = UserParams[param.name]            
         end
      elseif param.name == 'Content-Type' then   
         hasContentType = true         
      end      
   end   
   if hasContentType then
      -- Add any content-related parameters 
      local _,content = next(Data.requestBody.content)         
      for K,V in pairs(content.schema.properties) do
         Params.web[K] = UserParams[K]            
      end
   end
   return checkCache(Path, Params, typeof)
end

local function handleErrors(Response, Err, Header, Extras)
   iguana.logInfo(Response)
   if Err ~= 200 then -- For all responses other thsn 200 OK
       if Err == 401 then --Failed Authorization
         --Problem to look into later : config and Key are now not local
         trace(token)
         local tempToken = GetAccessTokenViaHTTP('access_token', {auth={username=Config.load{config='athena_key', key=Key}, 
                  password=Config.load{config='athena_secret', key=Key}}}).access_token
         trace(tempToken)
         Extras.P.header.Authorization = "Bearer "..tempToken
         Response, E, Header = api[Extras.typeof](Extras.api, Extras.P) --Retry the Api call
         if E ~= 200 then
            error('Failed to Authorize', 6)
         else
            return json.parse{data=Response}
         end
      end
      if Err == 404 then --incorrect/missing parameters
         trace(Response)
         return json.parse{data=Response}
      end
      if Err == 400 or Err == 403 then --Error in response    
         local ResponseError = ''
         local Response = json.parse{data=Response}
         ResponseError = ResponseError..Response.error..'\n'
         for K, V in pairs(Response) do
            if(K ~= 'error') then
               local BonusData = ''
               if(type(V) ~= 'table') then
                  BonusData = BonusData..V
               else
                  for K2,V2 in pairs(V) do
                     BonusData = BonusData..V2..' '
                  end
               end              
               ResponseError = ResponseError..' '..BonusData
            end
            trace(ResponseError)
         end
         error('API response error: ' .. Err .. ' ( '..ResponseError..' ) returned for query call.', 6)  
         return
      end
      if Err == 596 then
         error('Service not found', 6)
      end
   else -- return data from successful 200 OK response
      if Response ~= '' then
         return json.parse{data=Response}
      else 
         return Response
      end       
   end
end

local function MakeParamsArray(Params)
   local Result = {}   
   local hasContentType = false
   for i=1,#Params.parameters do 
      local param = Params.parameters[i]      
      if param.name ~= 'Authorization' and param.name ~= 'Content-Type' then
         trace(param.name)
         Result[i] = {}
         Result[i][param.name] = {}
         Result[i][param.name].Opt = not param.required
         Result[i][param.name].Desc = param.description
         if(param.schema.type) then
            Result[i][param.name].Desc = Result[i][param.name].Desc..' ('..param.schema.type..')'
         end         
      elseif param.name == 'Content-Type' and Params.requestBody ~= nil then         
         hasContentType = true      
      end
      trace(Result[i])
   end
   if hasContentType then
      -- Add any required content-related parameters 
      trace(Params)         
      local _,content = next(Params.requestBody.content) -- account for different content types         
      local requiredContent = {}
      if content.schema.required ~= nil then
         for j=1,#content.schema.required do
            requiredContent[content.schema.required[j]] = true
         end
      end
      trace(requiredContent)      
      for K,V in pairs(requiredContent) do         
         local j = #Result + 1
         Result[j] = {}
         Result[j][K] = {}
         Result[j][K].Opt = false         
         Result[j][K].Desc = content.schema.properties[K].description
      end 
   end
   return Result
end   

local function translateToCrud(def)
   if     def == 'GET'  then  return 'read'
   elseif def == 'POST' then  return 'add'
   elseif def == 'PUT'  then  return 'update'
   end
   return 'delete'
end

local function MakeHelp(Path,Table, func)
   trace(Table)
   local HelpInfo = {}
   HelpInfo.Desc = Table.description
   HelpInfo.ParameterTable = true
   HelpInfo.Parameters = MakeParamsArray(Table)
   HelpInfo.Title = "Api: "..Path
   help.set{input_function=func, help_data=HelpInfo}
end

local function makeObj(Path,Method,Data, a, Index)   
   local typeof = translateToCrud(Method:upper())
   local Table = string.split(Path, '/')
   local subStr = string.sub(Table[Index], 0, 1)   
   local url = Path:gsub('[{}]','')
   if(subStr == '{') then
      Table[Index] = string.sub(Table[Index], 2, string.len(Table[Index])-1)
   end
   if Index == #Table then
      trace(a[Table[Index]])
      if not a[Table[Index]] then 
         a[Table[Index]] = {[typeof] = function(P) return ApiCall(P, url, Data ,typeof) end}
         MakeHelp(url,Data, a[Table[Index]][typeof])
      else
         a[Table[Index]][typeof] = function(P) return  ApiCall(P, url, Data ,typeof) end
         MakeHelp(url,Data, a[Table[Index]][typeof])
      end
   elseif not a[Table[Index]] then
      a[Table[Index]] = {}
      makeObj(url,Method,Data, a[Table[Index]], Index + 1)
   elseif a[Table[Index]] then
      makeObj(url,Method,Data, a[Table[Index]], Index + 1)
   end   
end

local function init()
   local ApiData = json.parse{data=AthenaSource}
   trace(ApiData)
   -- Initialize root url, token path, and scope 
   for i=1,#ApiData.servers do
      if ApiData.servers[i].description == appType then
         Url.root = ApiData.servers[i].url..'/'
      end
   end
   local oauthDetails 
   if appType == 'Preview' then      
      oauthDetails = ApiData.components.securitySchemes.mdp_auth_preview      
   else
      oauthDetails = ApiData.components.securitySchemes.mdp_auth
   end
   Url.tokenPath = oauthDetails.flows.clientCredentials.tokenUrl:gsub(Url.root,'')   
   Url.scope = next(oauthDetails.flows.clientCredentials.scopes)
   trace(Url)

   local a  = {}
   
   for path,Methods in pairs(ApiData.paths) do
      trace(path,Methods)      
      for Method,Details in pairs(Methods) do
         trace(Method,Details)
         local Subsection = Details.tags[1]:lower()
         if not a[Subsection] then a[Subsection] = {} end
         makeObj(path,Method,Details, a[Subsection], 4)
      end      
   end
   trace(a)
   return a
end

local athenaSchema = init()
----------------------------------------------------------------------------------
-- The following 4 functions are for the 4 supported AJAX calls for Athena Health
-- @params api: The api call being made
-- @params params: Parameters necessary for the api call
   -- 3 sub tables : web, body, header
   -- web : parameter substitutes for api path variables
   -- body : paramters added to end of path
   -- header : header parameters i.e. Authorization and Connection
----------------------------------------------------------------------------------
function api.read(api, params)
   trace(params, token)
   local Result, E, Header = net.http.get{url=Url.root..api, headers=params.header, parameters=params.web, live=true, cache_time=60}
   trace(Result, E, Header)
   return Result, E, Header
end

function api.add(api, params)
   trace(params.header, params.web)
   local Result, E, Header = net.http.post{url=Url.root..api, headers=params.header, parameters=params.web, live=true, cache_time=60}
   return Result, E, Header
end

local function urlEncodeParams(Params)
   local Result = ''
   for K, V in pairs(Params) do
      Result = Result ..K..'='..filter.uri.enc(tostring(V))..'&'
   end
   return Result:sub(1, #Result-1)
end

function api.update(api, params)
   local data = urlEncodeParams(params.web)
   if(data == '') then --It wont let me do the request with just an empty string
      data = 'blank=yes'
   end   
   local Result, E, Header = net.http.put{url=Url.root..api, headers=params.header, data=data, live=true, cache_time=60}
   return Result, E, Header
end

function api.delete(api, params)
   trace(params)
   local QueryParams = '?'
   for K, V in pairs(params.web) do
      QueryParams = QueryParams..K..'='..V..'&'
   end
   QueryParams = string.sub(QueryParams, 0, string.len(QueryParams) - 1)   
   local Result, E, Header = net.http.delete{url = Url.root..api..QueryParams, headers=params.header, live=true, cache_time=60}
   return Result, E, Header
end
----------------------------------------------------------------------------------
-- Substitutes the appropriate path variables into the api
-- @params api: The api call being made
-- @params params: a table of web variables ot their values to be substituted into
-- the url
----------------------------------------------------------------------------------
local function createUrl(params, api)
   if (api:sub(0, 3) == '/v1') then -- handles new fhir nonsense
      api = 'v1'..api:sub(4, #api) --idk if this should be preview1 or w.e they use.
   end
   trace(api)
   for K, V in pairs(params) do
      trace(K, V)
      local start, stop = api:find(K, nil)
      trace(start, stop)
      if(start ~= nil) then
         local beginning = api:sub(1, start - 1)
         local ending = api:sub(stop + 1, api:len())
         trace(beginning, ending)
         api = beginning..V..ending
      end
   end
   trace(api)
   return api
end
----------------------------------------------------------------------------------
-- The main function called when you want to make an AJAX call
-- @params api: The api call being made
-- @params params: Parameters necessary for the api call
   -- 3 sub tables : web, body, header
   -- web : parameter substitutes for api path variables
   -- body : paramters added to end of path
   -- header : header parameters i.e. Authorization and Connection
      -- Note : omitting Content-Type from the header is typically fine. If required, 
      -- the type can be retrieved from the Data variable in the function ApiCall
-- @calltype : the type of AJAX call being made (get, post, put, or delete)
----------------------------------------------------------------------------------
function api.call(Api, params, calltype) 
   trace(token)      
   params.header = { Authorization = "Bearer "..token.access_token, Connection = 'keep-alive'}   
   Api = createUrl(params.path, Api)
   local Result, Header, E = {}, {}, 0
   Result, E, Header = api[calltype](Api, params)
   return handleErrors(Result, E, Header, {api = Api, P = params, typeof = calltype})
end

----------------------------------------------------------------------------------
-- Used to connected to Athena Help based on client key and client secret
-- Tries to find a cached token, if not will make an ajax call to get a new one
-- and store it, as well as store the time it was accessed
-- @params T:  Contains client key and secret and information necessary for
-- connection
----------------------------------------------------------------------------------
function athena.connect(Credentials)   
   Config = Credentials.config
   Key = Credentials.key
   local T = {auth = {username = Credentials.username, password = Credentials.password},
         grant_type = 'client_credentials', 
         clear_cache = Credentials.cache,
         key = 'access_data'}
   CheckClearCache(not T.clear_cache)
   token = GetAccessTokenCached(T.key, T) or GetAccessTokenViaHTTP(T.key, T)
   if token.error then
      error(token.error, 2)
   end   
   return athenaSchema --return cached result of init()
end
--- setting help for athena.connect
local HelpInfo = {Title = 'athena.connect', Desc = 'Connect to Athena server', ParameterTable = true, Parameters = {}}
HelpInfo.Parameters[1] = {['username'] = {['Desc'] = 'Client key for the app', ['Opt'] = false }}
HelpInfo.Parameters[2] = {['password'] = {['Desc'] = 'Client secret for the app', ['Opt'] = false }}
HelpInfo.Parameters[3] = {['cache'] = {['Desc'] = 'Keep a cache of app token', ['Opt'] = false }}
HelpInfo.Parameters[4] = {['config'] = {['Desc'] = 'Config object used to store credentials', ['Opt'] = false }}
HelpInfo.Parameters[5] = {['key'] = {['Desc'] = 'key to configuration file', ['Opt'] = false }}

trace(HelpInfo)
help.set{input_function=athena.connect, help_data=HelpInfo}

return athena