local practiceconfig = {}

--EXAMPLE: GET available practice IDs /v1/{practiceid}/practiceinfo
function practiceconfig.getPracticeInfo(api, practiceId)
   local practice = api["practice configuration"].practiceinfo.read{practiceid = practiceId}
   return practice
end
return practiceconfig