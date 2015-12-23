local csv = {}

function csv.formatHeaders(R)
   local Headers = ''
   for K, V in pairs(R) do
      if type(V) == 'string' or type(V) == 'number' then
         Headers = Headers .. '"'..K..'",'
      end
   end
   Headers = Headers:sub(1, #Headers-1)
   return Headers
end

local function escape(V)
   V = V:rxsub('\"', '""')
   return V
end

function csv.formatLine(R)
   local Line = ''
   for K,V in pairs(R) do
      if type(V) == 'string' then
         Line = Line .. '"'..escape(V)..'",'
      elseif type(V) == 'number' then
         Line = Line ..V..","    
      end
   end
   Line = Line:sub(1, #Line-1)
   return Line
end

-- We write to a temp file and rename it *after* we have finished writing the data.
function csv.writeFileAtomically(Name,Content)
   local FileNameTemp = Name..".tmp"
   local F = io.open(FileNameTemp, "w")
   F:write(Content)
   F:close()
   -- Atomically rename file once we are done!
   os.rename(FileNameTemp, Name)
end


return csv