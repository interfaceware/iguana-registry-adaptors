local patientApi = require 'resources.patients'
local athenaAPI = require 'athena.util' 
-- Note: Require module to import any api resources folder

-- **************************************************** --
-- Sample Channel to interact with Athenahealth API server
-- Last Updated: Aug, 2021
-- **************************************************** --

-- Note for Preview, use practiceID 195900 for all Ambulatory only testing
-- and practiceID 1128700 for all Hospital/Health System testing
-- https://docs.athenahealth.com/api/sandbox
local practiceId = '1128700' 

--(1) Initial Athenahealth API Account Setup 
--    Create Athenahealth User Account on https://developer.api.athena.io/ams-portal/

--(2) Update athena Clent ID and ClientSecret in the athena/util.lua module

--(3) If using a Production app, update the appType in the athena/api.lua module to 'Production'
--    If using the Preview app, leave it as is

--(4) Verify athena/athena_source.lua is up-to-date with current Athenahealth API schema

--(5) Connect athenaAPI
local api = athenaAPI.getAthenaAPI()

function main(Data)       
   -- (1) Search for a Patient
   local patientInfo = patientApi.getPatientList(api, practiceId, 'Mickey', 'Mouse')
   local totalPatients = patientInfo.totalcount
   local patientId
   for i=1, totalPatients do
      patientId = patientInfo.patients[i].patientid
      trace(patientId)
   end
   
   -- (2) Update a Patient's address information
   local R = patientApi.updatePatientAddress(api, practiceId, patientId, '10', 'Steele Street', 'New Jersey', '16427')
   trace(R[1].patientid)
   
   -- (3) Read a Patient   
   local patientInfo = patientApi.getPatientInfo(api, practiceId, patientId)
   trace(patientInfo)
   
   -- (4) Create a New Patient
   -- Note: Athenahealth Preview api does not provide delete patient api, uncomment line #45 to test create patient api
   local inboundMsg = json.parse{data=Data}
   --local new_patientId = patientApi.createNewPatient(api, inboundMsg)
end