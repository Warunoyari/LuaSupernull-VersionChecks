;; ECX=sctrl string
;; 1.1b1: entry point = 0x004485D5
;; 1.1b1: stricmp = [0x004DE1FC]
[bits 32]

;; Area References
  dd .AddressData
  dd .StringData

;; compare the input to the LuaExec state controller string
lea ecx,dword [esp+0x20]
push ecx
.LuaExec_RewriteString:
  push luaexec
call dword [0x004DE1FC]
add esp,0x08
;; if equal, read value as a string
test eax,eax
je .lua_string

;; compare the input to the LuaFile state controller string
lea ecx,dword [esp+0x20]
push ecx
.LuaFile_RewriteString:
  push luafile
call dword [0x004DE1FC]
add esp,0x08
;; if equal, read value as file
test eax,eax
je .lua_file

;; if neither matched, sctrl is invalid
lea ecx,dword [esp+0x20]
push ecx
push 0x004F82D0 ;; "Not a valid elem type: %s"
mov eax,0x004485DB
jmp eax ;; continue with error handler

.lua_string:
push 0x161
jmp .lua_readparam

.lua_file:
push 0x162

.lua_readparam:
.LuaString_RewriteString:
  push luastring
push ebp
mov eax,0x0046A5E0 ;; this function finds the address for the start of the input string
call eax
add esp,0x08
test eax,eax ;; on error, the lua property does not exist - custom error handler
jnz .lua_parseparam
;; error handler
pop eax
lea eax,[esp+0x20]
push eax
.LuaProperty_RewriteString:
  push luamissing
mov eax,0x0044861F
jmp eax

.lua_parseparam:
push eax
mov eax,0x0045AF40 ;; this function interprets the input string as a format string (re-uses the DtC processing here) -- in the future, might be better if this was done differently
call eax
add esp,0x04
test eax,eax ;; on error, there may be an issue with the input string - pass to regular DtC error handler
jnz .lua_storeparam
;; error handler
pop eax
mov eax,0x00444FEE
jmp eax

.lua_storeparam:
mov dword [ebx + 0x60],eax ;; store the string in the state controller structure
pop eax
mov dword [ebx + 0x10],eax ;; store the state controller ID in the state controller structure
mov eax,0x004472C2 ;; return to sctrl processing
jmp eax

;; Areas for Writing (defined here)
.AddressData: 
  dd .LuaExec_RewriteString
  dd .LuaFile_RewriteString
  dd .LuaProperty_RewriteString
  dd .LuaString_RewriteString

;; Strings for Loading
.StringData:
  dd .LuaExecString
  dd .LuaFileString
  dd .LuaPropertyString
  dd .LuaString

.LuaExecString:
  db "LuaExec", 0x00
.LuaFileString:
  db "LuaFile", 0x00
.LuaPropertyString:
  db "lua property not specified for %s.", 0x0D, 0x0A, 0x00
.LuaString:
  db "lua", 0x00

;; 
luaexec db "LuaExec", 0x00
luafile db "LuaFile", 0x00
luamissing db "lua property not specified for %s.", 0x0D, 0x0A, 0x00
luastring db "lua", 0x00