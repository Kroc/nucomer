
/*
 *  FTOHEX.C
 *
 *  (c)Copyright 1988, Matthew Dillon, All Rights Reserved.
 *
 *  FTOHEX format infile [outfile]
 *
 *  format: format used when assembling (asm705/asm65)
 *	    1,2,3	    -generate straight hex file
 *
 *  compilable on an ibm-pc or Amiga  _fmode is for Lattice C on the ibm,
 *  is IGNORED by Aztec C on the Amiga.  Note that INT and CHAR are not
 *  used as ibm's lattice C uses 16 bit ints and unsigned chars.  Change
 *  as needed.	No guarentees for the IBMPC version.
 *  FTOHEX format infile [outfile]
 */

#include <stdio.h>
#include <stdlib.h>

typedef unsigned char ubyte;
typedef unsigned short uword;

#define PERLINE 16

void exiterr(char *str);
void convert(int format, FILE *in, FILE *out);
uword getwlh(FILE *in);
void puth(ubyte c, FILE *out);

uword _fmode = 0;

int
main(int ac, char **av)
{
    int format;
    FILE *infile;
    FILE *outfile;

    _fmode = 0x8000;
    if (ac < 3) {
	puts("FTOHEX format infile [outfile]");
	puts("format 1,2, or 3.  3=raw");
	puts("(C)Copyright 1987 by Matthew Dillon, All Rights Reserved");
	exit(1);
    }
    format = atoi(av[1]);
    if (format < 1 || format > 3)
	exiterr("specify infile format 1, 2, or 3");
    infile = fopen(av[2], "r");
    if (infile == NULL)
	exiterr("unable to open input file");
    outfile = (av[3]) ? fopen(av[3], "w") : stdout;
    if (outfile == NULL)
	exiterr("unable to open output file");
    convert(format, infile, outfile);
    fclose(infile);
    fclose(outfile);

    return 0;
}

void
exiterr(char *str)
{
    fputs(str, stderr);
    fputs("\n", stderr);
    exit(1);
}

/*
 *  Formats:
 *
 *  1:	  origin (word:lsb,msb) + data
 *  2:	  origin (word:lsb,msb) + length (word:lsb,msb) + data	(repeat)
 *  3:	  data
 *
 *  Hex output:
 *
 *  :lloooo00(ll bytes hex code)cc	  ll=# of bytes
 *		      oooo=origin
 *			cc=invert of checksum all codes
 */

void
convert(int format, FILE *in, FILE *out)
{
    uword org = 0;
    uword idx;
    long len;
    ubyte buf[256];

    if (format < 3)
    org = getwlh(in);
    if (format == 2) {
	len = getwlh(in);
    } else {
	long begin = ftell(in);
	fseek(in, 0, SEEK_END);
	len = ftell(in) - begin;
	fseek(in, begin, 0);
    }
    for (;;) {
	while (len > 0) {
	    register ubyte chk;
	    register int i;

	    idx = (len > PERLINE) ? PERLINE : len;
	    fread(buf, idx, 1, in);
	    putc(':', out);
	    puth(idx, out);
	    puth(org >> 8, out);
	    puth(org & 0xFF, out);
	    putc('0', out);
	    putc('0', out);
	    chk = idx + (org >> 8) + (org & 0xFF);
	    for (i = 0; i < idx; ++i) {
		chk += buf[i];
		puth(buf[i], out);
	    }
	    puth((ubyte)-chk, out);
	    putc('\r', out);
	    putc('\n', out);
	    len -= idx;
	    org += idx;
	}
	if (format == 2) {
	    org = getwlh(in);
	    if (feof(in))
		break;
	    len = getwlh(in);
	} else {
	    break;
	}
    }
    fprintf(out, ":00000001FF\r\n");
}

uword
getwlh(FILE *in)
{
    uword result;

    result = getc(in);
    result += getc(in) << 8;
    return(result);
}

void
puth(ubyte c, FILE *out)
{
    static char dig[] = { "0123456789ABCDEF" };
    putc(dig[c>>4], out);
    putc(dig[c&15], out);
}

