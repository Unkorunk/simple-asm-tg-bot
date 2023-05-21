NULL equ 0
INTERNET_OPEN_TYPE_PRECONFIG equ 0
INTERNET_DEFAULT_HTTPS_PORT equ 443
INTERNET_SERVICE_HTTP equ 3
INTERNET_FLAG_SECURE equ 0x00800000

  extern printf
  extern InternetOpenA
  extern InternetCloseHandle
  extern InternetConnectA

  global main

  section .rodata

user_agent: db "Telegram Bot", 0
internet_open_status: db "Internet Open Status: %d", 0x0a, 0
internet_close_status: db "Internet Close Status: %d", 0x0a, 0
internet_connect_status: db "Internet Connect Status: %d", 0x0a, 0
hostname: db "api.telegram.org", 0

  section .text

main:
  ; NOTE: shadow space should be adj to the return address

  ; 8 bytes for allignment after func calling
  ; 32 bytes for shadow space (it's required by windows)
  ; 8 bytes for allignment after shadow space
  sub rsp, 0x48

  lea RCX, [REL user_agent]             ; 1st arg - lpszAgent
  mov RDX, INTERNET_OPEN_TYPE_PRECONFIG ; 2nd arg - dwAccessType
  mov R8, NULL                          ; 3rd arg - lpszProxy
  mov R9, NULL                          ; 4th arg - lpszProxyBypass
  mov dword [RSP + 0x20], 0             ; 5th arg - dwFlags
  call InternetOpenA
  ; RAX - internet handler if ok else NULL

  mov R12, RAX ; save internet handler

  ; if internet handler != NULL
  cmp R12, NULL
  je internet_open_fail
  ; then:

    ; report status
    lea RCX, [REL internet_open_status] ; fmt string
    mov RDX, 1                          ; %d = 1
    call printf

    ; open session
    mov RCX, R12                                  ; hInternet
    lea RDX, [REL hostname]                       ; lpszServerName
    mov R8, INTERNET_DEFAULT_HTTPS_PORT           ; nServerPort
    mov R9, NULL                                  ; lpszUserName
    mov qword [RSP + 0x20], NULL                  ; lpszPassword
    mov dword [RSP + 0x28], INTERNET_SERVICE_HTTP ; dwService
    mov dword [RSP + 0x30], INTERNET_FLAG_SECURE  ; dwFlags
    mov qword [RSP + 0x38], NULL                  ; dwContext
    call InternetConnectA
    ; RAX - session handler if ok or NULL otherwise

    mov R13, RAX ; save session handler

    ; if session handler != NULL
    cmp R13, NULL
    je internet_connect_fail
    ; then:

      ; report status
      lea RCX, [REL internet_connect_status]
      mov RDX, 1
      call printf

      ; close session handler
      mov RCX, R13
      call InternetCloseHandle
      ; RAX - true if handler successfuly closed or false otherwise

      lea RCX, [REL internet_close_status] ; fmt string
      mov RDX, RAX                         ; true / false
      call printf

    jmp after_internet_connect_fail
internet_connect_fail:
    ; else:

      ; report status
      lea RCX, [REL internet_connect_status]
      mov RDX, 0
      call printf

after_internet_connect_fail:

    ; close internet handler
    mov RCX, R12
    call InternetCloseHandle
    ; RAX - true if handler successfuly closed or false otherwise

    lea RCX, [REL internet_close_status] ; fmt string
    mov RDX, RAX                         ; true / false
    call printf

  jmp after_internet_open_fail
internet_open_fail:
  ; else:

    ; report status
    lea RCX, [REL internet_open_status] ; fmt string
    mov RDX, 0                          ; %d = 0
    call printf

after_internet_open_fail:

  add rsp, 0x48

  xor rax, rax
  ret
