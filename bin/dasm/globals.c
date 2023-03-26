/*
 *  GLOBALS.C
 *
 *  (c)Copyright 1988, Matthew Dillon, All Rights Reserved.
 *  Modifications Copyright 1995 by Olaf Seibert. All Rights Reserved.
 *
 */

#include "asm.h"

SYMBOL *SHash[SHASHSIZE];   /*	symbol hash table   */
MNE    *MHash[MHASHSIZE];   /*	mnemonic hash table */
INCFILE *Incfile;	    /*	include file stack  */
REPLOOP *Reploop;	    /*	repeat loop stack   */
SEGMENT *Seglist;	    /*	segment list	    */
SEGMENT *Csegment;	    /*	current segment     */
IFSTACK *Ifstack;	    /*	IF/ELSE/ENDIF stack */
char	*Av[256];	    /*	up to 256 arguments */
char	Avbuf[512];
ubyte	MsbOrder = 1;
int	Mnext;
char	Inclevel;
uword	Mlevel;
long	Localindex;	   /*  to generate local variables */
long	Lastlocalindex;
#if OlafDol
long	Localdollarindex;
long	Lastlocaldollarindex;
#endif
long	Processor;
ubyte	Xdebug, Xtrace;
ubyte	Outputformat;
long	Redo, Redo_why;
long	Redo_eval;	   /*  infinite loop detection only    */
#if OlafPhase
long	Redo_if;
#endif
char	ListMode = 1;
long	CheckSum;	    /*	output data checksum		*/


ubyte	 F_format = 1;
ubyte	 F_verbose = 3;
char	*F_outfile = "a.out";
char	*F_listfile;
char	*F_symfile;
char	*F_temppath = "ram:";
FILE	*FI_listfile;
FILE	*FI_temp;
ubyte	 Fisclear;
long	 Plab, Pflags;

uword	Adrbytes[]  = { 1, 2, 3, 2, 2, 2, 3, 3, 3, 2, 2, 2, 3, 1, 1, 2, 3 };
uword	Cvt[]	    = { 0, 2, 0, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0, 4, 5, 0, 0 };
uword	Opsize[]    = { 0, 1, 2, 1, 1, 1, 2, 2, 2, 2, 1, 1, 2, 0, 0, 1, 1 };

MNE Ops[] = {
    { NULL, v_list    , "list",           0,      0, },
    { NULL, v_include , "include",        0,      0, },
    { NULL, v_seg     , "seg",            0,      0, },
    { NULL, v_hex     , "hex",            0,      0, },
    { NULL, v_err     , "err",            0,      0, },
    { NULL, v_dc      , "dc",             0,      0, },
#if OlafByte
    { NULL, v_dc      , "byte",           0,      0, },
    { NULL, v_dc      , "word",           0,      0, },
    { NULL, v_dc      , "long",           0,      0, },
#endif
    { NULL, v_ds      , "ds",             0,      0, },
    { NULL, v_dc      , "dv",             0,      0, },
    { NULL, v_end     , "end",            0,      0, },
    { NULL, v_trace   , "trace",          0,      0, },
    { NULL, v_org     , "org",            0,      0, },
    { NULL, v_rorg    , "rorg",           0,      0, },
    { NULL, v_rend    , "rend",           0,      0, },
    { NULL, v_align   , "align",          0,      0, },
    { NULL, v_subroutine, "subroutine",   0,      0, },
    { NULL, v_equ     , "equ",            0,      0, },
#if OlafAsgn
    { NULL, v_equ     , "=",              0,      0, },
#endif
    { NULL, v_eqm     , "eqm",            0,      0, },
    { NULL, v_set     , "set",            0,      0, },
    { NULL, v_macro   , "mac",            MF_IF,  0, },
    { NULL, v_endm    , "endm",           MF_ENDM,0, },
    { NULL, v_mexit   , "mexit",          0,      0, },
    { NULL, v_ifconst , "ifconst",        MF_IF,  0, },
    { NULL, v_ifnconst, "ifnconst",       MF_IF,  0, },
    { NULL, v_if      , "if",             MF_IF,  0, },
    { NULL, v_else    , "else",           MF_IF,  0, },
    { NULL, v_endif   , "endif",          MF_IF,  0, },
    { NULL, v_endif   , "eif",            MF_IF,  0, },
    { NULL, v_repeat  , "repeat",         MF_IF,  0, },
    { NULL, v_repend  , "repend",         MF_IF,  0, },
    { NULL, v_echo    , "echo",           0,      0, },
    { NULL, v_processor,"processor",      0,      0, },
#if OlafIncbin
    { NULL, v_incbin,	"incbin",         0,      0, },
#endif
#if OlafIncdir
    { NULL, v_incdir,	"incdir",         0,      0, },
#endif
    { NULL, }
};

