.386                ; use 80386 instruction
FluidCube struct

diff real4 ?
deltat real4 ?
visc real4 ?
N dd 64

s real4 64*64 dup(0.0)
density real4 64*64 dup(0.0)
densityZ real4 64*64 dup(1.0)

Vx real4 64*64 dup(0.0)
Vy real4 64*64 dup(0.0)

Vx0 real4 64*64 dup(0.0)
Vy0 real4 64*64 dup(0.0)

FluidCube EndS
.model flat,stdcall ; uses flat memory addressing model % STDCALL as default calling convention
.stack 1000h
option casemap:none

include C:\masm32\include\windows.inc
include C:\masm32\include\kernel32.inc
include C:\masm32\include\user32.inc
include C:\masm32\include\gdi32.inc
include C:\masm32\include\masm32.inc
include \masm32\include\masm32rt.inc

includelib C:\masm32\lib\kernel32.lib   ; ExitProcess, GetCommandLineA, GetModuleHandleA
includelib C:\masm32\lib\user32.lib     ; BeginPaint, CreateWindowExA@, DefWindowProcA, DispatchMessageA, EndPaint, GetMessageA, InvalidateRect, LoadCursorA, LoadIconA, PostQuitMessage, RegisterClassExA, SetWindowTextA, ShowWindow, TranslateMessage, UpdateWindow
includelib C:\masm32\lib\gdi32.lib      ; CreatePen, LineTo, MoveToEx, SelectObject
includelib C:\masm32\lib\masm32.lib     ; dwtoa


.CONST
DRAWING equ 1
WAITING equ 0
R equ 0
G equ 1
B equ 2
RGBC equ 3
GRAY equ 4

.DATA
    ClassName db 'WinClass',0
    AppName db 'Fluid Simulator',0

    StaticClassName db 'static',0

    V db 'V', 2 dup (' ')
    VVal db '0.00001', 8 dup (?), 0
    Deltat db 'DT', 2 dup (' ')
    DeltatVal db '0.2', 12 dup (?), 0
    D db 'D', 2 dup (' ')
    DVal db '0.00001', 8 dup (?), 0 ; strings to print the fluid param labels

    state db WAITING
    moved db 0

    bcolor COLORREF 00111111h
    tempColor COLORREF 0

    cube FluidCube <0.0001, 0.2, 0.00001>
    DensityToAdd real4 150.0
    xVectorToAdd real4 2.0
    yVectorToAdd real4 2.0
    vectorNormalizer real4 0.4
    vectorDivisor real4 1.01

    consoleOutHandle dd ? 
    bytesWritten dd ? 
    message db "-----------------------------------------------------------------------------------------------------------------------",13,10
            db "|                                                                                                                     |",13,10
            db "|                                                                                                                     |",13,10
            db "|         _______________      ______________   ________                                 _____                        |",13,10
            db "|         ___  ____/__  /___  ____(_)_____  /   ___  __ \____  ______________ _______ ______(_)_____________          |",13,10
            db "|         __  /_   __  /_  / / /_  /_  __  /    __  / / /_  / / /_  __ \  __ `/_  __ `__ \_  /_  ___/_  ___/          |",13,10
            db "|         _  __/   _  / / /_/ /_  / / /_/ /     _  /_/ /_  /_/ /_  / / / /_/ /_  / / / / /  / / /__ _(__  )           |",13,10
            db "|         /_/      /_/  \__,_/ /_/  \__,_/      /_____/ _\__, / /_/ /_/\__,_/ /_/ /_/ /_//_/  \___/ /____/            |",13,10
            db "|                                                       /____/                                                        |",13,10
            db "|                                                                                                                     |",13,10
            db "|                                      ~~~~~~~~~~~~~~~ CONTROLS ~~~~~~~~~~~~~~~                                       |",13,10
            db "|                                                                                                                     |",13,10
            db "| TOGGLE VISCOSITY (V)..................................... UP ARROW (HIGHER VISCOSITY) / DOWN ARROW (LOWER VISCOSITY)|",13,10
            db "|                                                                                                                     |",13,10
            db "| TOGGLE TIMESTEP (DT) (HOW MUCH TIME PASSES EACH FRAME) .. RIGHT ARRROW (FASTER) / LEFT ARROW (SLOWER)               |",13,10
            db "|                                                                                                                     |",13,10
            db "| TOGGLE DIFFUSION RATE (D) .................................. + (HIGHER) / - (LOWER)                                 |",13,10
            db "|                                                                                                                     |",13,10
            db "| CHANGE COLOR MODE TO GRAYSCALE ......................... 1                                                          |",13,10
            db "|                                                                                                                     |",13,10
            db "| CHANGE COLOR MODE TO RED ............................... 2                                                          |",13,10
            db "|                                                                                                                     |",13,10
            db "| CHANGE COLOR MODE TO GREEN ............................. 3                                                          |",13,10
            db "|                                                                                                                     |",13,10
            db "| CHANGE COLOR MODE TO BLUE .............................. 4                                                          |",13,10
            db "|                                                                                                                     |",13,10
            db "| CHANGE COLOR MODE TO RGB TRANSITIONS ................... 5                                                          |",13,10
            db "|                                                                                                                     |",13,10
            db "|                                                                                                                     |",13,10
            db "-----------------------------------------------------------------------------------------------------------------------",13,10
    message2 db "ddddddddddddddddddddd",13,10 ; TODO - REMOVE THIS PART WHEN REMOVING dPrintToConsole
    gridLengthX dd 1
    gridLengthY dd 1

    bPercentage dd 255
    gPercentage dd 0
    rPercentage dd 0

    colorCounter dd 0
    repCounter dd 1
    floatSave dq ?
    
    mode dd GRAY


.DATA?
    hInstance HINSTANCE ?
    CommandLine LPSTR ?
    hitpoint POINT <>
    lastpoint POINT <>

    wc WNDCLASSEX <?>
    msg MSG <?> ; handle message
    hwnd HWND ? ; handle window procedure

    hwndV HWND ?
    hwndDT HWND ?
    hwndD HWND ?

    ps PAINTSTRUCT <?>

    hPen HPEN ? ; TODO - MAYBE REMOVE BECAUSE IT'S ONLY USED IN COMMENTED GRIDLINE DRAWING PART?

.CODE

IX proc ;x:dword, y:dword, N:word
    ; bp+4 = x, bp+6 = y, bp+8 = N
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push edx

    mov eax, [ebp+8]
    mov ebx, 4
    mul ebx ; multiplying by 4 to get it to dword add and not byte-wise
    mov [ebp+8], eax

    mov eax, [ebp+12] ; y
    mov ebx, 4
    mul ebx ; multiplying by 4 to get it to dword add and not byte-wise
    mov ebx, 0 
    mov ebx, [ebp+16] ; N
    mul ebx ; get row number in ax, since we're using a 1D array as a 2D one.

    mov ebx, [ebp+8] ; x
    add eax, ebx ; add x value to ax, to get it to point to the correct position.

    mov [ebp+16], eax

    pop edx
    pop ebx
    pop eax
    pop ebp

    ret 8
IX endp

addDensity proc cube_density:dword, N:dword, x:dword, y:dword, amount:real4
    ; bp+4 = cube add, bp + 6 = x, bp+8 = y, bp+10 = amount (in case I regret the invoke and change it to a normal proc call
    ;address is dword since the memory is 32-bit
    push ebx
    push eax

    push N
    push y
    push x

    call IX

    pop ebx
    add ebx, cube_density

    mov eax, amount
    fstp st(0)
    fld real4 ptr [ebx] ; loading the original value that we need to add to
    push eax
    fadd real4 ptr [esp]

    mov eax, 254
    push eax
    ficom real4 ptr [esp]
    fstsw ax          ;copy the Status Word containing the result to AX
    fwait             ;insure the previous instruction is completed
    sahf              ;transfer the condition codes to the CPU's flag register
    ja skipAdd
    fst real4 ptr [esp] ; pushing eax and storing the added value in the stack as to save it later
    mov eax, real4 ptr [esp]
    mov real4 ptr [ebx], eax ; storing the new value inside the addr
    skipAdd:


    pop eax ; popping to preserve stack

    pop eax
    pop ebx

    ret
addDensity endp

addVelocity proc Vx:dword, Vy:dword, N:dword, x:dword, y:dword, amountx:real4, amounty:real4
    push edi
    push ebx
    push eax

    push N
    push y
    push x

    call IX

    pop ebx
    mov edi, ebx

    add ebx, Vx
    add edi, Vy

    mov eax, amountx
    fstp st(0)
    fld real4 ptr [ebx] ; loading the original value that we need to add to
    push eax
    fadd real4 ptr [esp]
    fst real4 ptr [esp] ; pushing eax and storing the added value in the stack as to save it later
    mov eax, real4 ptr [esp]
    mov real4 ptr [ebx], eax ; storing the new value inside the addr

    pop eax ; popping to preserve stack

    mov eax, amounty
    fstp st(0)
    fld real4 ptr [edi] ; loading the original value that we need to add to
    push eax
    fadd real4 ptr [esp]
    fst real4 ptr [esp] ; pushing eax and storing the added value in the stack as to save it later
    mov eax, real4 ptr [esp]
    mov real4 ptr [edi], eax ; storing the new value inside the addr

    pop eax ; popping to preserve stack

    pop eax
    pop ebx
    pop edi

    ret
addVelocity endp

diffuse proc
    ; diffusion part - making the appropriate calculations
    ; Inputs -  cube member addresses in the following order:
    ; b value, vel, vel0, diff, dt, iter, N (With b value as the last push)
    ; Outputs - nothing

    ; TODO - get good values for dt and diff to make sure that it's doing what it's supposed to

    push ebp
    mov ebp, esp

    push eax
    push ebx

    fstp st(0)
    mov ebx, [ebp + 24]
    fld real4 ptr [ebx] ; dt
    mov ebx, [ebp + 20]
    fmul real4 ptr [ebx] ; diff
    mov ebx, [ebp + 32]
    mov ebx, dword ptr [ebx]
    sub ebx, 2
    push ebx ; pushing n - 2
    fimul dword ptr [esp]
    fimul dword ptr [esp] ; multiplying dt * diff * (N - 2) * (N - 2)
    pop ebx ; popping back to preserve stack

    ; setting up FPU pops to get the final calculated value in st and
    ; also do some more calcs on a (and push them)
    push eax ; redundancy push to save the a val inside
    fst real4 ptr [esp] ; a
    mov eax, 4
    push eax
    fimul dword ptr [esp]
    pop eax
    mov eax, 1
    push eax
    fiadd dword ptr [esp]
    pop eax
    push eax ; redundancy push to save the c val inside
    fst real4 ptr [esp] ; a * 4 + 1 (c val)
    mov eax, [ebp + 32] ; N
    push eax
    mov eax, [ebp + 28]; iter
    push eax
    mov eax, [ebp + 16] ; vel0
    push eax
    mov eax, [ebp + 12] ; vel
    push eax
    mov eax, [ebp + 8] ; b val
    push eax
    call linSolve

    pop ebx
    pop eax

    pop ebp
    ret 28
diffuse endp

project proc
    ; makes sure that there is no divergence in the velocity vector fields - takes the current field, subtracts the curl-free one from it, and then gets one with onyl curl.
    ; Inputs - Vx (+8), Vy (+12), p (+16), div (+20), iter (+24), N (+28)
    ; Outputs - nothing
    push ebp
    mov ebp, esp

    push eax
    push ebx
    push ecx
    push edx

    mov eax, dword ptr [ebp + 28]
    mov eax, dword ptr [eax] ; eax = N
    sub eax, 1 ; eax = N - 1
    mov ecx, 1 ; ecx = i = 1
    projectLoop1:
        push eax
        push ecx
        mov edx, 1 ; edx = j = 1
        projectLoop2:
            push eax
            push edx

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            push edx ; y: j
            add ecx, 1
            push ecx ; x: i + 1
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 8] ; ebx is pointing to Vx[i+1, j]
            sub ecx, 1 ; resetting ecx to ecx = i

            fstp st(0)
            fld real4 ptr [ebx] ; st(0) = Vx[i+1, j]

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            push edx ; y: j
            sub ecx, 1
            push ecx ; x: i - 1
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 8] ; ebx is pointing to Vx[i - 1, j]
            add ecx, 1 ; resetting ecx to ecx = i

            fsub real4 ptr [ebx] ; st(0) = Vx[i+1, j] - Vx[i-1, j]

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            add edx, 1
            push edx ; y: j + 1
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 12] ; ebx is pointing to Vy[i, j + 1]
            sub edx, 1 ; resetting edx to edx = j

            fadd real4 ptr [ebx] ; st(0) = Vx[i+1, j] - Vx[i-1, j] + Vy[i, j + 1]

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            sub edx, 1
            push edx ; y: j - 1
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 12] ; ebx is pointing to Vy[i, j - 1]
            add edx, 1 ; resetting edx to edx = j

            fadd real4 ptr [ebx] ; st(0) = Vx[i+1, j] - Vx[i-1, j] + Vy[i, j + 1] - Vy[i, j - 1]

            mov ebx, -2
            push ebx
            fidiv dword ptr [esp] ; st(0) = (Vx[i+1, j] - Vx[i-1, j] + Vy[i, j + 1] - Vy[i, j - 1]) / (-2)
            pop ebx

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx
            fidiv dword ptr [esp] ; st(0) = ((Vx[i+1, j] - Vx[i-1, j] + Vy[i, j + 1] - Vy[i, j - 1]) / (-2)) / N
            pop ebx

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            push edx ; y: j
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 20] ; ebx is pointing to div[i, j]
            fst real4 ptr [ebx] ; div[i, j] = ((Vx[i+1, j] - Vx[i-1, j] + Vy[i, j + 1] - Vy[i, j - 1]) / (-2)) / N

            fstp st(0)
            mov ebx, 0
            push ebx
            fild dword ptr [esp] ; st(0) = 0
            pop ebx

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            push edx ; y: j
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 16] ; ebx is pointing to p[i, j]
            fst real4 ptr [ebx] ; p[i, j] = 0



            pop edx
            pop eax
            add edx, 1
            cmp edx, eax ; exit if j >= eax (eax = N - 1) (j++)
        jb projectLoop2 ; inner loop
        pop ecx
        pop eax
        add ecx, 1
        cmp ecx, eax ; exit if i >= eax (eax = N - 1) (i++)
    jb projectLoop1 ; outer loop


    ; CLEANING UP ---------------------
    
    mov ebx, dword ptr [ebp + 28]
    push ebx ; N
    mov ebx, dword ptr [ebp + 20]
    push ebx ; div
    mov ebx, 0
    push ebx ; b value = 0
    call setBnd

    mov ebx, dword ptr [ebp + 28]
    push ebx ; N
    mov ebx, dword ptr [ebp + 16]
    push ebx ; p
    mov ebx, 0
    push ebx ; b value = 0
    call setBnd

    mov ebx, 1
    push ebx ; a value
    fstp st(0)
    fild dword ptr [esp]
    fst real4 ptr [esp]
    mov ebx, 6
    push ebx ; c value
    fstp st(0)
    fild dword ptr [esp]
    fst real4 ptr [esp]
    mov ebx, dword ptr [ebp + 28]
    push ebx ; N
    mov ebx, [ebp + 24]
    push ebx ; iter
    mov ebx, dword ptr [ebp + 20]
    push ebx ; div
    mov ebx, dword ptr [ebp + 16]
    push ebx ; p
    mov ebx, 0
    push ebx ; b value = 0
    call linSolve

    mov eax, dword ptr [ebp + 28]
    mov eax, dword ptr [eax] ; eax = N
    sub eax, 1 ; eax = N - 1
    mov ecx, 1 ; ecx = i = 1
    projectLoop3:
        push eax
        push ecx
        mov edx, 1 ; edx = j = 1
        projectLoop4:
            push eax
            push edx


            ; SETTING Vx[i, j] VALUE ---------------------------------

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            push edx ; y: j
            add ecx, 1
            push ecx ; x: i + 1
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 16] ; ebx is pointing to p[i+1, j]
            sub ecx, 1 ; resetting ecx to ecx = i

            fstp st(0)
            fld real4 ptr [ebx] ; st(0) = p[i+1, j]

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            push edx ; y: j
            sub ecx, 1
            push ecx ; x: i - 1
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 16] ; ebx is pointing to p[i - 1, j]
            add ecx, 1 ; resetting ecx to ecx = i

            fsub real4 ptr [ebx] ; st(0) = p[i+1, j] - p[i-1, j]
            
            mov ebx, -2
            push ebx
            fidiv dword ptr [esp] ; st(0) = (p[i+1, j] - p[i-1, j]) / (-2)
            pop ebx

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx
            fimul dword ptr [esp] ; st(0) = ((p[i+1, j] - p[i-1, j]) / (-2)) * N
            pop ebx

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            push edx ; y: j
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 8] ; ebx is pointing to Vx[i, j]
            fadd real4 ptr [ebx] ; st(0) = Vx[i, j] + ((p[i+1, j] - p[i-1, j]) / (-2)) * N
            fst real4 ptr [ebx] ; Vx[i, j] = Vx[i, j] + ((p[i+1, j] - p[i-1, j]) / (-2)) * N


            ; SETTING Vy[i, j] VALUE ---------------------------------
            

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            add edx, 1
            push edx ; y: j + 1
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 16] ; ebx is pointing to p[i, j+1]
            sub edx, 1 ; resetting edx to edx = i

            fstp st(0)
            fld real4 ptr [ebx] ; st(0) = p[i, j+1]

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            sub edx, 1
            push edx ; y: j - 1
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 16] ; ebx is pointing to p[i, j - 1]
            add edx, 1 ; resetting edx to edx = i

            fsub real4 ptr [ebx] ; st(0) = p[i, j+1] - p[i, j - 1]
            
            mov ebx, -2
            push ebx
            fidiv dword ptr [esp] ; st(0) = (p[i, j+1] - p[i, j - 1]) / (-2)
            pop ebx

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx
            fimul dword ptr [esp] ; st(0) = ((p[i, j+1] - p[i, j - 1]) / (-2)) * N
            pop ebx

            mov ebx, dword ptr [ebp + 28]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx ; N
            push edx ; y: j
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 12] ; ebx is pointing to Vy[i, j]
            fadd real4 ptr [ebx] ; st(0) = Vy[i, j] + ((p[i, j+1] - p[i, j - 1]) / (-2)) * N
            fst real4 ptr [ebx] ; Vy[i, j] = Vy[i, j] + ((p[i, j+1] - p[i, j - 1]) / (-2)) * N


            pop edx
            pop eax
            add edx, 1
            cmp edx, eax ; exit if j >= eax (eax = N - 1) (j++)
        jb projectLoop4 ; inner loop
        pop ecx
        pop eax
        add ecx, 1
        cmp ecx, eax ; exit if i >= eax (eax = N - 1) (i++)
    jb projectLoop3 ; outer loop

    ; CLEANING UP (AGAIN) ------------------------

    mov ebx, dword ptr [ebp + 28]
    push ebx ; N
    mov ebx, dword ptr [ebp + 8]
    push ebx ; Vx
    mov ebx, 1
    push ebx ; b value = 1
    call setBnd

    mov ebx, dword ptr [ebp + 28]
    push ebx ; N
    mov ebx, dword ptr [ebp + 12]
    push ebx ; Vy
    mov ebx, 2
    push ebx ; b value = 2
    call setBnd

    pop edx
    pop ecx
    pop ebx
    pop eax

    pop ebp
    ret 24
project endp

advect proc
    ; moving everything around after diffuse puts it all in place
    ; inputs - b val (+8), d(+12), d0(+16), Vx(+20), Vy(+24), dt(+28), N(+32) (with N being the first push)
    ; outputs - nothing.
    push ebp
    mov ebp, esp

    push eax
    push ebx
    push ecx
    push edx

    mov eax, [ebp + 32]
    mov eax, [eax] ; eax = N
    sub eax, 1 ; eax = N - 1
    mov ecx, 1 ; ecx = i = 1
    firstLoop:
        push ecx
        push eax
        mov edx, 1 ; edx = j = 1 
        secondLoop:
            push edx
            push eax

            push ecx
            push edx ; pushes to make sure that i get the right values after everything for i and j

            push eax ; saving a space for random saving: esp + 16
            push eax ; saving a space for x: esp + 12
            push eax ; saving a space for floor(x): esp + 8
            push eax ; saving a space for y: esp + 4
            push eax ; saving a space for floor(y): esp

            ; GETTING X VALUE ----------------------------------------
            mov ebx, [ebp + 32]
            mov ebx, dword ptr [ebx]
            push ebx ; N
            push edx ; y: j
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, [ebp + 20] ; ebx is pointing to Vx[i, j]
            fstp st(0)
            fld real4 ptr [ebx] ; st(0) = Vx[i, j]
            mov ebx, dword ptr [ebp + 28] ; ebx is pointing to dt
            fmul real4 ptr [ebx] ; st(0) = dt*Vx[i, j]
            mov ebx, dword ptr [ebp + 32] ; ebx is pointing to N
            mov ebx, dword ptr [ebx] ; ebx = N
            sub ebx, 2 ; ebx = N -2
            push ebx ; pushing to get it to the fpu
            fimul dword ptr [esp] ; st(0) = dt*(N-2)*Vx[i, j]
            pop ebx ; popping ebx back to preserve the stack
            fst real4 ptr [esp + 16] ; saving it to the random saving location assigned earlier

            push ecx ; i
            fstp st(0)
            fild dword ptr [esp] ; st(0) = i
            pop ecx ; popping to preserve the stack
            fsub real4 ptr [esp + 16] ; reacessing the value i stored earlier: st(0) = i - dt*(N-2)*Vx[i, j]
            fst real4 ptr [esp + 12] ; x = i - dt*(N-2)*Vx[i, j]

            fstp st(0)
            mov ebx, 1
            push ebx
            fild dword ptr [esp]
            pop ebx
            mov ebx, 2
            push ebx
            fidiv dword ptr [esp]
            pop ebx ; st(0) = 0.5

            fcom real4 ptr [esp + 12] ; comparing to x val
            fstsw ax          ;copy the Status Word containing the result to AX
            fwait             ;insure the previous instruction is completed
            sahf              ;transfer the condition codes to the CPU's flag register
            jb xGreaterThan0_5
            jz xIs0_5
            fst real4 ptr [esp + 12] ; if x < 0.5 => x = 0.5
            xGreaterThan0_5:
            xIs0_5: ; continuing to next calcs

            mov ebx, dword ptr [ebp + 32]
            mov ebx, dword ptr [ebx] ; ebx = N
            sub ebx, 2 ; ebx = N - 2
            push ebx
            fiadd dword ptr [esp]
            pop ebx ; st(0) = N - 2 + 0.5

            fcom real4 ptr [esp + 12] ; comparing to x val
            fstsw ax          ;copy the Status Word containing the result to AX
            fwait             ;insure the previous instruction is completed
            sahf              ;transfer the condition codes to the CPU's flag register
            ja xLessThanNMinus2Plus0_5
            jz xIsNMinus2Plus0_5
            fst real4 ptr [esp + 12] ; if x > N - 2 + 0.5 => x = N - 2 + 0.5

            xLessThanNMinus2Plus0_5:
            xIsNMinus2Plus0_5:

            ; GETTING Y VALUE -----------------------------------------------------------

            mov ebx, [ebp + 32]
            mov ebx, dword ptr [ebx]
            push ebx ; N
            push edx ; y: j
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, [ebp + 24] ; ebx is pointing to Vy[i, j]
            fstp st(0)
            fld real4 ptr [ebx] ; st(0) = Vy[i, j]
            mov ebx, dword ptr [ebp + 28] ; ebx is pointing to dt
            fmul real4 ptr [ebx] ; st(0) = dt*Vy[i, j]
            mov ebx, dword ptr [ebp + 32] ; ebx is pointing to N
            mov ebx, [ebx] ; ebx = N
            sub ebx, 2 ; ebx = N -2
            push ebx ; pushing to get it to the fpu
            fimul dword ptr [esp] ; st(0) = dt*(N-2)*Vy[i, j]
            pop ebx ; popping ebx back to preserve the stack
            fst real4 ptr [esp + 16] ; saving it to the random saving location assigned earlier

            push edx ; j
            fstp st(0)
            fild dword ptr [esp] ; st(0) = j
            pop edx ; popping to preserve the stack
            fsub real4 ptr [esp + 16] ; reacessing the value i stored earlier: st(0) = j - dt*(N-2)*Vy[i, j]
            fst real4 ptr [esp + 4] ; y = j - dt*(N-2)*Vy[i, j]
            
            fstp st(0)
            mov ebx, 1
            push ebx
            fild dword ptr [esp]
            pop ebx
            mov ebx, 2
            push ebx
            fidiv dword ptr [esp]
            pop ebx ; st(0) = 0.5

            fcom real4 ptr [esp + 4] ; comparing to x val
            fstsw ax          ;copy the Status Word containing the result to AX
            fwait             ;insure the previous instruction is completed
            sahf              ;transfer the condition codes to the CPU's flag register
            jb yGreaterThan0_5
            jz yIs0_5
            fst real4 ptr [esp + 4] ; if x < 0.5 => x = 0.5
            yGreaterThan0_5:
            yIs0_5: ; continuing to next calcs

            mov ebx, dword ptr [ebp + 32]
            mov ebx, dword ptr [ebx] ; ebx = N
            sub ebx, 2 ; ebx = N - 2
            push ebx
            fiadd dword ptr [esp]
            pop ebx ; st(0) = N - 2 + 0.5

            fcom real4 ptr [esp + 4] ; comparing to x val
            fstsw ax          ;copy the Status Word containing the result to AX
            fwait             ;insure the previous instruction is completed
            sahf              ;transfer the condition codes to the CPU's flag register
            ja yLessThanNMinus2Plus0_5
            jz yIsNMinus2Plus0_5
            fst real4 ptr [esp + 4] ; if x > N - 2 + 0.5 => x = N - 2 + 0.5

            yLessThanNMinus2Plus0_5:
            yIsNMinus2Plus0_5: ; continuing to next calcs

            ; GETTING floor(x) AND floor(y) VALUE -------------------------------------------

            mov ebx, 0
            push ebx
            fstcw word ptr [esp]
            fwait
            mov bx, word ptr [esp]
            and bx, 1111001111111111b
            or bx, 0000010000000000b
            push ebx
            fldcw [esp]
            pop ebx ; setting the control word to have the rounding set to round down

            fstp st(0)
            fld real4 ptr [esp + 16]
            fist dword ptr [esp + 12] ; saving x as int (rounded down) (esp is + 4 since we have the control word push on the stack) in floor(x)

            fstp st(0)
            fld real4 ptr [esp + 8]
            fist dword ptr [esp + 4] ; saving y as int (rounded down) (esp is + 4 since we have the control word push on the stack) in floor(y)

            fldcw word ptr [esp]
            pop ebx ; reloading control word

            ; essentially we're doing the following calculation here:
            ; --- f(x) = floor(x)
            ; d[i,j] = (1 + f(x) - x) * ((1 + f(y) - y) * d0[f(x), f(y)] + (y - f(y)) * d0[f(x), f(y) + 1])
            ;          + (x - f(x)) * ((1 + f(y) - y) * d0[f(x) + 1, f(y)] + (y - f(y)) * d0[f(x) + 1, f(y) + 1])

            fstp st(0)
            mov ebx, 1
            push ebx
            fild dword ptr [esp]
            pop ebx ; st(0) = 1
            fiadd dword ptr [esp] ; st(0) = 1 + f(y)
            fsub real4 ptr [esp + 4] ; st(0) = 1 + f(y) - y

            mov ebx, [ebp + 32]
            mov ebx, [ebx] ; ebx = N
            push ebx
            mov ebx, [esp + 4] ; ebx = f(y) (esp is +4 since we pushed ebx right now)
            push ebx
            mov ebx, [esp + 16] ; ebx = f(x) (esp is +8 since we pushed twice by this point)
            push ebx
            call IX
            pop ebx
            add ebx, [ebp + 16] ; ebx is pointing to d0[f(x), f(y)]
            fmul real4 ptr [ebx] ; st(0) = (1 + f(y) - y) * d0[f(x), f(y)]
            fst real4 ptr [esp + 16] ; saving to random access location we made earlier

            fstp st(0)
            fld real4 ptr [esp + 4]
            fisub dword ptr [esp] ; st(0) = y - f(y)

            mov ebx, [ebp + 32]
            mov ebx, [ebx] ; ebx = N
            push ebx
            mov ebx, [esp + 4]
            add ebx, 1 ; ebx = f(y) + 1 (esp is +4 since we pushed ebx right now)
            push ebx
            mov ebx, [esp + 16] ; ebx = f(x) (esp is +8 since we pushed twice by this point)
            push ebx
            call IX
            pop ebx
            add ebx, [ebp + 16] ; ebx is pointing to d0[f(x), f(y) + 1]
            fmul real4 ptr [ebx] ; st(0) = (y - f(y)) * d0[f(x), f(y) + 1]
            fadd real4 ptr [esp + 16] ; adding what we saved earlier
            ; st(0) = (1 + f(y) - y) * d0[f(x), f(y)] + (y - f(y)) * d0[f(x), f(y) + 1]
            fst real4 ptr [esp + 16] ; saving what we have to access it later

            fstp st(0)
            mov ebx, 1
            push ebx
            fild dword ptr [esp]
            pop ebx ; st(0) = 1
            fiadd dword ptr [esp + 8] ; st(0) = 1 + f(x)
            fsub real4 ptr [esp + 12] ; st(0) = 1 + f(x) - x

            fmul real4 ptr [esp + 16] ; st(0) = (1 + f(x) - x) * ((1 + f(y) - y) * d0[f(x), f(y)] + (y - f(y)) * d0[f(x), f(y) + 1])
            fst real4 ptr [esp + 16] ; saving what we have to access it later
            mov ebx, real4 ptr [esp + 16] ; ebx = st(0)

            push ebx ; doing the same but now ebp is ebp + 4 to save the value inside ebx




            fstp st(0)
            mov ebx, 1
            push ebx
            fild dword ptr [esp]
            pop ebx ; st(0) = 1
            fiadd dword ptr [esp + 4] ; st(0) = 1 + f(y)
            fsub real4 ptr [esp + 8] ; st(0) = 1 + f(y) - y

            mov ebx, dword ptr [ebp + 32]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx
            mov ebx, dword ptr [esp + 8] ; ebx = f(y) (esp is +4 since we pushed ebx right now)
            push ebx
            mov ebx, dword ptr [esp + 20] ; ebx = f(x) (esp is +8 since we pushed twice by this point)
            add ebx, 1 ; ebx = f(x) + 1
            push ebx
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 16] ; ebx is pointing to d0[f(x) + 1, f(y)]
            fmul real4 ptr [ebx] ; st(0) = (1 + f(y) - y) * d0[f(x) + 1, f(y)]
            fst real4 ptr [esp + 20] ; saving to random access location we made earlier

            fstp st(0)
            fld real4 ptr [esp + 8]
            fisub dword ptr [esp + 4] ; st(0) = y - f(y)

            mov ebx, dword ptr [ebp + 32]
            mov ebx, dword ptr [ebx] ; ebx = N
            push ebx
            mov ebx, dword ptr [esp + 8]
            add ebx, 1 ; ebx = f(y) + 1 (esp is +4 since we pushed ebx right now)
            push ebx
            mov ebx, dword ptr [esp + 20] 
            add ebx, 1 ; ebx = f(x) + 1 (esp is +8 since we pushed twice by this point)
            push ebx
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 16] ; ebx is pointing to d0[f(x) + 1, f(y) + 1]
            fmul real4 ptr [ebx] ; st(0) = (y - f(y)) * d0[f(x) + 1, f(y) + 1]
            fadd real4 ptr [esp + 20] ; adding what we saved earlier
            ; st(0) = (1 + f(y) - y) * d0[f(x) + 1, f(y)] + (y - f(y)) * d0[f(x), f(y) + 1]
            fst real4 ptr [esp + 20] ; saving what we have to access it later

            fstp st(0)
            fld real4 ptr [esp + 16]
            fisub dword ptr [esp + 12] ; st(0) = x - f(x)

            fmul real4 ptr [esp + 20] ; st(0) = (x - f(x)) * ((1 + f(y) - y) * d0[f(x) + 1, f(y)] + (y - f(y)) * d0[f(x), f(y) + 1])

            fadd real4 ptr [esp] ; st(0) = (1 + f(x) - x) * ((1 + f(y) - y) * d0[f(x), f(y)] + (y - f(y)) * d0[f(x), f(y) + 1]) +
            ;                              (x - f(x)) * ((1 + f(y) - y) * d0[f(x) + 1, f(y)] + (y - f(y)) * d0[f(x), f(y) + 1])

            pop ebx ; popping the push we did to get the st(0) value into the stack as esp

            pop ebx
            pop ebx
            pop ebx
            pop ebx
            pop ebx ; popping the stored values back so i can use the values i had for edx and ecx (j and i corrsepondingly)

            pop edx
            pop ecx ; popping the values we pushed at the top of the program to get them back (making sure that they are i and j)

            mov ebx, dword ptr [ebp + 32]
            mov ebx, dword ptr [ebx]
            push ebx ; N
            push edx ; y: j
            push ecx ; x: i
            call IX
            pop ebx
            add ebx, dword ptr [ebp + 12] ; ebx is pointing to d[i, j]
            fst real4 ptr [ebx] ; finished the calculation! we've got the following:
            ; d[i,j] = (1 + f(x) - x) * ((1 + f(y) - y) * d0[f(x), f(y)] + (y - f(y)) * d0[f(x), f(y) + 1])
            ;          + (x - f(x)) * ((1 + f(y) - y) * d0[f(x) + 1, f(y)] + (y - f(y)) * d0[f(x) + 1, f(y) + 1])



            pop eax
            pop edx
            inc edx
            cmp edx, eax
        jb secondLoop
        pop eax
        pop ecx
        inc ecx
        cmp ecx, eax
    jb firstLoop

    mov ebx, dword ptr [ebp + 32]
    push ebx ; N
    mov ebx, dword ptr [ebp + 12]
    push ebx ; d
    mov ebx, dword ptr [ebp + 8]
    push ebx ; b val
    call setBnd

    pop edx
    pop ecx
    pop ebx
    pop eax

    pop ebp
    ret 28
advect endp

setBnd proc
    ; sets the boundries to make sure that no fluid "leaks" outside of the bounds (making sure we're dealing with an incompressible fluid).
    ; Inputs - b, x, N (with N being the last push)
    ; Outputs - nothing
    push ebp
    mov ebp, esp
    
    push eax
    push ebx
    push ecx
    push edx

    mov ebx, [ebp + 16] ; N
    mov eax, dword ptr [ebx]
    sub eax, 1 ; eax = N-1

    mov ecx, 1

    loop1:
        push eax
        push ecx

        mov ebx, [ebp + 16] ; N
        mov eax, dword ptr [ebx]

        ; x[IX(i, 1)]
        push eax
        push 1
        push ecx
        call IX
        pop ebx
        add ebx, dword ptr [ebp + 12] ; positioning ebx inside the x array
    
        cmp dword ptr [ebp + 8], 2 ; b value == 2
        jnz false_2
        ; multiplying add value by -1 if the statement is true
        fstp st(0)
        fld real4 ptr [ebx]
        mov edx, -1
        push edx
        fimul dword ptr [esp]
        fst real4 ptr [esp]
        mov ebx, esp
        pop edx

        false_2:
    
        mov edx, real4 ptr [ebx]

        ; x[IX(i,0)]
        push eax
        push 0
        push ecx
        call IX
        pop ebx
        add ebx, dword ptr [ebp + 12] ; positioning ebx inside the x array
        mov real4 ptr [ebx], edx ; moving the value into the x array position

        ; doing the same regarding N-1 and N-2

        ; x[IX(i, N-2)]
        push eax
        sub eax, 2
        push eax
        add eax, 2
        push ecx
        call IX
        pop ebx
        add ebx, dword ptr [ebp + 12] ; positioning ebx inside the x array
    
        cmp dword ptr [ebp + 8], 2 ; b value == 2
        jnz false_2_N
        ; multiplying add value by -1 if the statement is true
        fstp st(0)
        fld real4 ptr [ebx]
        mov edx, -1
        push edx
        fimul dword ptr [esp]
        fst real4 ptr [esp]
        mov ebx, esp
        pop edx

        false_2_N:
    
        mov edx, real4 ptr [ebx]

        ; x[IX(i,N-1)]
        push eax
        sub eax, 1
        push eax
        add eax, 1
        push ecx
        call IX
        pop ebx
        add ebx, dword ptr [ebp + 12] ; positioning ebx inside the x array
        mov real4 ptr [ebx], edx ; moving the value into the x array position

        pop ecx
        pop eax
        inc ecx
        cmp ecx, eax
    jnz loop1 ; end of loop #1


    ; START OF LOOP 2 ---------------------------------------------------------

    mov ecx, 1

    loop2:
        push eax
        push ecx

        mov ebx, [ebp + 16] ; N
        mov eax, dword ptr [ebx]

        ; x[IX(1, i)]
        push eax
        push ecx
        push 1
        call IX
        pop ebx
        add ebx, dword ptr [ebp + 12] ; positioning ebx inside the x array
    
        cmp dword ptr [ebp + 8], 2 ; b value == 2
        jnz false_1
        ; multiplying add value by -1 if the statement is true
        fstp st(0)
        fld real4 ptr [ebx]
        mov edx, -1
        push edx
        fimul dword ptr [esp]
        fst real4 ptr [esp]
        mov ebx, esp
        pop edx

        false_1:
    
        mov edx, real4 ptr [ebx]

        ; x[IX(0, i)]
        push eax
        push ecx
        push 0
        call IX
        pop ebx
        add ebx, dword ptr [ebp + 12] ; positioning ebx inside the x array
        mov real4 ptr [ebx], edx ; moving the value into the x array position

        ; doing the same regarding N-1 and N-2

        ; x[IX(N-2, i)]
        push eax
        push ecx
        sub eax, 2
        push eax
        add eax, 2
        call IX
        pop ebx
        add ebx, dword ptr [ebp + 12] ; positioning ebx inside the x array
    
        cmp dword ptr [ebp + 8], 2 ; b value == 2
        jnz false_1_N
        ; multiplying add value by -1 if the statement is true
        fstp st(0)
        fld real4 ptr [ebx]
        mov edx, -1
        push edx
        fimul dword ptr [esp]
        fst real4 ptr [esp]
        mov ebx, esp
        pop edx

        false_1_N:
    
        mov edx, real4 ptr [ebx]

        ; x[IX(N-1, i)]
        push eax
        push ecx
        sub eax, 1
        push eax
        add eax, 1
        call IX
        pop ebx
        add ebx, dword ptr [ebp + 12] ; positioning ebx inside the x array
        mov real4 ptr [ebx], edx ; moving the value into the x array position

        pop ecx
        pop eax
        inc ecx
        cmp ecx, eax
    jnz loop2 ; end of loop #2

    ; SETTING VALUES FOR CORNERS --------------------------------

   ; POSITIONING IN 0, 0 -------------------------------------------------------------    

    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    push 0 ; y: 0
    push 1 ; x: 1
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at 1, 0

    fstp st(0)
    fld real4 ptr [ebx] ; loading x[1, 0]
    
    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    push 1 ; y: 1
    push 0 ; x: 0
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at 1, 0

    fadd real4 ptr [ebx] ; st(0) = x[0, 1] + x[1, 0]

    mov ebx, 2
    push ebx
    fidiv dword ptr [esp]
    pop ebx ; pushing ebx to get 2 in the stack and dividing st(0) by 2 (and then popping to preserve the stack

    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    push 0 ; y: 0
    push 0 ; x: 0
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at 0, 0
    fst real4 ptr [ebx] ; seving the new value in st(0) in 0, 0

    ; POSITIONING IN 0, N - 1 -------------------------------------------------------------    
    
    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    sub ebx, 1
    push ebx ; y: N-1
    push 1 ; x: 1
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at 1, N - 1

    fstp st(0)
    fld real4 ptr [ebx] ; loading x[1, N - 1]
    
    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    sub ebx, 2
    push ebx ; y: N-2
    push 0 ; x: 0
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at 0, N - 2

    fadd real4 ptr [ebx] ; st(0) = x[1, N - 1] + x[0, N - 2]

    mov ebx, 2
    push ebx
    fidiv dword ptr [esp]
    pop ebx ; pushing ebx to get 2 in the stack and dividing st(0) by 2 (and then popping to preserve the stack

    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    sub ebx, 1
    push ebx ; y: N - 1
    push 0 ; x: 0
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at 0, N - 1
    fst real4 ptr [ebx] ; seving the new value in st(0) in 0, N - 1

    ; POSITIONING IN N - 1, 0 -------------------------------------------------------------    
    
    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    push 1 ; y: 1
    sub ebx, 1
    push ebx ; x: N-1
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at N - 1, 1

    fstp st(0)
    fld real4 ptr [ebx] ; loading x[N - 1, 1]
    
    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    push 0 ; y: 0
    sub ebx, 2
    push ebx ; x: N-2
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at N - 2, 0

    fadd real4 ptr [ebx] ; st(0) = x[N - 1, 0] + x[N - 2, 0]

    mov ebx, 2
    push ebx
    fidiv dword ptr [esp]
    pop ebx ; pushing ebx to get 2 in the stack and dividing st(0) by 2 (and then popping to preserve the stack

    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    push 0 ; y: 0
    sub ebx, 1
    push ebx ; x: N - 1
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at N - 1, 0
    fst real4 ptr [ebx] ; seving the new value in st(0) in N - 1, 0
    

    ; POSITIONING IN N - 1, N - 1 -------------------------------------------------------------    
    
    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    sub ebx, 2
    push ebx ; y: N - 2
    add ebx, 1
    push ebx ; x: N - 1
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at N - 1, N - 2

    fstp st(0)
    fld real4 ptr [ebx] ; loading x[N - 1, N - 2]
    
    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    sub ebx, 1
    push ebx ; y: N-1
    sub ebx, 1
    push ebx ; x: N-2
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at N - 2, N - 1

    fadd real4 ptr [ebx] ; st(0) = x[N - 2, N - 1] + x[N - 1, N - 2]

    mov ebx, 2
    push ebx
    fidiv dword ptr [esp]
    pop ebx ; pushing ebx to get 2 in the stack and dividing st(0) by 2 (and then popping to preserve the stack

    mov ebx, [ebp + 16] ; N loc
    mov ebx, dword ptr [ebx]
    push ebx ; N value
    sub ebx, 1
    push ebx ; y: N - 1
    push ebx ; x: N - 1
    call IX
    pop ebx
    add ebx, [ebp + 12] ; positioning ebx inside vel at N - 1, N - 1
    fst real4 ptr [ebx] ; seving the new value in st(0) in N - 1, N - 1

    ; END OF CORNER PIECES -------------------------------------------------

    ; END OF PROC ----------------------------------------------------------

    pop edx
    pop ecx
    pop ebx
    pop eax

    pop ebp

    ret 12
setBnd endp

linSolve proc
    ; solves the linear equation to know how to diffuse and advect
    ; Inputs - b val, vel, vel0, iter, N, c, a (With a being the first push)
    ; Outputs - nothing
    push ebp
    mov ebp, esp
    
    push eax
    push ebx
    push ecx
    push edx

    mov ebx, [ebp + 24] ; N
    mov eax, dword ptr [ebx]
    sub eax, 1 ; eax = N-1
    mov ecx, [ebp + 20] ; iter
    ; looping for x and y over iter iterations
    iterLoop:
        push ecx
        mov ecx, 1
        xLoop:

            mov edx, 1
            yLoop:
                ; In essence, what we are doing here is the following algorithm:

                push edx
                push ecx
                push ebx
                push eax
                mov ebx, [ebp + 24] ; N
                mov eax, dword ptr [ebx]
                ; N is set up in eax, we will use it in other calls soon, mainly IX

                sub ecx, 1

                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 12] ; positioning location within vel arr
                fstp st(0)
                fld real4 ptr [ebx] ; getting the x-1, y val that is inside the arr

                add ecx, 2
                
                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 12] ; positioning location within vel arr
                fadd real4 ptr [ebx] ; getting the x + 1, y val that is inside the arr
                
                sub ecx, 1
                sub edx, 1

                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 12] ; positioning location within vel arr
                fadd real4 ptr [ebx] ; getting the x, y - 1 val that is inside the arr

                add edx, 2

                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 12] ; positioning location within vel arr
                fadd real4 ptr [ebx] ; getting the x, y + 1 val inside the arr
                
                sub edx, 1 ; getting edx back to y (from y + 1)

                ; MIDSECTION TO ALLOW THE PROGRAM TO BE THIS FRICKIN BIG
                
                jmp skipJump

                midLoop:
                jmp iterLoop

                skipJump:

                fmul real4 ptr [ebp + 32] ; multiplying all that by a

                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 16] ; positioning location within vel0 arr
                fadd real4 ptr [ebx] ; getting the vel0 x, y val that is inside the arr

                ;mov ebx, 1
                ;push ebx
                ;fild dword ptr [esp]
                ;pop ebx
                ; TODO - save 1/c elsewhere. There is no need to do this step and it is inefficient.

                fdiv real4 ptr [ebp + 28] ; getting the previous st(0) value and multipying by it


                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 12] ; positioning location x, y within vel arr
                

                fst real4 ptr [ebx] ; saving the final value in x, y inside vel arr
                fstp st(0)
                fld real4 ptr [ebx]

                pop eax
                pop ebx
                pop ecx
                pop edx

            inc edx
            cmp edx, eax
            jl yLoop ; end of yLoop

        inc ecx
        cmp ecx, eax
        jl xLoop ; end of xLoop
            
    mov ecx, [ebp + 24] ; N
    push ecx
    mov ecx, [ebp + 12] ; vel arr
    push ecx
    mov ecx, [ebp + 8] ; b val
    push ecx
    call setBnd ; setting boundaries to keep the fluid incompressible

    pop ecx
    loop midLoop

    mov cx, 0
              
    pop edx
    pop ecx
    pop ebx
    pop eax

    pop ebp

    ret 28
linSolve endp

fluidStep proc
    ; computes one whole step in the fluid
    ; Inputs - the adresses of each cube member (10 members) in the following order:
    ; N, visc, diff, deltat, Vx, Vy, Vx0, Vy0, s, density (With N being the last push)
    ; Outputs - nothing
    push ebp
    mov ebp, esp
    push eax
    push ebx
    
    mov eax, [ebp + 8] ; N
    push eax
    mov eax, 4 ; push value
    push eax
    mov eax, [ebp + 20] ; deltat
    push eax
    mov eax, [ebp + 12] ; visc
    push eax
    mov eax, [ebp + 24] ; Vx
    push eax
    mov eax, [ebp + 32] ; Vx0
    push eax
    mov eax, 1 ; b value
    push eax
    call diffuse

    mov eax, [ebp + 8] ; N
    push eax
    mov eax, 4 ; push value
    push eax
    mov eax, [ebp + 20] ; deltat
    push eax
    mov eax, [ebp + 12] ; visc
    push eax
    mov eax, [ebp + 28] ; Vy
    push eax
    mov eax, [ebp + 36] ; Vy0
    push eax
    mov eax, 2 ; b value
    push eax
    call diffuse


    mov eax, [ebp + 8] ; N
    push eax
    mov eax, 4 ; push value
    push eax
    mov eax, [ebp + 28] ; Vy
    push eax
    mov eax, [ebp + 24] ; Vx
    push eax
    mov eax, [ebp + 36] ; Vy0
    push eax
    mov eax, [ebp + 32] ; Vx0
    push eax
    call project

    mov eax, [ebp + 8] ; N
    push eax
    mov eax, [ebp + 20] ; deltat
    push eax
    mov eax, [ebp + 36] ; Vy0
    push eax
    mov eax, [ebp + 32] ; Vx0
    push eax
    mov eax, [ebp + 32] ; Vx0
    push eax
    mov eax, [ebp + 24] ; Vx
    push eax
    mov eax, 1 ; b value
    push eax
    call advect

    mov eax, [ebp + 8] ; N
    push eax
    mov eax, [ebp + 20] ; deltat
    push eax
    mov eax, [ebp + 36] ; Vy0
    push eax
    mov eax, [ebp + 32] ; Vx0
    push eax
    mov eax, [ebp + 36] ; Vy0
    push eax
    mov eax, [ebp + 28] ; Vy
    push eax
    mov eax, 2 ; b value
    push eax
    call advect

    mov eax, [ebp + 8] ; N
    push eax
    mov eax, 4 ; push value
    push eax
    mov eax, [ebp + 36] ; Vy0
    push eax
    mov eax, [ebp + 32] ; Vx0
    push eax
    mov eax, [ebp + 28] ; Vy
    push eax
    mov eax, [ebp + 24] ; Vx
    push eax
    call project

    mov eax, [ebp + 8] ; N
    push eax
    mov eax, 4 ; push value
    push eax
    mov eax, [ebp + 20] ; deltat
    push eax
    mov eax, [ebp + 16] ; diff
    push eax
    mov eax, [ebp + 44] ; density
    push eax
    mov eax, [ebp + 40] ; s
    push eax
    mov eax, 0 ; b value
    push eax
    call diffuse

    mov eax, [ebp + 8] ; N
    push eax
    mov eax, [ebp + 20] ; deltat
    push eax
    mov eax, [ebp + 24] ; Vx
    push eax
    mov eax, [ebp + 28] ; Vy
    push eax
    mov eax, [ebp + 40] ; s
    push eax
    mov eax, [ebp + 44] ; density
    push eax
    mov eax, 0 ; b value
    push eax
    call advect

    pop ebx
    pop eax

    pop ebp
    ret 40
fluidStep endp

printToConsole proc messageToPrint: dword
    push eax
    push ebx
    push ecx
    push edx

    INVOKE GetStdHandle, STD_OUTPUT_HANDLE ; getting output handle and saving it in eax
    mov consoleOutHandle, eax
    mov edx, messageToPrint ; message to print
    pushad
    mov eax, 121
    push edx
    mov edx, 0
    mov ebx, 30 ; eax = cols * rows to print on entire console
    mul ebx
    pop edx

    invoke WriteConsoleA, consoleOutHandle, edx, eax, offset bytesWritten, 0 ; writing to console
    popad

    pop edx
    pop ecx
    pop ebx
    pop eax ; blackbox

    ret
printToConsole endp

; TODO - REMOVE THIS PART BEFORE FINAL RELEASE
dprintToConsole proc messageToPrint: dword
    push eax
    push ebx
    push ecx
    push edx
    invoke dwtoa, messageToPrint, offset message2

    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    mov consoleOutHandle, eax
    mov edx, offset message2
    pushad
    mov eax, 16

    invoke WriteConsoleA, consoleOutHandle, edx, eax, offset bytesWritten, 0
    popad

    pop edx
    pop ecx
    pop ebx
    pop eax

    ret
dprintToConsole endp

drawSquare proc color: COLORREF, deviceContext: HDC, temp: COLORREF, pos: RECT
    push eax
    push ebx
    push ecx
    push edx

    invoke SetBkColor, deviceContext, color ; Getting previous background color into temp and setting current bgcolor to the requested one
    cmp eax, CLR_INVALID
    je fail
    mov COLORREF ptr [temp], eax ; saving previous bgcolor
    invoke ExtTextOut, deviceContext, 0, 0, ETO_OPAQUE, addr pos, " ", 0, 0 ; printing clear text with solid bg to draw the requested square (pos)
    invoke SetBkColor, deviceContext, COLORREF ptr [temp] ; resetting bgcolor

    fail:
    pop edx
    pop ecx
    pop ebx
    pop eax ; blackbox
    ret
drawSquare endp

getColor proc
    ; gets color value according to the requested mode
    ; INPUTS - COLOR (bp + 8), MODE (bp + 12)
    ; OUTPUTS - color value
    push ebp
    mov ebp, esp

    push eax
    push ebx
    push ecx

    mov ebx, dword ptr [ebp + 8] ; moving the density value into ebx (it's only in bl)
    mov eax, 0

    cmp dword ptr [ebp + 12], RGBC ; comparing the color mode to each option, and jumping accordingly
    je ON_RGB

    cmp dword ptr [ebp + 12], R
    je ON_R

    cmp dword ptr [ebp + 12], G
    je ON_G

    cmp dword ptr [ebp + 12], B
    je ON_B

    cmp dword ptr [ebp + 12], GRAY
    je ON_GRAY

    ON_RGB:
        ; REMINDER - colors are saved as BGR not RGB so it's in reverse order
        ; getting blue value
        mov al, bl ; eax = density value
        push eax
        mov eax, 255
        push eax
        fstp st(0)
        fild dword ptr [bPercentage]
        fidiv dword ptr [esp]
        pop eax
        fimul dword ptr [esp] ; st(0) = percentage * density / 255
        fist dword ptr [esp] 
        pop eax ; storing the value in eax (as int)
        shl eax, 16 ; saving it as the r value

        ; doing the same but for the green value since it's not a solid color
        mov ecx, 0
        mov cl, bl
        push ecx
        mov ecx, 255
        push ecx
        fstp st(0)
        fild dword ptr [gPercentage]
        fidiv dword ptr [esp]
        pop ecx
        fimul dword ptr [esp]
        fist dword ptr [esp]
        pop ecx
        mov ah, cl ; ah is holding the g part

        ; doing the same but for the blue value
        mov ecx, 0
        mov cl, bl
        push ecx
        mov ecx, 255
        push ecx
        fstp st(0)
        fild dword ptr [rPercentage]
        fidiv dword ptr [esp]
        pop ecx
        fimul dword ptr [esp]
        fist dword ptr [esp]
        pop ecx
        mov al, cl ; al is holding r percentage
        ; eax now holds the color we want
        jmp END_COLOR
    
    ON_R:
        mov al, bl ; only red
        jmp END_COLOR

    ON_G:
        mov ah, bl ; only green
        jmp END_COLOR
        
    ON_B:
        mov al, bl
        shl eax, 16 ; only blue
        jmp END_COLOR

    ON_GRAY:
        ; grayscale => R=G=B
        mov al, bl
        shl eax, 16
        mov al, bl
        mov ah, bl

    END_COLOR:
    mov dword ptr [ebp + 12], eax ; moving the final color value into the stack to return it

    pop ecx
    pop ebx
    pop eax ; blackbox

    pop ebp
    ret 4
getColor endp

; https://msdn.microsoft.com/library/windows/desktop/ms633573.aspx
WndProc PROC hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL screen:RECT
    LOCAL grid:RECT
    LOCAl systime:SYSTEMTIME

    cmp uMsg, WM_MOUSEMOVE
    je ON_WM_MOUSEMOVE

    cmp uMsg, WM_PAINT
    je ON_WM_PAINT

    cmp uMsg, WM_CREATE
    je ON_WM_CREATE

    cmp uMsg, WM_LBUTTONDOWN
    je ON_WM_LBUTTONDOWN

    cmp uMsg, WM_LBUTTONUP
    je ON_WM_LBUTTONUP

    cmp uMsg, WM_MOVE
    je ON_WM_MOVE

    cmp uMsg, WM_MOVING
    je ON_WM_MOVE

    cmp uMsg, WM_DESTROY
    je ON_WM_DESTROY

    cmp uMsg, WM_KEYDOWN
    je ON_WM_KEYDOWN

    ; cmp uMsg, WM_SIZE
    ; je ON_WM_MOVE

    jmp ON_DEFAULT

    ON_WM_KEYDOWN:

        ; setting label value for fluid params
        fstp st(0)
        fld real4 ptr [cube].visc
        fst qword ptr floatSave
        mov eax, offset VVal
        invoke FloatToStr, floatSave, eax
        invoke SetWindowText, hwndV, offset V

        fstp st(0)
        fld real4 ptr [cube].deltat
        fst qword ptr floatSave
        mov eax, offset DeltatVal
        invoke FloatToStr, floatSave, eax
        invoke SetWindowText, hwndDT, offset Deltat

        fstp st(0)
        fld real4 ptr [cube].diff
        fst qword ptr floatSave
        mov eax, offset DVal
        invoke FloatToStr, floatSave, eax
        invoke SetWindowText, hwndD, offset D

        mov eax, lParam
        and eax, 111111110000000000000000b
        shr eax, 16 ; eax now has the scancode of the keyboard input


        cmp eax, 10h ; q
        je ON_K_Q

        cmp eax, 02h ; 1
        je ON_K_1

        cmp eax, 03h ; 2
        je ON_K_2

        cmp eax, 04h ; 3
        je ON_K_3

        cmp eax, 05h ; 4
        je ON_K_4

        cmp eax, 06h ; 5
        je ON_K_5

        cmp eax, 4dh ; right arrow
        je ON_K_RIGHT

        cmp eax, 4bh ; left arrow
        je ON_K_LEFT

        cmp eax, 48h ; up arrow
        je ON_K_UP

        cmp eax, 50h ; down arrow
        je ON_K_DOWN

        cmp eax, 0ch ; -
        je ON_K_MINUS

        cmp eax, 0dh ; +
        je ON_K_PLUS

        jmp EXIT

        ON_K_Q:
            jmp ON_WM_DESTROY

        ON_K_1:
            mov dword ptr [mode], GRAY
            jmp EXIT
            
        ON_K_2:
            mov dword ptr [mode], R
            jmp EXIT

        ON_K_3:
            mov dword ptr [mode], G
            jmp EXIT
        
        ON_K_4:
            mov dword ptr [mode], B
            jmp EXIT
        
        ON_K_5:
            mov dword ptr [mode], RGBC
            jmp EXIT

        ON_K_RIGHT:
            fstp st(0)
            fld real4 ptr [cube].deltat
            mov eax, 3c23d70ah
            push eax
            fadd real4 ptr [esp]
            pop eax
            mov eax, 1
            push eax
            ficom dword ptr [esp] ; comparing to x val
            fstsw ax          ;copy the Status Word containing the result to AX
            fwait             ;insure the previous instruction is completed
            sahf              ;transfer the condition codes to the CPU's flag register
            jb skipResetDT1
            fstp st(0)
            fild dword ptr [esp]
            skipResetDT1:
            pop eax
            fst real4 ptr [cube].deltat
            
            ; push eax
            ; fst real4 ptr [esp]
            ; pop eax
            ; invoke dprintToConsole, eax
            jmp EXIT

        ON_K_LEFT:
            fstp st(0)
            fld real4 ptr [cube].deltat
            mov eax, 3c23d70ah
            push eax
            fsub real4 ptr [esp]
            pop eax
            mov eax, 3c23d70ah
            push eax
            fcom dword ptr [esp] ; comparing to x val
            fstsw ax          ;copy the Status Word containing the result to AX
            fwait             ;insure the previous instruction is completed
            sahf              ;transfer the condition codes to the CPU's flag register
            ja skipResetDT2
            fstp st(0)
            fld dword ptr [esp]
            skipResetDT2:
            pop eax
            fst real4 ptr [cube].deltat

            ; push eax
            ; fst real4 ptr [esp]
            ; pop eax
            ; invoke dprintToConsole, eax     

            jmp EXIT

        ON_K_UP:
            fstp st(0)
            fld real4 ptr [cube].visc
            mov eax, 3a83126fh
            push eax
            fadd real4 ptr [esp]
            pop eax
            mov eax, 3dcccccdh
            push eax
            fcom dword ptr [esp] ; comparing to x val
            fstsw ax          ;copy the Status Word containing the result to AX
            fwait             ;insure the previous instruction is completed
            sahf              ;transfer the condition codes to the CPU's flag register
            jb skipResetVisc1
            fstp st(0)
            fld dword ptr [esp]
            skipResetVisc1:
            pop eax
            fst real4 ptr [cube].visc

            ; push eax
            ; fst real4 ptr [esp]
            ; pop eax
            ; invoke dprintToConsole, eax 

            jmp EXIT

        ON_K_DOWN:
            fstp st(0)
            fld real4 ptr [cube].visc
            mov eax, 3a83126fh
            push eax
            fsub real4 ptr [esp]
            pop eax
            mov eax, 3727c5ach
            push eax
            fcom dword ptr [esp] ; comparing to x val
            fstsw ax          ;copy the Status Word containing the result to AX
            fwait             ;insure the previous instruction is completed
            sahf              ;transfer the condition codes to the CPU's flag register
            ja skipResetVisc2
            fstp st(0)
            fld dword ptr [esp]
            skipResetVisc2:
            pop eax
            fst real4 ptr [cube].visc

            ; push eax
            ; fst real4 ptr [esp]
            ; pop eax
            ; invoke dprintToConsole, eax
            
            jmp EXIT

        ON_K_PLUS:
            fstp st(0)
            fld real4 ptr [cube].diff
            mov eax, 3727c5ach
            push eax
            fadd real4 ptr [esp]
            pop eax
            mov eax, 3dcccccdh
            push eax
            fcom dword ptr [esp] ; comparing to x val
            fstsw ax          ;copy the Status Word containing the result to AX
            fwait             ;insure the previous instruction is completed
            sahf              ;transfer the condition codes to the CPU's flag register
            jb skipResetDiff1
            fstp st(0)
            fld dword ptr [esp]
            skipResetDiff1:
            pop eax
            fst real4 ptr [cube].diff

            ; push eax
            ; fst real4 ptr [esp]
            ; pop eax
            ; invoke dprintToConsole, eax

            jmp EXIT
        ON_K_MINUS:
            fstp st(0)
            fld real4 ptr [cube].diff
            mov eax, 3727c5ach
            push eax
            fsub real4 ptr [esp]
            pop eax
            mov eax, 0
            push eax
            ficom dword ptr [esp] ; comparing to x val
            fstsw ax          ;copy the Status Word containing the result to AX
            fwait             ;insure the previous instruction is completed
            sahf              ;transfer the condition codes to the CPU's flag register
            ja skipResetDiff2
            fstp st(0)
            fild dword ptr [esp]
            skipResetDiff2:
            pop eax
            fst real4 ptr [cube].diff

            ; push eax
            ; fst real4 ptr [esp]
            ; pop eax
            ; invoke dprintToConsole, eax

            jmp EXIT
        jmp EXIT

    ON_WM_DESTROY:              ; User closes program
        invoke PostQuitMessage, NULL ; quitting
        jmp EXIT

    ON_WM_CREATE:
        ; Create windows for text
        finit ; init fpu at the start
        
        push ebx
        fstcw word ptr [esp]
        fwait
        mov bx, word ptr [esp]
        and bx, 1111110011111111b
        or bx,  0001000000000000b ; bit masks on control word to make the fpu use real4 mode and infinity control to respect both -inf and +inf
        mov word ptr [esp], bx
        fldcw word ptr [esp]
        fwait
        pop ebx

        invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset StaticClassName, offset V, WS_CHILD or WS_VISIBLE or WS_BORDER or ES_LEFT, 20, 20, 150, 25, hWnd, 1, hInstance, NULL
        mov hwndV, eax
        invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset StaticClassName, offset Deltat, WS_CHILD or WS_VISIBLE or WS_BORDER or ES_LEFT, 20, 50, 150, 25, hWnd, 1, hInstance, NULL
        mov hwndDT, eax
        invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset StaticClassName, offset D, WS_CHILD or WS_VISIBLE or WS_BORDER or ES_LEFT, 20, 80, 150, 25, hWnd, 1, hInstance, NULL
        mov hwndD, eax ; creating windows to display the params

        ; Create pen for LineTo
        ; TODO - MAKE SURE IF THIS IS NECESSARY OR NOT
        invoke CreatePen, PS_SOLID, 2, 00000000h
        mov hPen, eax

        invoke printToConsole, offset message ; printing to console the display

        jmp EXIT

    ON_WM_LBUTTONDOWN:
        mov [state], DRAWING ; mov into state that the mouse is clicked

        jmp EXIT

    ON_WM_LBUTTONUP:
        mov [state], WAITING ; move into state that the mouse is no longer clicked
        
        jmp EXIT

    ON_WM_MOUSEMOVE:
        movzx eax, WORD PTR lParam
        mov hitpoint.x, eax ; hitpoint x is current mouse x given in the param

        mov eax, lParam
        shr eax, 16 ; getting the most significant word into ax
        mov hitpoint.y, eax ; hitpoint y is current mouse y given in the param

        cmp [state], DRAWING
        ; invoke InvalidateRect, hWnd, NULL, FALSE    ; https://msdn.microsoft.com/library/dd145002.aspx
        jne UPDATELASTXY
        mov eax, hitpoint.x
        mov ebx, dword ptr [gridLengthX]
        push edx
        mov edx, 0
        div ebx
        mov ecx, eax ; x in grid
        mov eax, hitpoint.y
        mov ebx, dword ptr [gridLengthY]
        mov edx, 0
        div ebx
        mov ebx, eax ; y in grid
        pop edx

        invoke addDensity, offset [cube].density, [cube].N, ebx, ecx, real4 ptr [DensityToAdd] ; adding 150 in density to the mouse location on grid

        push ecx
        push ebx

        push eax

        push ebx ; mandatory pushes

        mov eax, lastpoint.x
        mov ebx, dword ptr [gridLengthX]
        push edx
        mov edx, 0
        div ebx
        pop edx
        sub ecx, eax ; ecx is current point minus last point x

        pop ebx
        push ecx
        
        mov eax, lastpoint.y
        mov ecx, dword ptr [gridLengthY]
        push edx
        mov edx, 0
        div ecx
        pop edx
        sub ebx, eax ; ebx is current point minus last point y
    
        pop ecx

        pop eax ; popping to reset the stack


        cmp ebx, 2
        jle skip_1b
        mov ebx, 2
        jmp skip1b
        skip_1b:
        cmp ebx, 0
        je skip1b
        cmp ebx, -2
        jge skip1b
        mov ebx, -2
        skip1b: ; making sure -2 <= ebx <= 2


        push ebx
        fstp st(0)
        fild dword ptr [esp]
        fmul real4 ptr [vectorNormalizer]
        fst real4 ptr [yVectorToAdd]
        pop ebx ; normalizing the value to fit in for the working values and saving in yVectorToAdd

        cmp ecx, 2
        jle skip_1c
        mov ecx, 2
        jmp skip1c
        skip_1c:
        cmp ecx, 0
        je skip1c
        cmp ecx, -2
        jge skip1c
        mov ecx, -2
        skip1c: ; making sure -2 <= ecx <= 2

        push ecx
        fstp st(0)
        fild dword ptr [esp]
        fmul real4 ptr [vectorNormalizer]
        fst real4 ptr [xVectorToAdd]
        pop ecx ; normalizing the value to fit in for the working values and saving in xVectorToAdd


        pop ebx
        pop ecx ; resetting ebx and ecx to their x and y

        invoke addVelocity, offset cube.Vx, offset cube.Vy, cube.N, ebx, ecx, real4 ptr [xVectorToAdd], real4 ptr [yVectorToAdd] ; adding vels in mouse pos on grid

        UPDATELASTXY:
        mov eax, hitpoint.x
        mov lastpoint.x, eax
        mov eax, hitpoint.y
        mov lastpoint.y, eax ; updating last hitpoint and current hitpoint

        jmp EXIT
    
    ON_WM_MOVE:
        mov byte ptr [moved], 1 ; on screen move, making moved flag positive so it redraws the grid
        
        jmp EXIT

    ON_WM_PAINT:

        invoke GetSystemTime, addr systime
        mov edx, 0
        mov eax, 0
        mov ax, [systime].wMilliseconds
        mov ecx, 33
        div ecx
        cmp edx, 0
        jne EXIT ; fps cap


        ; making smooth RGBC
        inc dword ptr [colorCounter]
        cmp dword ptr [colorCounter], 1FFh ; colorCounter goes from 0 - 510 and will get the smooth RGBC transition
        jbe resetColorCounter

        mov dword ptr [colorCounter], 0
        inc dword ptr [repCounter]
        cmp dword ptr [repCounter], 3 ; repCounter goes from 0 - 2 and goes up whenever colorCounter finishes its loop
        jb resetColorCounter
        
        mov dword ptr [repCounter], 0 ; if it's >= 3 then set it to 0

        resetColorCounter:

        mov eax, dword ptr [repCounter]
        mov ebx, 4
        mov edx, 0
        mul ebx
        mov ebx, offset bPercentage
        add ebx, eax ; ebx is pointing to bPercentage + repCounter (repCounter is multiplied by 4 since we're in 32-bit memory)

        inc dword ptr [ebx]
        cmp dword ptr [ebx], 0FFh ; checking if the location ebx is pointing to is 255
        jbe skipResetPercentage

        mov dword ptr [ebx], 0FFh ; making the color max 255
        mov eax, dword ptr [repCounter]
        cmp eax, 0
        ja skipResetRepCounter
        mov eax, 3
        skipResetRepCounter:
        dec eax ; if the inc color gets to 255, the dec color (which is one location before the inc color) starts to get decreased from 255
    
        mov ebx, 4
        mov edx, 0
        mul ebx
        mov ebx, offset bPercentage
        add ebx, eax ; ebx is pointing to bPercentage + repCounter (repCounter is multiplied by 4 since we're in 32-bit memory)

        cmp dword ptr [ebx], 0 ; checking if the location ebx is pointing to is min 0
        jle skipResetPercentage
        
        dec dword ptr [ebx] ; if dec color is larger than 0, dec it

        skipResetPercentage:

        push offset [cube].density
        push offset [cube].s
        push offset [cube].Vy0
        push offset [cube].Vx0
        push offset [cube].Vy
        push offset [cube].Vx
        push offset [cube].deltat
        push offset [cube].diff
        push offset [cube].visc
        push offset [cube].N
        call fluidStep ; calling fluidStep to move the fluid


        invoke BeginPaint, hWnd, offset ps ; beginning paint to draw
        invoke GetClientRect, hWnd, addr screen
        mov eax, [screen].right
        mov ebx, [cube].N
        mov edx, 0
        div ebx
        mov ebx, eax ; screen width / N in ebx
        mov dword ptr [gridLengthX], ebx
        mov eax, [screen].bottom
        mov ecx, [cube].N
        mov edx, 0
        div ecx ; screen height / N in eax
        mov dword ptr [gridLengthY], eax
        mov ecx, [cube].N ; getting the screen size and saving the length of the grid (for later calcs)

        xGridLoop:
            dec ecx
            push ecx
            push ebx
            push eax
            mov ebx, eax ; getting eax in ebx to get the rect values to fill in the grid
            mov edx, 0
            mul ecx
            mov [grid].top, eax
            mov [grid].bottom, eax
            add [grid].bottom, ebx ; x value
            pop eax
            pop ebx
            mov edx, [cube].N

            yGridLoop:
                dec edx
                push edx
                push ecx
                push ebx
                push eax


                cmp byte ptr [moved], 1
                je reDraw ; if the window has been moved, we need to redraw everything since it deletes it
                push ebx ; pushing ebx as to not change it
                push [cube].N
                push edx
                push ecx
                call IX
                ; invoke printToConsole, ecx
                pop ebx
                push ebx
                add ebx, offset [cube].density
                fstp st(0)
                fld real4 ptr [ebx]
                mov eax, 3c23d70ah
                push eax
                fsub real4 ptr [esp]
                pop eax
                mov eax, 0
                push eax
                ficom dword ptr [esp] ; comparing to x val
                fstsw ax          ;copy the Status Word containing the result to AX
                fwait             ;insure the previous instruction is completed
                sahf              ;transfer the condition codes to the CPU's flag register
                jae skipFade
                fstp st(0)
                fild dword ptr [esp]
                skipFade:
                pop eax
                fst real4 ptr [ebx]

                sub ebx, offset [cube].density


                ; FADING THE VELS ----------------------------------------------------
                ; this shit sucks so i better fix it

                add ebx, offset [cube].Vx
                fstp st(0)
                fld real4 ptr [ebx]
                fdiv real4 ptr [vectorDivisor]
                fst real4 ptr [ebx]

                sub ebx, offset [cube].Vx

                add ebx, offset [cube].Vy
                fstp st(0)
                fld real4 ptr [ebx]
                fdiv real4 ptr [vectorDivisor]
                fst real4 ptr [ebx]


                pop ebx

                cmp dword ptr [mode], RGBC
                je RGBCMode ; if mode is rgb mode then refresh anyway

                mov eax, ebx
                add ebx, offset [cube].density
                add eax, offset [cube].densityZ
                mov eax, real4 ptr [eax]
                cmp real4 ptr [ebx], eax ; comparing the previous density value of grid pixel to current density value and skipping the draw if they're the same
                je skipDrawing

                RGBCMode:
                pop ebx ; resetting stack

                reDraw:
                push ebx
                push eax

                push [cube].N
                push edx
                push ecx
                call IX
                pop ebx
                add ebx, offset [cube].density ; ebx is pointing to density[x, y]

                mov eax, real4 ptr [ebx]

                push [cube].N
                push edx
                push ecx
                call IX
                pop ebx
                add ebx, offset [cube].densityZ
                mov real4 ptr [ebx], eax ; moving the current density value into the previous one

                pop eax
                pop ebx


                mov eax, ebx
                push ecx
                push edx
                mov ecx, edx
                mov edx, 0
                mul ecx
                pop edx
                pop ecx
                mov [grid].left, eax
                mov [grid].right, eax
                add [grid].right, ebx ; setting grid to point to the needed location

                push [cube].N
                push edx
                push ecx
                call IX
                pop ebx
                add ebx, offset [cube].density ; ebx points to cube density value in x y
                
                fstp st(0)
                fld real4 ptr [ebx]
                push eax
                fist dword ptr [esp]
                pop ebx ; ebx has the integer value of the density

                push dword ptr [mode]
                push ebx
                call getColor
                pop eax ; getting the color in eax

                mov [bcolor], eax
                invoke drawSquare, bcolor, ps.hdc, offset tempColor, grid ; drawing the square in the color according to the density

                jmp skipPop
                skipDrawing:
                pop ebx
                skipPop:
                pop eax
                pop ebx
                pop ecx
                pop edx

                cmp edx, 0
            jne yGridLoop



            pop ecx
            cmp ecx, 0
        jne xGridLoop

        ; END OF GRIDLOOP -----------------------------------------------------------------------

        mov byte ptr [moved], 0 ; making sure to reset the moved flag if it is 1 (so we won't draw unnecessary things)
        mov ecx, [cube].N ; loop counter


        ; THIS PART MAKES THE GRID -----------------------------------------
        
        ; gridLoop:
        ;     push eax
        ;     push ebx
        ;     push ecx
        ;     mov ebx, eax ; getting eax in ebx to get the rect values to fill in the grid
        ;     mov edx, 0
        ;     mul ecx
        ;     mov [grid].top, eax
        ;     mov [grid].bottom, eax
        ;     add [grid].bottom, ebx
        ;     push eax
        ;     invoke MoveToEx, ps.hdc, 0, eax, NULL
        ;     invoke SelectObject, ps.hdc, hPen;
        ;     pop eax
        ;     invoke LineTo, ps.hdc, [screen].right, eax ; iterating over y values with const x
        ;     pop ecx
        ;     pop ebx
        ;     pop eax
        ;     push eax
        ;     push ebx
        ;     push ecx ; getting the register values back, since the invokes change them
        ;     mov eax, ebx
        ;     mov edx, 0
        ;     mul ecx
        ;     mov [grid].left, eax
        ;     mov [grid].right, eax
        ;     add [grid].right, ebx
        ;     push eax
        ;     invoke MoveToEx, ps.hdc, eax, 0, NULL
        ;     invoke SelectObject, ps.hdc, hPen;
        ;     pop eax
        ;     invoke LineTo, ps.hdc, eax, [screen].bottom ; iterating over x values with const y

        ;     mov eax, [screen].right
        ;     invoke dwtoa, eax, offset X
        ;     invoke SetWindowText, hwndDT, offset X

        ;     pop ecx
        ;     pop ebx
        ;     pop eax
        ;     dec ecx
        ;     cmp ecx, 0
        ; jne gridLoop

        invoke EndPaint, hWnd, offset ps ; ending paint

        invoke InvalidateRect, hWnd, NULL, FALSE ; refreshing screen
        jmp EXIT

    ON_DEFAULT:     ; handle any message that program don't handle
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam    ; https://msdn.microsoft.com/library/windows/desktop/ms633572.aspx
        jmp EXIT

    EXIT:
        ret
WndProc ENDP

WinMain PROC hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD

    ; WNDCLASSEX structure in MSDN, declaration in windows.inc
    ; https://msdn.microsoft.com/library/windows/desktop/ms633577.aspx
    invoke LoadIcon, NULL, IDI_APPLICATION  ; Load default icon
    mov wc.hIcon, eax
    mov wc.hIconSm, eax
    invoke LoadCursor, NULL, IDC_ARROW      ; Load default cursor
    mov wc.hCursor, eax

    mov wc.cbSize, SIZEOF WNDCLASSEX        ; size of this structure
    mov wc.style, CS_HREDRAW or CS_VREDRAW  ; style of windows https://msdn.microsoft.com/library/windows/desktop/ff729176.aspx
    mov wc.lpfnWndProc, OFFSET WndProc      ; address of window procedure
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, NULL
    push hInstance
    pop wc.hInstance
    mov wc.hbrBackground,COLOR_WINDOW+1     ; background color, require to add 1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET ClassName

    invoke RegisterClassEx, offset wc       ; https://msdn.microsoft.com/library/windows/desktop/ms633587.aspx
    
    ; creating client window
    ; https://msdn.microsoft.com/library/windows/desktop/ms632680.aspx
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset ClassName, offset AppName, WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 600, 600, NULL, NULL, hInstance, NULL
    mov hwnd, eax                       ; Store windows handle
    invoke ShowWindow, hwnd, CmdShow    ; https://msdn.microsoft.com/library/windows/desktop/ms633548.aspx
    invoke UpdateWindow, hwnd           ; https://msdn.microsoft.com/library/windows/desktop/dd145167.aspx

    ; Message Loop
    MESSAGE_LOOP:                       ; https://msdn.microsoft.com/library/windows/desktop/ms644936.aspx

        invoke GetMessage, offset msg, NULL, 0, 0
        test eax, eax
        jle END_LOOP

        invoke TranslateMessage, offset msg
        invoke DispatchMessage, offset msg ; processing message and dispatching it

        jmp MESSAGE_LOOP

    END_LOOP:
    mov eax, msg.wParam
    ret
WinMain ENDP

main PROC
    invoke GetModuleHandle, NULL    ; https://msdn.microsoft.com/library/windows/desktop/ms683199.aspx
    mov hInstance, eax              ; return an instance to handle in eax

    invoke GetCommandLine           ; https://msdn.microsoft.com/library/windows/desktop/ms683156.aspx
    mov CommandLine, eax            ; return a pointer to the command-line for current process
    invoke WinMain, hInstance, NULL, CommandLine, SW_SHOW ; starting main proc

    invoke ExitProcess, eax ; exiting
main ENDP

END main