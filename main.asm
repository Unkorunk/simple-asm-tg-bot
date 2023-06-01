NULL equ 0
INTERNET_OPEN_TYPE_PRECONFIG equ 0
INTERNET_DEFAULT_HTTPS_PORT equ 443
INTERNET_SERVICE_HTTP equ 3
INTERNET_FLAG_SECURE equ 0x00800000
INTERNET_FLAG_KEEP_CONNECTION equ 0x00400000

  ; C functions
  extern printf
  extern sprintf

  ; CRT
  extern __argc ; extern int __argc;
  extern __argv ; extern char ** __argv;

  ; WinAPI
  extern InternetOpenA
  extern InternetCloseHandle
  extern InternetConnectA
  extern HttpOpenRequestA
  extern HttpSendRequestA
  extern InternetReadFile

  global main

  section .rodata

invalid_count_of_args: db "Invalid count of args. Expected 2, but got %d", 0x0a, 0
user_agent: db "Telegram Bot", 0
internet_open_status: db "Internet Open Status: %d", 0x0a, 0
internet_close_status: db "Internet Close Status: %d", 0x0a, 0
internet_connect_status: db "Internet Connect Status: %d", 0x0a, 0
http_open_request_status: db "Http Open Request Status: %d", 0x0a, 0
http_send_request_status: db "Http Send Request Status: %d", 0x0a, 0
internet_read_file_status: db "InternetReadFile Status: %d", 0x0a, "Content:", 0x0a, "%s", 0x0a, 0
hostname: db "api.telegram.org", 0
request_method: db "GET", 0
http_version: db "HTTP/1.1", 0
application_json: db "application/json", 0
accept_types: dq application_json, NULL
endpoint_fmt: db "bot%s/%s", 0 ; 1st - token, 2nd - method and args
getMe: db "getMe", 0

  section .bss

endpoint_fmt_buffer: resb 1024 ; reserve 1024 bytes
internet_read_file_buffer: resb 1025 ; reserve 1024 bytes + 1 for null-ending for getting content
number_of_bytes_read: resq 1 ; reserve 1 dword for actually read bytes

  section .text

main:
  mov qword [REL number_of_bytes_read], 0

  ; NOTE: shadow space should be adj to the return address

  ; 8 bytes for allignment after func calling
  ; 32 bytes for shadow space (it's required by windows)
  ; 8 bytes for allignment after shadow space
  sub rsp, 0x48

  mov R12, [REL __argc]
  cmp R12, 2
  jne args_check_fail

  ; prepare getMe endpoint
  lea RCX, [REL endpoint_fmt_buffer]
  lea RDX, [REL endpoint_fmt]

  mov R8, [REL __argv]
  add R8, 0x08
  mov qword R8, [R8]

  lea R9, [REL getMe]
  call sprintf
  ; after that getMe endpoint in endpoint_fmt_buffer

  lea RCX, [REL user_agent]             ; 1st arg - lpszAgent
  mov RDX, INTERNET_OPEN_TYPE_PRECONFIG ; 2nd arg - dwAccessType
  mov R8, NULL                          ; 3rd arg - lpszProxy
  mov R9, NULL                          ; 4th arg - lpszProxyBypass
  mov qword [RSP + 0x20], 0             ; 5th arg - dwFlags
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
    mov qword [RSP + 0x28], INTERNET_SERVICE_HTTP ; dwService
    mov qword [RSP + 0x30], INTERNET_FLAG_SECURE  ; dwFlags (TODO: i don't sure should i specify here secure flag or not)
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

      ; open request
      mov RCX, R13                                                                   ; hConnect
      lea RDX, [REL request_method]                                                  ; lpszVerb
      lea R8, [REL endpoint_fmt_buffer]                                              ; lpszObjectName
      lea R9, [REL http_version]                                                     ; lpszVersion
      mov qword [RSP + 0x20], NULL                                                   ; lpszReferrer

      lea R14, [REL accept_types]
      mov [RSP + 0x28], R14                                                          ; lplpszAcceptTypes

      mov qword [RSP + 0x30], (INTERNET_FLAG_KEEP_CONNECTION | INTERNET_FLAG_SECURE) ; dwFlags
      mov qword [RSP + 0x38], NULL                                                   ; dwContext
      call HttpOpenRequestA
      ; RAX - request handler if ok or NULL otherwise

      mov R14, RAX ; save request handler

      ; if request handler != NULL
      cmp R14, NULL
      je http_open_request_fail
      ; then:

        ; report status
        lea RCX, [REL http_open_request_status]
        mov RDX, 1
        call printf

        ; send request
        mov RCX, R14              ; hRequest
        mov RDX, NULL             ; lpszHeaders
        mov R8, 0                 ; dwHeadersLength
        mov R9, NULL              ; lpOptional
        mov qword [RSP + 0x20], 0 ; dwOptionalLength
        call HttpSendRequestA
        ; RAX - true / false

        mov R15, RAX ; save status for future use

        ; report status
        lea RCX, [REL http_send_request_status]
        mov RDX, RAX
        call printf

        ; if [status of send request] == false
        cmp R15, 0
        je http_send_request_fail
        ; else:
          
          ; read 1024 bytes or less of data
          mov RCX, R14
          lea RDX, [REL internet_read_file_buffer]
          mov R8, 1024
          lea R9, [REL number_of_bytes_read]
          call InternetReadFile
          ; RAX - true / false

          ; add null ending
          lea R15, [REL internet_read_file_buffer]
          add R15, [REL number_of_bytes_read]
          mov byte [R15], 0

          ; print status & content
          lea RCX, [REL internet_read_file_status]
          mov RDX, RAX
          ; mov R8, [REL number_of_bytes_read]
          lea R8, [REL internet_read_file_buffer]
          call printf

http_send_request_fail:
        ; close request handler
        mov RCX, R14
        call InternetCloseHandle
        ; RAX - true if handler successfuly closed or false otherwise

        lea RCX, [REL internet_close_status] ; fmt string
        mov RDX, RAX                         ; true / false
        call printf

      jmp after_http_open_request_fail
http_open_request_fail:
      ; else:

        ; report status
        lea RCX, [REL http_open_request_status]
        mov RDX, 0
        call printf

after_http_open_request_fail:

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

    jmp after_args_check_fail
args_check_fail:

  lea RCX, [REL invalid_count_of_args]
  mov RDX, [REL __argc]
  call printf

after_args_check_fail:

  add rsp, 0x48

  xor rax, rax
  ret
