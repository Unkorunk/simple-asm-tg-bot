NULL equ 0
INTERNET_OPEN_TYPE_PRECONFIG equ 0

  extern printf
  extern InternetOpenA
  extern InternetCloseHandle

  global main

  section .rodata

user_agent: db "Telegram Bot", 0
internet_open_status: db "Internet Open Status: %d", 0x0a, 0
internet_close_status: db "Internet Close Status: %d", 0x0a, 0

  section .text

main:
  sub rsp, 0x38

  lea RCX, [REL user_agent]             ; 1st arg - lpszAgent
  mov RDX, INTERNET_OPEN_TYPE_PRECONFIG ; 2nd arg - dwAccessType
  mov R8, NULL                          ; 3rd arg - lpszProxy
  mov R9, NULL                          ; 4th arg - lpszProxyBypass
  mov dword [RSP + 20], 0               ; 5th arg - dwFlags
  call InternetOpenA
  ; RAX - internet handler if ok else NULL

  mov R12, RAX ; save internet handler

  cmp R12, 0
  je internet_open_fail

  lea RCX, [REL internet_open_status] ; fmt string
  mov RDX, 1                          ; %d = 1
  call printf

  mov RCX, R12
  call InternetCloseHandle
  ; RAX - true if handler successfuly closed or false otherwise

  lea RCX, [REL internet_close_status] ; fmt string
  mov RDX, RAX                         ; true / false
  call printf

  jmp after_internet_open_fail
internet_open_fail:
  lea RCX, [REL internet_open_status] ; fmt string
  mov RDX, 0                          ; %d = 0
  call printf

after_internet_open_fail:

  add rsp, 0x38

  xor rax, rax
  ret
