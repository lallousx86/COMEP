
                title   ".com files encryptor 'n' protector"

codestart       equ     100h            ; .com file start exec addr
params          equ     82h             ; parameter receiver
takedbytes      equ     45              ; bytes overwritten in .com file
jumpcode        equ     0E9h            ; machine code for jum instruction
maxfilesize     equ     0EA60h          ; maximum .com file size

comep           segment  'code'

                assume    cs:comep,ds:comep,ss:comep

                org       codestart

main            proc      near

                jmp       begin

main            endp
;----------------------------------------------------------------------------
begin:
                ;---------------------------- Display Copyright -------------
                mov     ah,9
                lea     dx,about
                int     21h
                ;---------------------------- Check If There Parameters -----
                mov     si,params            ;  get parameters
                mov     al,[si]              ;  check if theres
                cmp     al,00h               ;  at least one
                jne     loc_001              ;  found ?

                lea     dx,err_noparams      ;  display error
                call    haltprog             ;  and exit

      loc_001:  ; ** Continue if no Error **

                ;------------------------ Convert Parameter To file name -----
                call    getfile              ; convert parameter to file name

                ;------------------------------Open File 'n' Read to Buffer--
                lea     dx,comfilename       ; set up file
                call    openfile             ; open file

                jnc     loc_002              ; existing file ?
                lea     dx,err_filenotfound  ; display error message
                call    haltprog             ; and exit

      loc_002:  ; ** Continue if no Error **

                mov     comfilehandle,ax     ; save handle
                xchg    ax,bx                ; requested file
                mov     cx,maxfilesize       ; set up cx = max size of comfile
                lea     dx,combuffer         ; set up buffer for read
                call    readfile             ; read up the file
                mov     comfilesize,ax       ; save file size in readbytes
                cmp     ax,maxfilesize
                jbe     rep_001
                lea     dx,err_filelarge
                call    haltprog
                ;-------------- Encrypt the Buffer With a Random Key --------
      rep_001:
                mov     ah,2Ch               ; Req. Get System Time
                int     21h                  ; DoIt
                xor     ax,ax                ; Clear Ax
                add     al,ch                ; Add AL to hours
                add     al,dl                ; Add AL to mill. seconds
                mov     xorval,al            ; Random Key Generated and Stored
                call    encbuf               ; encrypt buffer using (xor loop)

                ;-------------------------------- Create temp file name------
                mov     ah,3Ch               ; create file
                sub     cx,cx                ; clear attributes => normal
                lea     dx,tempfilename      ; assign to file name
                int     21h                  ; ok DoIt
                xchg    ax,bx                ; put handle to bx
                mov     tempfilehandle,bx    ; put handel to tempfilename
                jnc     loc_003              ; if not error continue
                lea     dx,err_tmpcreate     ; Display Error
                call    haltprog             ; and exit

      loc_003:  ; ** Continue if no Error **

                ;---------------------------------- Save first few bytes-----
                cld                          ; left to right
                lea     di,comsavebuf        ; set up (di) to comsavebuf
                lea     si,combuffer         ; and (si) to copyied file buffer
                mov     cx,takedbytes        ; size = var ?
                repe    movsb                ; store them

                ;------------------------- Set up the JUMP SIZE before write---
                lea     si,combuffer         ; assign si to buffer
                mov     al,jumpcode          ; put the 'jump code' into al
                mov     [si],al              ; now put al to [si]
                mov     ax,comfilesize       ; put .com file size on ax
                add     ax,takedbytes        ; increase the jump location
                dec     al
                mov     [si+1],al            ; now the jump is set
                mov     [si+2],ah            ; to the end of file

                ;--------------------------- Set Up IDBytes -----------------
                lea     si,IdBytes           ;
                lea     di,combuffer+3       ;
                sub     bx,bx
                mov     cx,0FFh
      loc_009:
                movsb
                inc     bx
                cmp     byte ptr ds:[si],IdBytesEndMark
                jne     loc_009

                ;--------------------------- Write the temp file ------------
                mov     ah,40h               ; request write to file
                mov     bx,tempfilehandle    ; what file?
                mov     cx,comfilesize       ; set up the size
                lea     dx,combuffer         ; set up buffer
                int     21h                  ; ok write

                ;------------------------- Write at EOF the few taked bytes --
                mov     ah,40h               ; req. write to file
                lea     dx,comsavebuf        ; append to the end
                mov     cx,takedbytes        ; the takedbytes
                int     21h                  ; write them

                ;--------------------------- Write at EOF the file size -----
                mov     ah,40h               ; req. write to file
                lea     dx,comfilesize       ; file size
                mov     cx,2                 ; size of word
                int     21h                  ; DoIt

                ;-------------- Setup the Decryption Routine Appended Code ---
                mov     al,xorval            ; SetUp XorKey
                mov     code_xor_val,al      ; Store In CodeBlock

                mov     ax,comfilesize       ; load to ax comSaveBuf
                mov     code_scbuf,ax        ; Store In CodeBlock

                mov     ax,comfilesize       ; SetUp .com file size
                mov     code_cfsize,ax       ; Store In CodeBlock

                ;------------------ Write At EOF the Decryption  Routine -----
                lea     dx,dycbuf            ; set DX to DYC routine
                mov     ax,dx                ; and CX also
                lea     cx,enddycbuf         ; set AX to enddycbuf (indicating end of routine)
                sub     cx,ax                ; CX - AX = size of DYC routine
                mov     bx,tempfilehandle    ; Restore File Handle
                mov     ah,40h               ; req. write to file
                int     21h                  ; DoIt

                ;-------------------------- Close temp file -----------------
                mov     ah,3Eh               ; Close temp file
                int     21h                  ; And Write Changes
                jnc     loc_004              ; Create Ok

                lea     dx,err_tmpwrite      ; Display Error Message
                call    haltprog             ; And Exit

      loc_004:  ; ** Continue if no Error **

                ;----------------------------- Close .COM file --------------

                mov     ah,3eh               ; Close comfile
                mov     bx,comfilehandle     ; .com file
                int     21h                  ; DoIt

                ;------------------------------ Rename Files ----------------
                mov     ax,3D00h             ; Req. Open file
                lea     dx,tempfilename1     ; file 'temp.!!1'
                int     21h                  ; DoIt
                jc      loc_006              ; If not exists continue

                mov     ah,41h               ; Req. delete file
                lea     dx,tempfilename1     ; 'temp.!!1'
                int     21h                  ; DoIt

                jnc      loc_006             ; If Deleted Continue

                lea      dx,err_tmp1del      ; Display error Message
                call     haltprog            ; and Exit

      loc_006:  ; ** Continue Following Condition **

                mov     ah,56h               ; req. rename files

                push    ax                   ; save this command

                lea     dx,comfilename       ; .com file (as old)
                lea     di,tempfilename1     ; to 'temp.!!1'
                int     21h                  ; Ok Rename

                pop     ax                   ; rename
                lea     dx,tempfilename      ; 'temp.!!!' (as old)
                lea     di,comfilename       ; .com file name (as new)
                int     21h                  ; Ok Rename

                mov     ah,56h               ; rename
                lea     dx,tempfilename1     ; 'temp.!!1' (as old)
                lea     di,tempfilename      ; 'temp.!!!' (as old)
                int     21h                  ; Ok Rename

                ;------------------------------Exit to Dos -------------------
                call    exitproc             ; call exit


;------------------------------------- Convert parameters to file name-------
getfile:
                mov     si,params            ; load params to si
                sub     bx,bx                ; clear bx
      loop_001:
                mov     al,[si]              ; get 1st char
                mov     comfilename[bx],al   ; store it to comfiles[bx]
                inc     si                   ; increase index
                inc     bx                   ; increase comfiles index
                cmp     al,0Dh               ; al = CR
                je      loop_break_001       ; parameter 1 finished?
                cmp     al,20h               ; no ? loop_001
                je      loop_break_001       ; Continue
                jmp     loop_001
      loop_break_001:
                dec     bx                   ; replace CR or spc
                mov     comfilename[bx],0    ; with 00
                ret

;--------------------------------------- Encrypt Buffer Using Xor Loop ------
encbuf:
                lea     si,combuffer         ; load buffer
                mov     cx,comfilesize       ; set size of file
                mov     al,xorval            ; load to al to encryption key
      xor_loop_001:
                push    cx                   ; save CX

                mov     cl,al                ; cl = xorval

                ;--------------------------- Encryption Technices -----------
                xor     [si],cl              ; Encryption Methode
                not     word ptr [si]        ;

                inc     si                   ; increase index
                pop     cx
                loop    xor_loop_001         ; not finished : loop
                ret
;-------------------------- Dycrpt Buffer To mem form within file -----------
dycbuf:

                mov     dx,codestart         ; set up dx

                push    cs                   ; save cs
                push    cs                   ; save cs
                pop     es                   ; es = cs
                pop     ds                   ; ds = cs
                push    dx                   ; push it -> sp -= 2
                cld
                mov     di,dx                ; di = .com files start code


                db      0BEh                 ; mov si,code_comfilesize
   code_scbuf   dw      0FFFFh               ; this is redifiened up there

                add     si,dx                ; calculate si
                mov     cx,takedbytes        ; set up cx
                repe    movsb                ; restore the few taked bytes
                mov     si,dx                ; move si to codestart

                db      0B9h                 ; mov cx,code_comfilesize
    code_cfsize dw      0FFFFh               ; this is redefiened up there

                ;---------------------------- Dycryption Techniques ---------

                db      0B0h                 ; mov al,code_xor_val
   code_xor_val db      0FFh                 ; this is redifiened up there

      xor_loop_002:
                push    cx                   ; save loop value
                mov     cl,al                ; cl = xorval

                xor     [si],cl              ; Dycription method
                not     word ptr [si]        ;

                inc     si                   ; Increase Index
                pop     cx                   ; restore loop value
                loop    xor_loop_002         ; Loop Until Decrypted All the File

                db      0EBh,03h             ; jmp $+3
                db      0FEh,0Eh,0CAh,0C3h   ; dec byte ptr [CAC3] but 'ret' (0C3h)
                                             ; is nested in it ^^

                db      0B8h,00h,04Ch
                db      0CDh,021h            ; fake code = ( mov ah,4c // int 21 )

enddycbuf       db      0EEh                 ; this is neccessary to mark end of this routine

;----------------------------------------------------------------------------
haltprog:
                mov     ah,9
                int     21h
                call    exitproc

;---------------------------------------- Open a File And Exit If Not Found--
openfile:
                mov     ax,03D02h           ;  Open file
                int     21h                 ;  DoIt !
                ret                         ;  Return
;------------------------------------- Read File to Buffer -------------------
readfile:
                mov     ax,3F00h            ;  Read file:handle to Buffer in
                int     21h                 ;  ds:dx , cx sized
                ret                         ;

;-------------------------------- Exit Procedure ----------------------------
exitproc:
                mov     ax,4C00h            ;  exit to dos
                int     21h                 ;  exit code = al = 0
                ret                         ;  unreached code

;----------------------------------- Message Definitions --------------------
err_noparams     db      0Dh,0Ah,3 DUP ( 32 )
                 db      "Usage:",0Ah,08h
                 db      "COMEP <filename.com>",0Ah,0Dh,0Ah,0Dh,"$"

err_filenotfound db      "error - file not found!",0Ah,0Dh,"$"
err_tmpcreate    db      "error - TEMP.!!! not created!",0Ah,0Dh,"$"
err_tmpwrite     db      "error - can'nt create TEMP.!!!",0Ah,0Dh,"$"
err_tmp1del      db      "error - can'nt delete TEMP.!!1",0Ah,0Dh,"$"
err_filelarge    db      "error - too large .com file",0Ah,0Dh,"$"

IdBytes          db      3 DUP ( 8 ), 3 DUP ( 9 )
                 db      "COMEP 0.1a (c) Hacker's Fingers",26,IdBytesEndMark
IdBytesEndMark   equ     0EBh

about            db      0Ah,0Dh
                 db      "COMEP.COM version 0.1a (c) Copyright 1997 Hacker's Fingers Software",0Dh,0Ah
                 db      "An COM-files Encryptor and Protector By Elias Bachaalany.",0Dh,0Ah
                 db      "Protect your code and Encrypt Your Data Without Detriment to Its Work.",0Dh,0Ah,"$"

;------------------------------------- Buffers And Variables ----------------
checksum        dd        0
xorval          db        45h                ;  xor encryption key
tempfilehandle  dw        0                  ;  temp file handle
comfilehandle   dw        0                  ;  file handle
comfilesize     dw        0                  ;  com file size
comfilename     db        13    dup (0)      ;  file name string
tempfilename    db        "temp.!!!",0       ;  temp file name
tempfilename1   db        "temp.!!1",0       ;  temp file name
comsavebuf      db        takedbytes dup (0) ;  saved 1st 3 bytes
combuffer       db        90h                ;  buffer to copy file (should be last variable)

;----------------------------------------------------------------------------

ends            comep
                end             main


