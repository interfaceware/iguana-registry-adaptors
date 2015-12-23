-- This demonstrates a wrapper for the Athena RESTful web API
-- We are looking at Athena for new patients being added to the Athena application
-- Before using the Athena Adapter, please enter your consumer key and consumer secret into the config.lua file in
-- the shared/athena folder.
-- See http://help.interfaceware.com/forums/topic/athena-health-web-adapter
require 'athena.api'
config = require 'athena.config'

csv = require 'csv.writer'


PracticeId = 195900

function main() 
   local A = athena.connect{username=config.username, password=config.password, cache=true}
   
   local Patients
   -- If we had a real instance of Athena Health then we would register this practice ID
   -- A.patients.patients.changed.subscription.add{practiceid=PracticeId}
   -- Then the patients.changed 
   Patients = A.patients.patients.changed.read{practiceid=195900,leaveunprocessed=iguana.isTest()}
 
   -- For a real athena health instance you'd like want to get rid of this line since we
   -- are querying male patients who last name is "Smith"
   Patients = A.patients.patients.read{practiceid=PracticeId,sex='M', lastname='Smith'}

       
   -- In this case we push the patients into the queue and we'll process them downstream.
   if #Patients.patients == 0 then
      iguana.logInfo("We have no patients that have been updated.")
      return 
   end
   
   -- Set up the headers.
   local Headers = csv.formatHeaders(Patients.patients[1])
   -- Then the body of the CSV export
   local Data = ''
   for i=1, #Patients.patients do
      local Line = csv.formatLine(Patients.patients[i])
      Data = Data..Line.."\n"
   end
   -- Put all the content together
   local Content = Headers .. '\n'..Data
   trace(Content) -- Have a look to see if it okay
   -- Make a temporary file - time stamp and great big GUID :-) adapt as you will.
   local FileName = os.ts.date('%Y-%b-%d-%H:%M:%S')..util.guid(128)
   csv.writeFileAtomically(FileName, Content)
end

