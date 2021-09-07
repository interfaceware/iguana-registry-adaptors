local appointments = {}

-- EXAMPLE: GET /appointmentcancelreasons /preview1/:practiceid/appointmentcancelreasons
function appointments.getCancelReasons(api, practiceId)
   local reasons = api.appointments.appointmentcancelreasons.read{practiceid= practiceId}
   return reasons
end

return appointments