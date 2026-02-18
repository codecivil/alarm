#!/bin/lua
-- This is in /usr/bin
-- and is called by the button as get://[AP_IP]:40080/cgi-bin/detect_alarm.lua?[CLOAKED_MAC]
-- if the mac is not cloaked then the myStrom buttons will issue an alarm everytime they reconnect
-- (what they tried every 12h if you do not allow to connect)

-- Thanks to tonypdmtr in https://stackoverflow.com/questions/28916182/parse-parameters-out-of-url-in-lua
function urldecode(s)
  s = s:gsub('+', ' ')
       :gsub('%%(%x%x)', function(h)
                           return string.char(tonumber(h, 16))
                         end)
  return s
end

function parseurl(s)
  s = s:match('%s+(.+)')
  local ans = {}
  for k,v in s:gmatch('([^&=?]-)=([^&=?]+)' ) do
    ans[ k ] = urldecode(v)
  end
  return ans
end
--

_mac = parseurl(os.getenv("QUERY_STRING")).mac
_action = parseurl(os.getenv("QUERY_STRING")).action
if (_action ~= "2" ) then
  os.execute("/usr/bin/detect_alarm.sh wlan0 AP-STA-CONNECTED " .. _mac)
end
if (_action == "2" ) then
  os.execute("/usr/bin/remove_alarm.sh wlan0 AP-STA-CONNECTED " .. _mac)
end
os.exit
