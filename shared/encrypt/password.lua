-- This module is a helpful utility if your script needs to use
-- a password that you don't want to appear in the lua code that
-- is saved in a repository.

-- The code uses AES encryption https://en.wikipedia.org/wiki/Advanced_Encryption_Standard

-- http://help.interfaceware.com/v6/encrypt-password-in-file

local config = {}

local XmlSaveFragment=[[
<config password='' salt=''/>
]]

local function LoadFile(FileName)
   local F = io.open(FileName, "r")
   if not F then
      return nil
   end
   local C = F:read("*a")
   F:close()
   return C
end

local function SaveFile(FileName, Content)
   local F = io.open(FileName, "w")
   F:write(Content)  
   F:close()
end

function config.load(T)
   local Config = T.config
   local Key = T.key
   local Data=LoadFile(Config)
   if not Data then
      return "No password file saved"
   end
   local X = xml.parse{data=Data}
   local Salt = X.config.salt:S()
   local TotalKey = filter.base64.enc(crypto.digest{data=Key .. Salt,algorithm='SHA512'}):sub(1,32)
   local Password = X.config.password:S()
   Password = filter.base64.dec(Password)
   Password = filter.aes.dec{data=Password, key=TotalKey}
   -- If we have a short password need to get rid
   -- of \0 padding.
   for i=#Password, 1, -1 do
      if Password:byte(i) ~= 0 then
         Password = Password:sub(1, i)
         break
      end
   end
   return Password
end

local Comment=[[
<!-- This config file was saved with the config.load -->
]]

local XmlSaveFragment=[[
<config password='' salt=''/>
]]

function config.save(T)
   local Config   = T.config
   local Password = T.password
   local Key      = T.key
   local Salt     = util.guid(128)
   local TotalKey = filter.base64.enc(crypto.digest{data=Key .. Salt,algorithm='SHA512'}):sub(1,32)
   local X        = xml.parse{data=XmlSaveFragment}
   
   local EncryptedPassword = filter.aes.enc{data=Password, key=TotalKey}
   EncryptedPassword = filter.base64.enc(EncryptedPassword)
   
   X.config.salt = Salt
   X.config.password = EncryptedPassword
   
   local Content = Comment..X:S()
   SaveFile(Config, Content)
end

local LoadHelp=[[{
   "Returns": [{"Desc": "The decrypted password <u>string</u>."}],
   "SeeAlso": [
      {
         "Title": "Source code for the encrypt.password.lua module on github",
         "Link": "https://github.com/interfaceware/iguana-tools/blob/master/shared/encrypt/password.lua"
      },
      {
         "Title": "Encrypt Password in File",
         "Link": "http://help.interfaceware.com/v6/encrypt-password-in-file"
      }
   ],
   "Title": "config.load",
   "Parameters": [
      { "config": {"Desc": "Name of the configuration file to load <u>string</u>."}},
      { "key": { "Desc": "Key used to decrypt the password in the file <u>string</u>."}}],
   "ParameterTable": true,
   "Usage": "config.load{config=&lt;filename&gt;, key=&lt;decryption key&gt;}",
   "Examples": [
      "--Save the config file - but do not leave this line in the script
config.save{password='my password',config='acmeapp', key='skKddd223kdS'}<br>
-- Load the password previously saved to the configuration file
local Password = config.load{config='acmeapp', key='skKddd223kdS'}"
   ],
   "Desc": "This function loads an encrypted password from the specified file in the configuration directory of Iguana that was saved using the config.save{} function"
}]]

help.set{input_function=config.load, help_data=json.parse{data=LoadHelp}}

local SaveHelp=[[{
   "Returns": [],
   "SeeAlso": [
      {
         "Title": "Source code for the encrypt.password.lua module on github",
         "Link": "https://github.com/interfaceware/iguana-tools/blob/master/shared/encrypt/password.lua"
      },
      {
         "Title": "Encrypt Password in File",
         "Link": "http://help.interfaceware.com/v6/encrypt-password-in-file"
      }
   ],
   "Title": "config.save",
   "Parameters": [
      { "password": { "Desc": "The password to save in the file <u>string</u>."}},
      { "config": {"Desc": "Name of the configuration file to save to <u>string</u>."}},
      { "key" : { "Desc": "Key used to encrypt the saved password <u>string</u>."}}],
   "ParameterTable": true,
   "Usage": "config.save{password=&lt;password&gt;, config=&lt;filename&gt;, key=&lt;encryption key&gt;}",
   "Examples": [
      "--Save the config file - but do not leave this line in the script
config.save{password='my password',config='acmeapp', key='skKddd223kdS'}<br>
-- Load the password previously saved to the configuration file
local Password = config.load{config='acmeapp', key='skKddd223kdS'}"
   ],
   "Desc": "This function encrypts and saves a password to the specified file located in the configuration directory of Iguana."
}
]]

help.set{input_function=config.save, help_data=json.parse{data=SaveHelp}}

return config
