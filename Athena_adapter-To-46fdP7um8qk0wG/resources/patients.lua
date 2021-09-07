local patient = {}

-- API: GET /v1/{practiceid}/patients
function patient.getPatientList(api, practiceId, PatientFirstName, PatientLastName)
   local patientInfo = api.patient.patients.read{practiceid= practiceId, firstname= PatientFirstName, lastname = PatientLastName}
   -- return first patient info on the list
   return patientInfo
end


-- API: GET /v1/{practiceid}/patients/{patientid}
function patient.getPatientInfo(api, practiceId, PatientId)
   local patientInfo = api.patient.patients.patientid.read{practiceid= practiceId, patientid=PatientId}
   return patientInfo
end


-- API: POST /v1/{practiceid}/patients
function patient.createNewPatient(api, inboundMsg)   
   local patientInfo = api.patient.patients.add{
      practiceid = inboundMsg.PracticeID, 
      firstname = inboundMsg.PatientFirstName, 
      lastname = inboundMsg.PatientLastName, 
      dob= inboundMsg.DateOfBirth, 
      departmentid = inboundMsg.DepartmentID, 
      email = inboundMsg.email}
   -- return first patient info on the list
   
   return patientInfo
end

-- API: PUT /v1/{practiceid}/patients/{patientid}
function patient.updatePatientAddress(api, practiceId, PatientId, Address1, Address2, City, Zip)
   local patientInfo = api.patient.patients.patientid.update{practiceid= practiceId, 
      patientid= PatientId, 
      address1= Address1, 
      address2= Address2, 
      city= City, 
      zip= Zip}
   --return first patient info on the list
   return patientInfo
end


return patient