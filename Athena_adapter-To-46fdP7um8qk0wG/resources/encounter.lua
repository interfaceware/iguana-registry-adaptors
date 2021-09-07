local encounter = {}

-- EXAMPLE: GET /v1/{practiceid}/chart/encounter/{encounterid}
-- Test value for EncounterId = 1
function encounter.getEncounterInfo(api, practiceId, encounterId)
   local info = api.chart.chart.encounter.encounterid.read{practiceid= practiceId, encounterid= encounterId}
   return info
end

return encounter