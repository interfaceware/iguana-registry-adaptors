-- This demonstrates a wrapper for the Athena RESTful web API
-- Before using the Athena Adapter, please enter your consumer key and consumer secret into the config.lua file in
-- the shared/athena folder.
-- See http://help.interfaceware.com/forums/topic/athena-health-web-adapter
require 'athena.api'
config = require 'athena.config'

function main() 
   Connection = athena.connect{username=config.username, password=config.password, cache=true}
 
   local Appointments = Connection.appointments.appointmenttypes.read{practiceid=195900}
   
  
   
      
  -- Connection.administrative.providers.read{practiceid=195900}
  
   
   
end



