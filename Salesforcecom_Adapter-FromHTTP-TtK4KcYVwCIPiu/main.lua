local salesforce = require 'salesforce'
local salesforce_objects = require 'salesforce_objects'

local config = require 'encrypt.password'

local StoreKey = "dfsdfasdfadsfsa"

-- It's good practice to avoid saving your passwords in the repository.
-- So we use the encrypt.password module:
-- http://help.interfaceware.com/v6/encrypt-password-in-file

-- You'll need to:
--  A) Edit these values saved here.
--  B) Then uncomment the lines.
--  C) Then re comment the lines out
--  D) Then obfiscate your password from this Lua file *BEFORE* your next milestone commit.
--config.save{config='salesforce_consumer_key', password='3sdkASDjjhwkjehwehwhewhlehq2uh4jjhejhwekjhwerkwejhrwkejrhwkejrhwkre_dkfwkjfhwejhw6_26', key=StoreKey}
--config.save{config='salesforce_consumer_secret', password='3422348298342383384', key=StoreKey}
--config.save{config='salesforce_username', password='harold.brown@interfaceware.com', key=StoreKey}
--config.save{config='salesforce_password', password='dkjdwkjhewkej', key=StoreKey}

function main(Data)
   local ConsumerKey = config.load{config="salesforce_consumer_key", key=StoreKey}
   
   local C = salesforce.connect{username='richard.wang1@interfaceware.com', objects=salesforce_objects, 
      password='Iguana2016', consumer_key=ConsumerKey,  consumer_secret='3918946598378214139'}
  
   -- We use this method to generate a defintion for a given object type
   -- see the salesforce_objects.lua file.
   C:apiDefinition("Account")
   
   local R = 'List of salesforce.com users:\n'
   local Users = C:userList{}
   for i=1, #Users.records do
      R = R..Users.records[i].Name.."\n\n"
   end
   trace(R)
   net.http.respond{body=R, entity_type='text/plain'}
end

