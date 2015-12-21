-- This demonstrates a wrapper 
-- Before using the Athena Adapter, please enter your consumer key and consumer secret into the config file.
require 'athena.api'
config = require 'config'

function main() 
   Connection = athena.connect{username=config.username, password=config.password, cache=true}
   Connection.appointments.appointmenttypes.read{practiceid=195900}
  -- Connection.administrative.providers.read{practiceid=195900}
   
end


