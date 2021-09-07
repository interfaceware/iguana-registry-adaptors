local chart = {}

-- EXAMPLE GET /v1/{practiceid}/chart/{patientid}/allergies
function chart.getPatientAllergies(api, practiceId, patientId, departmentId)
   local contracts = api.chart.chart.patientid.allergies.read{
      practiceid= practiceId,patientid=patientId,departmentid=departmentId}
   return contracts
end

return chart