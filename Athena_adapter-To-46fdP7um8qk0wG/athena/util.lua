-- This Athena API Utility Tool
local config = require 'encrypt.password'
local Key = 'sdfasdfakdsakjyhfghfweiuhwifsdfsfsdeuhwiuhc'
local retry = require 'retry'
local athena = require 'athena.api'

local athenaUtil = {}

local function InitialSetup()
   -- Follow these steps to store Athena server credentials securely in 2 configuration files
   -- Be careful not to save a milestone containing password information
   --  1) Enter password for athena_key and athena_secret
   --  2) Uncomment the lines.
   --  3) Recomment the lines
   --  4) Remove the password *BEFORE* you same a milestone

  --config.save{key=Key,config="athena_key",    password=""}
  --config.save{key=Key,config="athena_secret", password=""}
end

local function Connection() 
   local Username = config.load{config='athena_key', key=Key} -- Client Id
   local Password = config.load{config='athena_secret', key=Key} -- Client Key
   api = athena.connect{username=Username, password=Password, config=config, key=Key, cache=true}
   return api
end

function athenaUtil.getAthenaAPI()
   InitialSetup()
   local api = retry.call{func= Connection,retry=2, pause=3480,funcname='athenaUtil_Connection'}
   return api
end


return athenaUtil