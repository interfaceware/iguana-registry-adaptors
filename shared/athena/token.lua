function CheckClearCache(DoClear)
   if DoClear then
      store.resetTableState()
   end
end

function GetAccessTokenViaHTTP(CacheKey, Parameters)
   trace(Parameters, Url)
   local J = net.http.post{url=Url.root..Url.tokenPath, auth=Parameters.auth,
      live=true, parameters= {grant_type = 'client_credentials'} }
   store.put(CacheKey, J)
   store.put(CacheKey..'_time', os.ts.time())
   return json.parse{data=J}
end

function CheckTokenValid(CacheKey, T)
   local Time = store.get(CacheKey..'_time')
   local CacheData = store.get(CacheKey)
   CacheData = json.parse{data = CacheData}
   trace(os.ts.difftime(os.ts.time(), Time))
   if os.ts.difftime(os.ts.time(), Time) > CacheData.expires_in then
      CheckClearCache(true)
      GetAccessTokenViaHTTP(CacheKey, T)
   end
end

function GetAccessTokenCached(CacheKey, T)
   local S = store.get(CacheKey)
   if(S) then
      CheckTokenValid(CacheKey, T)
      return json.parse{data=S}
   else 
      return nil
   end
end
