.386                ; use 80386 instruction
FluidCube struct

diff real4 ?
deltat real4 ?
visc real4 ?
N dd 64

s real4 64*64 dup(0.0)
density real4 64*64 dup(100.0)

Vx real4 64*64 dup(1.0)
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

.DATA
    ClassName db 'SimpleWinClass',0
    AppName db 'Paint',0

    labelDrawing db 'Drawing...',0
    labelWaiting db 'Waiting.',0

    StaticClassName db 'static',0
    X dw 'x',0
    Y dw 'y',0

    state db WAITING

    bcolor dd 00232323h

    cube FluidCube <3.1, 4.2, 5.3>
    ThreeBytes db 10h,20h,30h
    real2 real4 2.0

    consoleOutHandle dd ? 
    bytesWritten dd ? 
    message db "Hello World",13,10
    lmessage dd 13

.DATA?
    hInstance HINSTANCE ?
    hbr HBRUSH ?
    CommandLine LPSTR ?
    hitpoint POINT <>
    lastpoint POINT <>

    wc WNDCLASSEX <?>
    msg MSG <?> ; handle message
    hwnd HWND ? ; handle window procedure

    hwndX HWND ?
    hwndY HWND ?
    hwndState HWND ?

    hdc HDC ?
    ps PAINTSTRUCT <?>

    hPen HPEN ?

.CODE

delay proc
    push eax
    push ebx
    push ecx

    mov eax, 00000DFFh
    mov ebx, 0
    mov ecx, 0
    loop1:
    inc ebx
    loop2:
    push eax
    invoke DeleteObject, hbr
    invoke CreateSolidBrush, eax
    mov hbr, eax
    pop eax
    inc ecx
    cmp ecx, eax
    jnz loop2
    mov ecx, 0
    cmp ebx, eax
    jnz loop1 ; nested loops - delaying by incrementing bx and cx until they equal the val in ax. change ax to change delay time

    pop ecx
    pop ebx
    pop eax
    ret
delay endp

IX proc ;x:dword, y:dword, N:word
    ; bp+8 = x, bp+12 = y, bp+16 = N
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
    mov bx, [ebp+16] ; N
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
    fld real4 ptr [ebx]
    push eax
    fadd real4 ptr [esp]
    fst real4 ptr [esp]
    mov eax, real4 ptr [esp]
    mov real4 ptr [ebx], eax

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
    add real4 ptr [ebx], eax

    mov eax, amounty
    add real4 ptr [edi], eax

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
    push ebp
    mov ebp, esp

    push eax
    push ebx

    mov ebx, [ebp + 32] ; N
    fstp st(0)
    fild dword ptr [ebx]
    mov eax, 2
    push eax
    fisub dword ptr [esp]
    pop eax
    fst st(1)

    fstp st(0)
    mov ebx, [ebp + 24]
    fadd real4 ptr [ebx] ; dt
    mov ebx, [ebp + 20]
    fmul real4 ptr [ebx] ; diff
    mov ebx, [ebp + 32]
    fmul st, st(1) ; N - 2
    fmul st, st(1) ; N - 2

    ; setting up FPU pops to get the final calculated value in st and
    ; also do some more calcs on a (and push them)
    sub esp, 4
    fst dword ptr [esp] ; a
    mov eax, 6
    push eax
    fimul dword ptr [esp]
    pop eax
    mov eax, 1
    push eax
    fiadd dword ptr [esp]
    pop eax
    sub esp, 4
    fst dword ptr [esp] ; a * 6 + 1
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

    ret 24
project endp

advect proc

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

    pop eax
    inc ecx
    cmp ecx, eax
    jnz loop1 ; end of loop #1


    ; START OF LOOP 2 ---------------------------------------------------------

    mov ecx, 1

    loop2:
    push eax

    mov ebx, [ebp + 16] ; N
    mov eax, dword ptr [ebx]

    ; x[IX(i, 1)]
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

    ; x[IX(i,0)]
    push eax
    push ecx
    push 1
    call IX
    pop ebx
    add ebx, dword ptr [ebp + 12] ; positioning ebx inside the x array
    mov real4 ptr [ebx], edx ; moving the value into the x array position

    ; doing the same regarding N-1 and N-2

    ; x[IX(i, N-2)]
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

    ; x[IX(i,N-1)]
    push eax
    push ecx
    sub eax, 1
    push eax
    add eax, 1
    call IX
    pop ebx
    add ebx, dword ptr [ebp + 12] ; positioning ebx inside the x array
    mov real4 ptr [ebx], edx ; moving the value into the x array position

    pop eax
    inc ecx
    cmp ecx, eax
    jnz loop2 ; end of loop #2

    pop edx
    pop ecx
    pop ebx
    pop eax

    pop ebp

    ret 12
setBnd endp

linSolve proc
    ; solves the linear equation to know how to diffuse and advect
    ; Inputs - b val, vel, vel0, iter, N, c, a (With a being the last push)
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
                mov eax, [ebx]
                ; N is set up in eax, we will use it in other calls soon

                sub ecx, 1

                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 12] ; positioning location within vel arr
                fstp st(0)
                fld real4 ptr [ebx] ; getting the val inside the arr

                add ecx, 2
                
                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 12] ; positioning location within vel arr
                fadd real4 ptr [ebx] ; getting the val inside the arr
                
                sub ecx, 1
                sub edx, 1

                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 12] ; positioning location within vel arr
                fadd real4 ptr [ebx] ; getting the val inside the arr

                add edx, 2

                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 12] ; positioning location within vel arr
                fadd real4 ptr [ebx] ; getting the val inside the arr
                
                sub edx, 1

                ; MIDSECTION TO ALLOW THE PROGRAM TO BE THIS FRICKIN BIG
                
                jmp skipJump

                midLoop:
                jmp iterLoop

                skipJump:

                fmul real4 ptr [ebp + 32]

                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 16] ; positioning location within vel0 arr
                fadd real4 ptr [ebx] ; getting the val inside the arr

                fst st(1)

                fstp st(0)

                mov ebx, 1
                push ebx
                fild dword ptr [esp]
                pop ebx
                mov ebx, [ebp + 28]
                push ebx
                fdiv dword ptr [esp]
                pop ebx

                fmul st, st(1)

                push eax
                push edx ; y val
                push ecx ; x val
                call IX
                pop ebx
                add ebx, [ebp + 12] ; positioning location within vel arr
                
                push ebx
                fst real4 ptr [esp]
                mov eax, real4 ptr [esp]
                mov real4 ptr [ebx], eax
                pop ebx


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
    mov eax, [ebp + 32] ; Vx0
    push eax
    mov eax, [ebp + 24] ; Vx
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
    mov eax, [ebp + 36] ; Vy0
    push eax
    mov eax, [ebp + 28] ; Vy
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
    mov eax, [ebp + 36] ; Vy0
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


fputest proc
    
    fstp st(0)
    fld real4 ptr [real2]
    fstp st(0)
    fld real4 ptr [real2]

    ret
fputest endp


updateXY PROC lParam:LPARAM
    movzx eax, WORD PTR lParam
    mov hitpoint.x, eax

    ; invoke dwtoa, eax, offset X
    ; invoke SetWindowText, hwndX, offset X

    mov eax, lParam
    shr eax, 16
    mov hitpoint.y, eax

    ; invoke dwtoa, eax, offset Y
    ; invoke SetWindowText, hwndY, offset Y
    ret
updateXY ENDP

changePenColor proc color:dword
    push eax

    invoke CreatePen, PS_SOLID, 2, color
    mov hPen, eax

    pop eax
    ret
changePenColor endp

changeBrushColor proc color: dword
    push eax
    push ebx
    push ecx
    push edx
    
    invoke DeleteObject, hbr
    invoke CreateSolidBrush, color
    mov hbr, eax

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
changeBrushColor endp



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

    cmp uMsg, WM_DESTROY
    je ON_WM_DESTROY

    jmp ON_DEFAULT

    ON_WM_DESTROY:              ; User closes program
        invoke PostQuitMessage, NULL
        jmp EXIT

    ON_WM_CREATE:
        ; Create windows for text
        invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset StaticClassName, offset X, WS_CHILD or WS_VISIBLE or WS_BORDER or ES_LEFT, 20, 20, 50, 25, hWnd, 1, hInstance, NULL
        mov hwndX, eax
        invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset StaticClassName, offset Y, WS_CHILD or WS_VISIBLE or WS_BORDER or ES_LEFT, 90, 20, 50, 25, hWnd, 1, hInstance, NULL
        mov hwndY, eax
        invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset StaticClassName, offset labelWaiting, WS_CHILD or WS_VISIBLE or WS_BORDER or ES_LEFT, 20, 60, 80, 23, hWnd, 1, hInstance, NULL
        mov hwndState, eax

        ; Create pen for LineTo
        invoke CreatePen, PS_SOLID, 2, 00000000h
        mov hPen, eax
        invoke CreateSolidBrush, 00EEEEEEh
        mov hbr, eax

        jmp EXIT

    ON_WM_LBUTTONDOWN:

        ; last mouse position = current mouse position
        mov eax, hitpoint.x
        mov lastpoint.x, eax
        mov eax, hitpoint.y
        mov lastpoint.y, eax

        mov [state], DRAWING
        invoke SetWindowText, hwndState, offset labelDrawing
        jmp EXIT

    ON_WM_LBUTTONUP:
        mov [state], WAITING
        invoke SetWindowText, hwndState, offset labelWaiting
        jmp EXIT

    ON_WM_MOUSEMOVE:
        invoke updateXY, lParam                     ; PROC above

        cmp [state], DRAWING
        ; invoke InvalidateRect, hWnd, NULL, FALSE    ; https://msdn.microsoft.com/library/dd145002.aspx
        jne EXIT

        jmp EXIT

    ON_WM_PAINT:
        invoke BeginPaint, hWnd, offset ps
        invoke changeBrushColor, 00FFFFFFh

        invoke GetClientRect, hWnd, addr screen
        mov eax, [screen].right
        mov ebx, [cube].N
        mov edx, 0
        div ebx
        mov ebx, eax ; screen width / N in ebx
        mov eax, [screen].bottom
        mov ecx, [cube].N
        mov edx, 0
        div ecx ; screen height / N in eax
        mov ecx, [cube].N ; loop counter

        gridLoop:
            push eax
            push ebx
            push ecx
            mov ebx, eax ; getting eax in ebx to get the rect values to fill in the grid
            mov edx, 0
            mul ecx
            mov [grid].top, eax
            mov [grid].bottom, eax
            add [grid].bottom, ebx
            push eax
            invoke MoveToEx, ps.hdc, 0, eax, NULL
            invoke SelectObject, ps.hdc, hPen;
            pop eax
            invoke LineTo, ps.hdc, [screen].right, eax ; iterating over y values with const x
            pop ecx
            pop ebx
            pop eax
            push eax
            push ebx
            push ecx ; getting the register values back, since the invokes change them
            mov eax, ebx
            mov edx, 0
            mul ecx
            mov [grid].left, eax
            mov [grid].right, eax
            add [grid].right, ebx
            push eax
            invoke MoveToEx, ps.hdc, eax, 0, NULL
            invoke SelectObject, ps.hdc, hPen;
            pop eax
            invoke LineTo, ps.hdc, eax, [screen].bottom ; iterating over x values with const y

            mov eax, [screen].right
            invoke dwtoa, eax, offset X
            invoke SetWindowText, hwndY, offset X

            pop ecx
            pop ebx
            pop eax
            dec ecx
            cmp ecx, 0
        jne gridLoop
        invoke EndPaint, hWnd, offset ps

            invoke InvalidateRect, hWnd, NULL, FALSE
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
    mov wc.lpfnWndProc, OFFSET WndProc      ; andress of window procedure
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, NULL
    push hInstance
    pop wc.hInstance
    mov wc.hbrBackground,COLOR_WINDOW+1     ; background color, require to add 1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET ClassName

    invoke RegisterClassEx, offset wc       ; https://msdn.microsoft.com/library/windows/desktop/ms633587.aspx

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
        invoke DispatchMessage, offset msg

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
    invoke WinMain, hInstance, NULL, CommandLine, SW_SHOW

    invoke ExitProcess, eax
main ENDP

END main