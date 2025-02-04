;;;; lualoader.asm: function which is called during DisplayToClipboard, and conditionally launches some Lua function from the calling character's folder.
;;;;                it's pretty messy so it deserves some revision later.
;; at entry, EAX=the input string, EBP=the character data pointer
[bits 32]

;; Area References
  dd .AddressData
  dd .StringData
;; VERSION NUMBER, ONLY INCREASE if making change to official respository.
;; For personal changes, please implement them at runtime via LuaFile without modifying this number.  

push eax
;; inspect the input string to check if it starts with `!lua `
cmp byte [eax+0],0x21
jne .nolua
cmp byte [eax+1],0x6C
jne .nolua
cmp byte [eax+2],0x75
jne .nolua
cmp byte [eax+3],0x61
jne .nolua
cmp byte [eax+4],0x20
jne .nolua

;; check if the player has been custom stated
;; read the stateowner index, which will be -1 if not custom stated
mov ecx, dword [ebp + 0xCB8]
cmp ecx, -1
je .not_custom_stated
;; read the info pointer of the state owner
mov edx, dword [0x5040E8]
lea edx, dword [edx + 0x12274 + ecx * 0x04]
mov edx, dword [edx]
mov ecx, dword [edx]
push ecx
jmp .read_folder

.not_custom_stated:
push dword [ebp]
mov ecx, dword [ebp]

.read_folder:
;; fetch the character folder string
mov ecx, dword [ecx+0xB0]
xor esi,esi
;; copy the input string to the character folder string
.loopfindend:
cmp byte [ecx], 0x00
je .loopfindenddone
inc ecx
inc esi
jmp .loopfindend

.loopfindenddone:
;; point eax to the file to be loaded
add eax,0x05

.loopcopy:
mov dl, byte [eax]
mov byte [ecx], dl
inc eax
inc ecx
cmp byte [eax], 0x00
je .loopcopydone
jmp .loopcopy

.loopcopydone:
mov byte [ecx], 0x00
;; call the file loading function
pop ecx
mov ecx, dword [ecx+0xB0]
push ecx
mov ecx,dword [0x005040FC]
push ecx
mov ecx, 0x004C6250 ;; luaL_loadfile
call ecx
;; cleanup+test for errors
lea ecx,[esp+0x04]
mov ecx, dword [ecx]
add ecx, esi
mov byte [ecx], 0x00
add esp,0x08
test eax,eax
jnz .error

;; put our character's ID into a Lua global variable
mov ecx,dword [ebp+4]
push ecx
mov ecx, dword [0x005040FC]
push ecx
mov ecx,0x004C4FD0 ;; lua_pushinteger(L, ID)
call ecx 
add esp,0x08
.CharID_RewriteString:
  push charid
push -10002
mov ecx, dword [0x005040FC]
push ecx
mov ecx, 0x004C5460 ;; lua_setfield(L, LUA_GLOBALSINDEX, "charID")
call ecx
add esp,0x0C

;; call the file execution function
mov ecx,dword [0x005040FC]
push 0
push 0
push 0
push ecx
mov ecx, 0x004C5740 ;; lua_pcall
call ecx
;; cleanup+test for errors
add esp,0x10
test eax,eax
jnz .error

jmp .done

.error:
.ErrorExecute_RewriteString:
  push errmsg
mov ecx, 0x0040C710 ;; mugen error handler (clipboard print)
call ecx
add esp,0x04
jmp .done

.nolua:
pop eax ;; awkward thing just to make sure the printf is valid...
pop ebx ;; preserve return address...
call dword [0x004DE29C] ;; _snprintf
push ebx
push eax

.done:
pop eax
ret

;; Areas for Writing
.AddressData: 
  dd .CharID_RewriteString
  dd .ErrorExecute_RewriteString

;; Strings for Loading
.StringData:
  dd .CurrCharacterIDString
  dd .ErrorExecuteString

.CurrCharacterIDString:
  db "CurrCharacterID", 0x00
.ErrorExecuteString:
  db "Error while executing Lua from %s: %s.", 0x0D, 0x0A, 0x00


;; 
errmsg db "Error while loading Lua file from command '%s'.", 0x0D, 0x0A, 0x00
charid db "CurrCharacterID", 0x00