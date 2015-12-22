require 'stringutil'
require 'jsonhelp'
require 'database'
-- In this channel we process the patients we get off the wire.
-- We'll enter the data into a set of database tables.  The database
-- tables are defined in a schema file called a 'vmd file'.
--
-- This can edited using a windows program called Chameleon that comes with Iguana.


function GetDatabase()
   return db.connect{api=db.SQLITE, name='patient_info'}
end
   
function main(Data)
   InitDb()
   local Patient = json.parse{data=Data}
   -- We instantiate a set of table rows to populate
   local T = db.tables{vmd='athena.vmd', name='Tables'}
   MapPatient(T.Patient[1], Patient)
   trace(T)
   local Database = GetDatabase()
   Database:merge{data=T}
end

-- Convert date from DD/MM/YYYY -> YYYY-MM-DD
function ConvertDate(ADate)
   local Year = ADate:sub(-4)
   local Month = ADate:sub(1,2)
   local Day = ADate:sub(4,5)
   
   return Year..'-'..Month..'-'..Day
end

function CheckNull(V)
   if V == json.NULL then
      getmetatable(V)
      return nil
   end
   return V
end

function MapPatient(T, P)
   T.PatientId = P.patientid
   T.FirstName = P.firstname
   T.LastName = P.lastname
   T.MiddleName = P.middlename
   T.Sex = P.sex
   T.Address1 = P.address1
   T.Dob = ConvertDate(P.dob)
   T.Zip = P.zip
   T.City = P.city
   T.DriversLicense = P.driverslicense:n()
   T.ContactMobilePhone = P.contactmobilephone:n()
   T.MiddleName = P.middlename
   T.ContactMobilePhone = P.contactmobilephone:n()
   T.EmployerPhone = P.employerphone:n()
   T.NextKinPhone = P.nextkinphone:n()
   T.Ssn = P.ssn:n()
   T.MobilePhone = P.mobilephone
end


