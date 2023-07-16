; external functions from X11 library
extern XOpenDisplay
extern XDisplayName
extern XCloseDisplay
extern XCreateSimpleWindow
extern XMapWindow
extern XRootWindow
extern XSelectInput
extern XFlush
extern XCreateGC
extern XSetForeground
extern XDrawLine
extern XDrawPoint
extern XFillArc
extern XNextEvent

; external functions from stdio library (ld-linux-x86-64.so.2)    
extern printf
extern exit

%define	StructureNotifyMask	131072
%define KeyPressMask		1
%define ButtonPressMask		4
%define MapNotify		19
%define KeyPress		2
%define ButtonPress		4
%define Expose			12
%define ConfigureNotify		22
%define CreateNotify 16
%define QWORD	8
%define DWORD	4
%define WORD	2
%define BYTE	1

%define nbPoints 10
%define windowSize 200

global main

section .bss
display_name:	resq	1
screen:			resd	1
depth:         	resd	1
connection:    	resd	1
width:         	resd	1
height:        	resd	1
window:		resq	1
gc:		resq	1


;tabX: resd nbPoints
;tabY: resd nbPoints
tabHx: resw nbPoints
tabHy: resw nbPoints

;ajout supplémentaire
tabX: resw nbPoints
tabY: resw nbPoints


section .data

event:		times	24 dq 0

x1:	dd	0
x2:	dd	0
y1:	dd	0
y2:	dd	0
px: dd 0 ; init to window size so every points are lower
py: dd 0
lx: dd windowSize
ly: dd windowSize
SwapLyToo: db 0
ix: dd 0
iy: dd 0
qx: dd 0
qy: dd 0
PIx: dd 0
PIy: dd 0
IQx: dd 0
IQy: dd 0
randPointx: dd 0
randPointy: dd 0

swap: db "Swap I Q",10,0
fmt: db "-->%d<--",10,0
fmtWD: db "->Le point est à droite de %d des %d arêtes<-",10,0
fmtxy1: db "x1: %d  y1: %d",10,0
fmtxy2: db "x2: %d  y2: %d",10,0
fmt3: db "x:%d y:%d i=%d",10,0
fmt3h: db "Here is tabH x:%d y:%d i=%d",10,0
fmt3hout: db "Here is tabH out  x:%d y:%d i=%d",10,0
fmt3q: db "x:%d y:%d i=%d for Q",10,0
fmt3qout: db "x:%d y:%d i=%d for Qout",10,0
fmt3i: db "x:%d y:%d i=%d for I",10,0
fmt3p: db "x:%d y:%d i=%d for P",10,0
fmt3l: db "x:%d y:%d i=%d for L",10,0
fmtxAB: db "x𝐴𝐵 = x𝐵 − x𝐴 || %d = %d - %d",10,0
fmtyAB: db "𝑦𝐴𝐵 = 𝑦𝐵 − 𝑦𝐴 || %d = %d - %d",10,0
fmtxBC: db "xBC = xC − xB || %d = %d - %d",10,0
fmtyBC: db "𝑦BC = 𝑦C − 𝑦B || %d = %d - %d",10,0
fmtMul: db "(𝑥𝐵𝐶 × 𝑦𝐴𝐵) − (𝑥𝐴𝐵 × 𝑦𝐵𝐶) || (%d * %d) - (%d * %d)",10,0
fmtxBCyAB: db "(𝑥𝐵𝐶 × 𝑦𝐴𝐵) || %d = %d x %d",10,0
fmtxAByBC: db "(𝑥AB × 𝑦BC) || %d = %d x %d",10,0

fmtPointXY: db "The random point coordinate are x: %d  y: %d",10,0
indice: dw 0
printIndice:	db 	"t[%d]=%d", 10, 0

JustCameOnce: db 0
segf: db "Not here",10,0
isLeft: db 0
pointIsIn: db "Le point (%d,%d) est contenu dans l'enveloppe",10,0
pointIsOut: db "Le point (%d,%d) n'est pas contenu dans l'enveloppe",10,0

section .text
	
;##################################################
;########### PROGRAMME PRINCIPAL ##################
;##################################################

main:
cmp byte[JustCameOnce],1 ; if not we come here 2 times
je finDessin
call randomNumber

xor     rdi,rdi
call    XOpenDisplay	; Création de display
mov     qword[display_name],rax	; rax=nom du display

; display_name structure
; screen = DefaultScreen(display_name);
mov     rax,qword[display_name]
mov     eax,dword[rax+0xe0]
mov     dword[screen],eax

mov rdi,qword[display_name]
mov esi,dword[screen]
call XRootWindow
mov rbx,rax

mov rdi,qword[display_name]
mov rsi,rbx
mov rdx,10
mov rcx,10
mov r8,windowSize	; largeur
mov r9,windowSize	; hauteur
push 0xFFFFFF	; background  0xRRGGBB
push 0x00FF00
push 1
call XCreateSimpleWindow
mov qword[window],rax

mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,131077 ;131072
call XSelectInput

mov rdi,qword[display_name]
mov rsi,qword[window]
call XMapWindow

mov rsi,qword[window]
mov rdx,0
mov rcx,0
call XCreateGC
mov qword[gc],rax

mov rdi,qword[display_name]
mov rsi,qword[gc]
mov rdx,0x000000	; Couleur du crayon
call XSetForeground

boucle: ; boucle de gestion des évènements

mov rdi,qword[display_name]
mov rsi,event
call XNextEvent

xor rbx,rbx
cmp dword[event],ConfigureNotify	; à l'apparition de la fenêtre
je dessin							; on saute au label 'dessin'

cmp dword[event],KeyPress			; Si on appuie sur une touche
je closeDisplay						; on saute au label 'closeDisplay' qui ferme la fenêtre
jmp boucle

;#########################################
;#		DEBUT DE LA ZONE DE DESSIN		 #
;#########################################


push rbp
dessin:
cmp byte[JustCameOnce],1 ; if not we come here 2 times
je finDessin
mov byte[JustCameOnce],1

mov word[indice],0
mov rbx,0
generationPoints:

movzx rbx,word[indice]

mov rdi,fmt3
movzx rsi,word[tabX+rbx*WORD]
movzx rdx,word[tabY+rbx*WORD] ;  
movzx rcx,word[indice]
mov rax,0
call printf

    ;couleur du point 1
    mov rdi,qword[display_name]
    mov rsi,qword[gc]
    mov edx,0x000000	; Couleur du crayon ; rouge
    call XSetForeground

    ; Dessin d'un point rouge sous forme d'un petit rond : coordonnées (tabX[i],tabY[i])
    mov rdi,qword[display_name]
    mov rsi,qword[window]
    mov rdx,qword[gc]
    movzx ebx, word[indice] ; On charge l'indice dans ebx;
    movzx rcx,word[tabX+ebx*WORD]		; coordonnée en x du point
    sub ecx,3
    movzx ebx, word[indice] ; On charge l'indice dans ebx;
    movzx r8,word[tabY+ebx*WORD] 		; coordonnée en y du point
    sub r8,3
    mov r9,6
    mov rax,23040
    push rax
    push 0
    push r9
    call XFillArc

    inc word[indice]; On incrémente l'indice

    cmp word[indice], nbPoints; On compare l'indice à la taille du tableau
    jb generationPoints; Si l'indice est plus petit que la taille du tableau, on saute à la génération des points


    ; L = Points with min x
    mov rbx,0
    mov rcx,0
    mov rax,0

    LookForL:
        movzx ebx,word[tabX+rcx*WORD]
    cmp dword[lx],ebx
    jb NotLowerLx ; MIN X
        mov dword[lx],ebx ; IN LX
        mov ax,word[tabX] ; tmp = tab[0]
        mov word[tabX+ecx*WORD],ax ; tab[lx] = tmp
        mov word[tabX],bx   ;tab[0] = lx
        mov byte[SwapLyToo],1
    NotLowerLx:
    cmp byte[SwapLyToo],0 ; TO PUT
    je NotLowerLy ;
        movzx ebx,word[tabY+rcx*WORD]
        mov dword[ly],ebx ; IN LY
        mov ax,word[tabY] ; tmp = tab[0]
        mov word[tabY+ecx*WORD],ax ; tab[ly] = tmp
        mov word[tabY],bx   ;tab[0] = ly
        mov byte[SwapLyToo],0
    NotLowerLy:
    inc rcx
    cmp rcx,nbPoints
    jb LookForL

Increment:
;inc rbx
;cmp rbx,nbPoints ; rbx is at 1331 for some reason so 40 points = 1331 + 40
;jb loopDessin


mov rbx,nbPoints

printLoop:

;; Print every points coordinates
;mov rdi,fmt3
;movzx rsi,byte[tabX+rbx]
;movzx rdx,byte[tabY+rbx]
;mov rcx,rbx
;mov rax,0
;call printf

dec rbx
cmp rbx,0
ja printLoop

xor rax,rax

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; L is the points with min x


; L = P
mov eax,dword[lx]
mov dword[px],eax
mov eax,dword[ly]
mov dword[py],eax

;mov rdi,fmt3p
;mov eax,dword[px]
;mov rsi,rax
;mov eax,dword[py]
;xor rdx,rdx
;mov rax,0
;call printf

mov word[indice],0
   AddPtoH:

    ;mov rdi,fmt3p
    ;mov eax,dword[px]
    ;mov rsi,rax
    ;mov eax,dword[py]
    ;mov rdx,rax
    ;movzx rcx,word[indice]
    ;mov rax,0
    ;call printf

    mov rbx,0
        printH1:
        cmp rbx,nbPoints
        je lfnextpoint

        mov rdi,fmt3h
        movzx rsi,word[tabHx+rbx*WORD]
        movzx rdx,word[tabHy+rbx*WORD]
        mov rcx,rbx
        mov rax,0
        call printf

        inc rbx
        cmp bx,word[indice]
        jb printH1

xor rcx,rcx

    ;Add p to H

    ;Avoid duplicates
    ;mov eax,dword[px]
    ;movzx ecx,word[indice]
    ;cmp word[tabHx+(ecx-1)*WORD],ax
    ;jne NoDuplicates
    ;mov eax,dword[py]
    ;cmp word[tabHy+(ecx-1)*WORD],ax
    ;jne NoDuplicates
    ;mov rbx,0
    ;jmp lfnextpoint

    ;NoDuplicates:


    mov eax,dword[px]
    movzx ecx,word[indice]
    mov word[tabHx+ecx*WORD],ax
    mov eax,dword[py]
    mov word[tabHy+ecx*WORD],ax
    inc word[indice]

    ; Init Q with next Point
    mov rbx,0
    lfnextpoint:

    mov eax,dword[px]
    cmp word[tabHx+rbx*WORD],ax
    jne endlfnextpoint ; Si Px == tabX[x]
    mov eax,dword[py]
    cmp word[tabHy+rbx*WORD],ax ; Et Py == tabX[y]
    jne endlfnextpoint

    cmp rbx,nbPoints-2
    jae Initw1st

    movzx eax,word[tabX+(rbx+1)*WORD]
    mov dword[qx],eax
    movzx eax,word[tabY+(rbx+1)*WORD]
    mov dword[qy],eax
    jmp endlfnextpoint

    Initw1st:
    movzx eax,word[tabX]
    mov dword[qx],eax
    movzx eax,word[tabY]
    mov dword[qy],eax
    jmp endlfnextpoint

    endlfnextpoint:
    inc rbx
    cmp rbx,nbPoints
    jb lfnextpoint

    cmp rbx,nbPoints
    ja genRandX

        ; Looping through Points
        mov rbx,0 ; i
        pointLoop:
        ; I = E[i]
        movzx eax,word[tabX+rbx*WORD]
        mov dword[ix],eax
        movzx eax,word[tabY+rbx*WORD]
        mov dword[iy],eax

        ; Px - Lx = 0
        mov eax,dword[px]
        cmp eax,dword[ix]
        jne DontTestIY
        mov eax,dword[py]
        cmp eax,dword[iy]
        je endPointLoop
        DontTestIY:



                ;mov rdi,fmt3i
                ;mov eax,dword[ix]
                ;mov rsi,rax
                ;mov eax,dword[iy]
                ;mov rdx,rax
                ;mov rax,0
                ;call printf

        ;Pour calculer l’orientation du triangle PIQ, on va utiliser le produit vectoriel entre les vecteurs
        ;PI et IQ . Si ce produit vectoriel est supérieur ou égal à 0, alors le triangle PIQ est orienté dans
        ;le sens des aiguilles d’une montre et le point I est un meilleur candidat que Q pour l’enveloppe.

        ; P = A / I = B / Q = C
        ; Check PIQ rotation. If ( ((𝑥𝐵𝐶 × 𝑦𝐴𝐵) − (𝑥𝐴𝐵 × 𝑦𝐵𝐶)) >= 0); Q = I
        ; Check PIQ rotation. If ( ((𝑥IQ × 𝑦PI) − (𝑥PI × 𝑦IQ)) >= 0); Q = I

        ; 𝑥𝐴𝐵 = 𝑥𝐵 − 𝑥𝐴
        ; 𝑦𝐴𝐵 = 𝑦𝐵 − 𝑦𝐴

        ; Need x,y AB and x,y BC
        ; Need x,y PI and x,y IQ

        ; --> x,y PI
        ; PIx = xI - xP
        mov rax,0
        mov eax,dword[ix]
        sub eax,dword[px]
        mov dword[PIx],eax

        ;mov rdi,fmtxAB
        ;mov rsi,rax
        ;mov rdx,qword[ix]
        ;mov rcx,qword[px]
        ;mov rax,0
        ;call printf

        ; PIy = yI - yP
        mov eax,dword[iy]
        sub eax,dword[py]
        mov dword[PIy],eax

        ;mov rdi,fmtyAB
        ;mov rsi,rax
        ;mov rdx,qword[iy]
        ;mov rcx,qword[py]
        ;mov rax,0
        ;call printf

        ; --> x,y IQ
        ; IQx = xQ - xI
        mov eax,dword[qx]
        sub eax,dword[ix]
        mov dword[IQx],eax

        ; IQy = yQ - yI
        mov eax,dword[qy]
        sub eax,dword[iy]
        mov dword[IQy],eax

        mov rcx,0

        ; (𝑥𝐵𝐶 × 𝑦𝐴𝐵) − (𝑥𝐴𝐵 × 𝑦𝐵𝐶)
        ; (𝑥𝐵𝐶 × 𝑦𝐴𝐵)
        mov eax,dword[IQx]
        mul dword[PIy]
        mov rcx,rax

        ; (𝑥𝐴𝐵 × 𝑦𝐵𝐶)
        mov eax,dword[PIx]
        mul dword[IQy]

        sub ecx,eax
        jns Clockwise

        ; result : (𝑥IQ × 𝑦PI) − (𝑥PI × 𝑦IQ)
        
        mov eax,dword[ix]
        mov dword[qx],eax
        ; Qy = Iy
        mov eax,dword[iy]
        mov dword[qy],eax


        Clockwise:
                ;mov rdi,fmt3qout
                ;mov eax,dword[qx]
                ;mov rsi,rax
                ;mov eax,dword[qy]
                ;mov rdx,rax
                ;mov rcx,rcx
                ;mov rax,0
                ;call printf

        endPointLoop:
        inc rbx
        cmp rbx,nbPoints
        jne pointLoop

;couleur de la ligne 1
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0x000000	; Couleur du crayon ; noir
call XSetForeground
; coordonnées de la ligne 1 (noire)


; dessin de la ligne 1
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,dword[px]	; coordonnée source en x
mov r8d,dword[py]	; coordonnée source en y
mov r9d,dword[qx]	; coordonnée destination en x
push qword[qy]		; coordonnée destination en y
call XDrawLine

;mov rax,0
;mov rdi,fmtxy1
;mov eax,dword[px]
;mov rsi,rax
;mov eax,dword[py]
;mov rdx,rax
;mov rax,0
;call printf

;mov rdi,fmtxy2
;mov eax,dword[qx]
;mov rsi,rax
;mov eax,dword[qy]
;mov rdx,rax
;mov rax,0
;call printf


    ; P = Q
    mov eax,dword[qx]
    mov dword[px],eax
    mov eax,dword[qy]
    mov dword[py],eax

;mov rdi,fmt3p
;mov eax,dword[px]
;mov rsi,rax
;mov eax,dword[py]
;mov rdx,rax
;movzx rcx,word[indice]
;mov rax,0
;call printf

; Px == Lx
mov eax,dword[px]
cmp eax,dword[lx]
jne DontTestY
mov eax,dword[py]
cmp eax,dword[ly]
je printH
DontTestY:

jmp AddPtoH ; if P not equal to L continue
;mov rdi,fmt
;mov rsi,rax
;mov rax,0
;call printf

;mov rcx,0
    printH:

    mov rdi,fmt3h
    movzx rsi,word[tabHx+rbx*WORD]
    movzx rdx,word[tabHy+rbx*WORD]
    mov rax,0
    call printf
    inc rcx
    cmp bx,word[indice]
    jb printH

cmp rbx,nbPoints
ja genRandX;

inc rbx
cmp bx,word[indice]
jb printH

 genRandX:
        rdrand ax ; Génération d'un nombre aléatoire
        jc goodx ; Si CF=1, la valeur est valide et on sort de la boucle
        jmp genRandX ; Sinon, on recommence

        subRandX:
        sub rax,windowSize
        cmp rax,windowSize
        ja subRandX


        goodx:
            cmp eax, windowSize
            ja genRandX ; Si le nombre est supérieur à la taille de la fenêtre, on recommence
            cmp ax, 0
            jbe genRandX ; Si le nombre est inférieur ou égal à 0, on recommence
            mov dword[randPointx],eax
 genRandY:
         rdrand ax ; Génération d'un nombre aléatoire
         jc goody ; Si CF=1, la valeur est valide et on sort de la boucle
         jmp genRandY ; Sinon, on recommence

        subRandY:
                sub rax,windowSize
                cmp rax,windowSize
                ja subRandY

         goody:
             cmp eax, windowSize
             ja genRandY ; Si le nombre est supérieur à la taille de la fenêtre, on recommence
             cmp ax, 0
             jbe genRandY ; Si le nombre est inférieur ou égal à 0, on recommence
         mov dword[randPointy],eax

         xor rax,rax
         mov rdi,fmtPointXY
         mov eax,dword[randPointx]
         mov rsi,rax
         mov eax,dword[randPointy]
         mov rdx,rax
         mov rax,0
         call printf


         ;couleur du point 1
         mov rdi,qword[display_name]
         mov rsi,qword[gc]
         mov edx,0xFF0000	; Couleur du crayon ; rouge
         call XSetForeground


         mov rdi,qword[display_name]
         mov rsi,qword[window]
         mov rdx,qword[gc]
         movsx rcx,dword[randPointx]		; coordonnée en x du point
         sub ecx,3
         push rax
         movsx r8,dword[randPointy] 		; coordonnée en y du point
         sub r8,3
         mov r9,6
         mov rax,23040
         push rax
         push 0
         push r9
         call XFillArc

        ; calcul de l'orientation avec A = H[i], B = randPoint et C = H[i+1]

           mov rbx,0
           mov byte[isLeft],0
          isRandPointIn:
                mov rax,0
                mov rcx,0

                ; Init 1 with tabH[i] or tabH[indice] if i=0
                ;cmp bx,-1
                ;jne InitA0

                ;mov rcx,0

                ;mov cx,word[indice]
                ;dec cx
                ;mov ax,word[tabHx+ecx*WORD]
                ;mov dword[px],eax
                ;mov ax,word[tabHy+ecx*WORD]
                ;mov dword[py],eax

                ;jmp DontInitA2time
                ;InitA0:

                mov ax,word[tabHx+rbx*WORD]
                mov dword[px],eax
                mov ax,word[tabHy+rbx*WORD]
                mov dword[py],eax
                DontInitA2time:



                ; print A
                mov rdi,fmt3p
                mov eax,dword[px]
                mov rsi,rax
                mov eax,dword[py]
                mov rdx,rax
                mov rcx,rbx
                mov rax,0
                call printf

                ; Init B with tabH[i+1] or tabH[0] if i=0
                mov ax,word[indice]
                dec ax
                cmp bx,ax
                jne InitB0

                mov rcx,0

                mov ax,word[tabHx]
                mov dword[qx],eax
                mov ax,word[tabHy]
                mov dword[qy],eax

                jmp DontInitB2time
                InitB0:

                mov ax,word[tabHx+(rbx+1)*WORD]
                mov dword[qx],eax
                mov ax,word[tabHy+(rbx+1)*WORD]
                mov dword[qy],eax
                DontInitB2time:

                ; print B
                mov rdi,fmt3q
                mov eax,dword[qx]
                mov rsi,rax
                mov eax,dword[qy]
                mov rdx,rax
                mov rcx,rbx
                mov rax,0
                call printf

                ; Init C with randPoint
                mov eax,dword[randPointx]
                mov dword[ix],eax

                mov eax,dword[randPointy]
                mov dword[iy],eax


                                ; PIy = Ix - Px
                                mov eax,dword[ix]
                                sub eax,dword[px]
                                mov dword[PIx],eax


                                ;mov rdi,fmtxAB
                                ;mov eax,dword[PIx]
                                ;mov rsi,rax
                                ;mov eax,dword[ix]
                                ;mov rdx,rax
                                ;mov eax,dword[px]
                                ;mov rcx,rax
                                ;mov rax,0
                                ;call printf


                                ; PIy = yI - yP
                                mov eax,dword[iy]
                                sub eax,dword[py]
                                mov dword[PIy],eax

                                ;mov rdi,fmtyAB
                                ;mov eax,dword[PIy]
                                ;mov rsi,rax
                                ;mov eax,dword[iy]
                                ;mov rdx,rax
                                ;mov eax,dword[py]
                                ;mov rcx,rax
                                ;mov rax,0
                                ;call printf

                                ; --> x,y IQ
                                ; IQx = xQ - xI
                                mov eax,dword[qx]
                                sub eax,dword[ix]
                                mov dword[IQx],eax

                                ;mov rdi,fmtxBC
                                ;mov eax,dword[IQx]
                                ;mov rsi,rax
                                ;mov eax,dword[qx]
                                ;mov rdx,rax
                                ;mov eax,dword[ix]
                                ;mov rcx,rax
                                ;mov rax,0
                                ;call printf


                                ; IQy = yQ - yI
                                mov eax,dword[qy]
                                sub eax,dword[iy]
                                mov dword[IQy],eax


                                ;mov rdi,fmtyBC
                                ;mov eax,dword[IQy]
                                ;mov rsi,rax
                                ;mov eax,dword[qy]
                                ;mov rdx,rax
                                ;mov eax,dword[iy]
                                ;mov rcx,rax
                                ;mov rax,0
                                ;call printf



                                mov rcx,0
                                mov rax,0

                        mov rdi,fmtMul
                        mov eax,dword[IQx]
                        mov rsi,rax
                        mov eax,dword[PIy]
                        mov rdx,rax
                        mov eax,dword[PIx]
                        mov rcx,rax
                        mov eax,dword[IQy]
                        mov r8,rax
                        mov rax,0
                        call printf

                        ; (𝑥𝐵𝐶 × 𝑦𝐴𝐵) − (𝑥𝐴𝐵 × 𝑦𝐵𝐶)
                        ; (𝑥𝐵𝐶 × 𝑦𝐴𝐵)
                        mov eax,dword[IQx]
                        mul dword[PIy]
                        mov rcx,rax

                        ;mov rdi,fmtxBCyAB
                        ;mov rsi,rcx
                        ;xor rax,rax
                        ;mov eax,dword[IQx]
                        ;mov rdx,rax
                        ;mov eax,dword[PIy]
                        ;mov rcx,rax
                        ;mov rax,0
                        ;call printf



                        ; (𝑥𝐴𝐵 × 𝑦𝐵𝐶)
                        mov eax,dword[PIx]
                        mul dword[IQy]

                        ;push rbp
                        ;mov rdi,fmtxAByBC
                        ;mov rsi,rax
                        ;xor rax,rax
                        ;mov eax,dword[PIx]
                        ;mov rdx,rax
                        ;mov eax,dword[IQy]
                        ;mov rcx,rax
                        ;mov rax,0
                        ;call printf
                        ;pop rbp


                sub rcx,rax
                js incLeftNum ; If sign then point is left
                mov rcx,rax

                push rbp
                mov rdi,fmt
                mov rsi,rcx
                mov rax,0
                call printf
                pop rbp


                ;decLeftNum:
                ;dec byte[isLeft]

                ;mov rdi,fmtWD
                ;movzx rsi,byte[isLeft]
                ;mov rax,0
                ;call printf
                ;mov rdi,segf
                ;mov rax,0
                ;call printf
                
                jmp endisRandPointIn

                incLeftNum:
                 push rbp
                 mov rdi,fmt
                 mov rsi,rcx
                 mov rax,0
                 call printf
                 pop rbp

                inc byte[isLeft]
                mov rdi,fmtWD
                movzx rsi,byte[isLeft]
                mov rax,0
                mov ax,word[indice]
                mov rdx,rax
                mov rax,0
                call printf
                jmp endisRandPointIn

                endisRandPointIn:
                inc rbx
                cmp bx,word[indice]
                jb isRandPointIn
                mov cx,word[indice]
                cmp byte[isLeft],cl
                jne NotIn ; If isLeft != indice, all points aren't left

                ItIsIn:
                mov rdi,pointIsIn
                mov rsi,qword[qx]
                mov rdx,qword[qy]
                mov rax,0
                call printf
                jmp finDessin


                NotIn:
                inc byte[isLeft]
                jpe ItIsIn ; If isLeft is odd, it's probably in

                mov rdi,pointIsOut
                mov rsi,qword[qx]
                mov rdx,qword[qy]
                mov rax,0
                call printf
                jmp finDessin


pop rbp
finDessin:

; ############################
; # FIN DE LA ZONE DE DESSIN #
; ############################
jmp flush

flush:
mov rdi,qword[display_name]
call XFlush
jmp boucle
mov rax,34
syscall

closeDisplay:
    mov     rax,qword[display_name]
    mov     rdi,rax
    call    XCloseDisplay
    xor	    rdi,rdi
    call    exit

global randomNumber
randomNumber:

    generationX:
        rdrand rax ; Génération d'un nombre aléatoire
        jc good1 ; Si CF=1, la valeur est valide et on sort de la boucle
        jmp generationX ; Sinon, on recommence

        good1:
            cmp ax, windowSize
            ja generationX ; Si le nombre est supérieur à la taille de la fenêtre, on recommence
            cmp ax, 0
            jbe generationX ; Si le nombre est inférieur ou égal à 0, on recommence

            ;stockage dans le tableau
            movzx ecx, word[indice] ; On récupère l'indice du tableau
            mov tabX[ecx*WORD], ax ; On stocke le nombre dans le tableau

    ;code pour voir le tableau
	;mov rdi, printIndice
	;movzx rsi, word[indice]
	;movzx rdx, word[tabX + ecx*WORD]
	;mov rax, 0
	;call printf

    inc word[indice] ; On incrémente l'indice du tableau

    cmp word[indice], nbPoints ; On compare l'indice au nombre de points
    jne generationX ; Si l'indice est inférieur au nombre de points, on recommence



    ;fin du tableau de X



    mov word[indice], 0 ; On remet l'indice à 0
    generationY:
        rdrand rax ; Génération d'un nombre aléatoire
        jc good2 ; Si CF=1, la valeur est valide et on sort de la boucle
        jmp generationY ; Sinon, on recommence

        good2:
            cmp ax, windowSize
            ja generationY ; Si le nombre est supérieur à la taille de la fenêtre, on recommence
            cmp ax, 0
            jbe generationY ; Si le nombre est inférieur ou égal à 0, on recommence

            ;stockage dans le tableau
            movzx ecx, word[indice] ; On récupère l'indice du tableau
            mov tabY[ecx*WORD], ax ; On stocke le nombre dans le tableau

    ;code pour voir le tableau
	;mov rdi, printIndice
	;movzx rsi, word[indice]
	;movzx rdx, word[tabY + ecx*WORD]
	;mov rax, 0
	;call printf

    inc word[indice] ; On incrémente l'indice du tableau

    cmp word[indice], nbPoints ; On compare l'indice au nombre de points
    jne generationY ; Si l'indice est inférieur au nombre de points, on recommence

ret
