/* -*-c-*- */

%{
/*
 * scan_netlist.l - scanner for the Qucs netlist
 *
 * Copyright (C) 2003-2009 Stefan Jahn <stefan@lkcc.org>
 *
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this package; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street - Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 * $Id$
 *
 */

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-register"
#endif

#if HAVE_CONFIG_H
# include <config.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#ifdef __MINGW32__
#include <io.h>
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#include "logging.h"
#include "equation.h"
#include "check_netlist.h"
#include "tokens_netlist.h"

#if !HAVE_STRCHR
# define strchr  index
# define strrchr rindex
#endif

using namespace qucs;

static double netlist_evaluate_scale (double val, char * scale) {
  double factor = 1.0;
  while (isspace (scale[0])) scale++;
  switch (scale[0]) {
  case 'E': factor = 1e+18; break;
  case 'P': factor = 1e+15; break;
  case 'T': factor = 1e+12; break;
  case 'G': factor = 1e+09; break;
  case 'M': factor = 1e+06; break;
  case 'k': factor = 1e+03; break;
  case 'm':
    if (scale[1] == 'i' && scale[2] == 'l')
      factor = 2.54e-5;
    else
      factor = 1e-03;
    break;
  case 'u': factor = 1e-06; break;
  case 'n': factor = 1e-09; break;
  case 'p': factor = 1e-12; break;
  case 'f':
    if (scale[1] == 't')
      factor = 0.3048;
    else
      factor = 1e-15;
    break;
  case 'a': factor = 1e-18; break;
  case 'd':
    if (scale[1] == 'B') {
      val = std::pow (10.0, val / 10.0);
      if (scale[2] == 'm')
	factor = 1e-03;
      else if (scale[2] == 'u')
	factor = 1e-06;
    }
    break;
  case 'i':
    if (scale[1] == 'n')
      factor = 2.54e-2;
    break;
  case 'y':
    if (scale[1] == 'd')
      factor = 0.9144;
    break;
  }
  return val * factor;
}

%}

WS       [ \t\n\r]
SIMPLEID [a-zA-Z_][a-zA-Z0-9_]*
POSTID   "."[a-zA-Z0-9_]+
ID       {SIMPLEID}{POSTID}*
NODE     {SIMPLEID}\!?
FILE     "{"[^\t\n\r\}]+"}"
CHR      "'"[^\n\r\']{1}"'"
STR      "'"[^\n\r\']*"'"
DIGIT    [0-9]
EXPONENT [Ee][+-]?{DIGIT}+
PFX1     ("E"|"P"|"T"|"G"|"M"|"k"|"m"|"u"|"n"|"p"|"f"|"a")
PFX2     ("mil"|"in"|"ft"|"yd")
PFX3     ("dBu"|"dBm"|"dB")
PFX      ({PFX1}|{PFX3})
UNT      ("Ohm"|"S"|"s"|"K"|"H"|"F"|"Hz"|"V"|"A"|"W"|"m")
EXCEPT   ("mm"|{PFX2})
SU       ({PFX}|{UNT}|{PFX}{UNT}|{EXCEPT})
SPACE    [ \t]
RINT     [+-]?{DIGIT}+
IINT     [+-]?[ij]{1}{DIGIT}*
RFLOAT1  [+-]?{DIGIT}+{EXPONENT}
RFLOAT2  [+-]?{DIGIT}*"."{DIGIT}+({EXPONENT})?
IFLOAT1  [+-]?[ij]{1}{DIGIT}+{EXPONENT}
IFLOAT2  [+-]?[ij]{1}{DIGIT}*"."{DIGIT}+({EXPONENT})?
CREAL    ({RFLOAT1}|{RFLOAT2}|{RINT})
CIMAG    ({IFLOAT1}|{IFLOAT2}|{IINT})
COMPLEX  {CREAL}{CIMAG}
URINT    {DIGIT}+
UIINT    [ij]{1}{DIGIT}*
URFLOAT1 {DIGIT}+{EXPONENT}
URFLOAT2 {DIGIT}*"."{DIGIT}+({EXPONENT})?
UIFLOAT1 [ij]{1}{DIGIT}+{EXPONENT}
UIFLOAT2 [ij]{1}{DIGIT}*"."{DIGIT}+({EXPONENT})?
UCREAL   ({URFLOAT1}|{URFLOAT2}|{URINT})({SPACE})*({PFX})?
UCIMAG   ({UIFLOAT1}|{UIFLOAT2}|{UIINT})({SPACE})*({PFX})?
UCOMPLEX {UCREAL}{UCIMAG}


%x COMMENT STR EQN
%option yylineno noyywrap nounput noinput prefix="netlist_"

%%

<INITIAL,STR>{SU} { /* identify scale and/or unit */
    netlist_lval.str = strdup (netlist_text);
    return ScaleOrUnit;
  }
<INITIAL>"Eqn" { /* special equation case */
    BEGIN(EQN);
    return Eqn;
  }
<INITIAL>"."{SPACE}*"Def"{SPACE}*":" {
    /* subcircuit definition begins */
    return DefSub;
  }
<INITIAL>"."{SPACE}*"Def"{SPACE}*":"{SPACE}*"End" {
    /* subcircuit definition ends */
    return EndSub;
  }
<INITIAL,STR>{ID} { /* identify identifier */
    netlist_lval.ident = strdup (netlist_text);
    return Identifier;
  }
<INITIAL>{NODE} { /* identify node identifier */
    netlist_lval.ident = strdup (netlist_text);
    return Identifier;
  }
<INITIAL,STR>{FILE} { /* identify file reference */
    char * p = strrchr (netlist_text, '}'); *p = '\0';
    netlist_lval.ident = strdup (&netlist_text[1]);
    return Identifier;
  }
<INITIAL,STR>{CREAL} { /* identify (signed) real float */
    netlist_lval.d = strtod (netlist_text, NULL);
    return REAL;
  }
<INITIAL,STR>{CIMAG} { /* identify (signed) imaginary float */
    if (netlist_text[0] == 'i' || netlist_text[0] == 'j')
      netlist_text[0] = (netlist_text[1] == '\0') ? '1' : '0';
    else
      netlist_text[1] = '0';
    netlist_lval.d = strtod (netlist_text, NULL);
    return IMAG;
  }
<INITIAL,STR>{COMPLEX} { /* identify complete (signed) complex number */
    int i = 0;
    while (netlist_text[i] != 'i' && netlist_text[i] != 'j') i++;
    netlist_text[i] = netlist_text[i - 1];
    netlist_text[i - 1] = '\0';
    netlist_lval.c.r = strtod (netlist_text, NULL);
    netlist_lval.c.i = strtod (&netlist_text[i], NULL);
    return COMPLEX;
  }
<INITIAL,EQN>{ID}{SPACE}*=[^=] {  /* identify 'identifier =' assign */
    int len = netlist_leng - 3;
    while (isspace (netlist_text[len])) len--;
    netlist_lval.ident = (char *) calloc (len + 2, 1);
    memcpy (netlist_lval.ident, netlist_text, len + 1);
    yyless (netlist_leng - 1); /* push back last character */
    return Assign;
  }

<INITIAL,STR>"[" { /* special token for the value list */ return '['; }
<INITIAL,STR>"]" { /* special token for the value list */ return ']'; }
<INITIAL,STR>";" { /* special token for the value list */ return ';'; }

<INITIAL>"."   { /* pass the '.' to the parser */ return '.'; }
<INITIAL>":"   { /* pass the ':' to the parser */ return ':'; }
<INITIAL>"="   { /* pass the '=' to the parser */ return '='; }
<INITIAL>\r?\n { /* detect end of line */ return Eol; }

<INITIAL,EQN>{SPACE}|\\\r?\n /* skip spaces and the trailing '\' */

<INITIAL>"#" { /* leave these characters */
    BEGIN(COMMENT);
  }
<INITIAL>\" { /* string constant starts here */
    BEGIN(STR);
    return '"';
  }
<INITIAL>. { /* any other character in invalid */
    logprint (LOG_ERROR,
	      "line %d: syntax error, unrecognized character: `%s'\n",
	      netlist_lineno, netlist_text);
    return InvalidCharacter;
  }

<COMMENT>. { /* skip any character in here */ }
<COMMENT>\r?\n { BEGIN(INITIAL); /* skipping ends here */ }

<STR>\" { /* string constant ends here */
    BEGIN(INITIAL);
    return '"';
  }
<STR>\r?\n { /* string in a single line only */
    logprint (LOG_ERROR,
	      "line %d: syntax error, unterminated string constant\n",
	      netlist_lineno);
    return Eol;
  }
<STR,EQN>{SPACE} /* skip spaces */

<STR>. { /* any other character is invalid */
    logprint (LOG_ERROR,
	      "line %d: syntax error, unrecognized character: `%s'\n",
	      netlist_lineno, netlist_text);
    return InvalidCharacter;
  }

<EQN>[-+*/%(),^:\"\[\]\?] { /* return operators unchanged */
    return netlist_text[0];
  }

<EQN>">=" { return GreaterOrEqual; }
<EQN>"<=" { return LessOrEqual; }
<EQN>"!=" { return NotEqual; }
<EQN>"==" { return Equal; }
<EQN>"&&" { return And; }
<EQN>"||" { return Or; }
<EQN>"<"  { return Less; }
<EQN>">"  { return Greater; }
<EQN>"!"  { return Not; }

<EQN>[,;] { /* special tokens for vectors / matrices */
    return netlist_text[0];
  }

<EQN>{UCREAL} { /* identify unsigned real float */
    char * endptr = NULL;
    netlist_lval.d = strtod (netlist_text, &endptr);
    netlist_lval.d = netlist_evaluate_scale (netlist_lval.d, endptr);
    return REAL;
  }
<EQN>{UCIMAG} { /* identify unsigned imaginary float */
    if (netlist_text[0] == 'i' || netlist_text[0] == 'j')
      netlist_text[0] = (netlist_text[1] == '\0') ? '1' : '0';
    else
      netlist_text[1] = '0';
    char * endptr = NULL;
    netlist_lval.d = strtod (netlist_text, &endptr);
    netlist_lval.d = netlist_evaluate_scale (netlist_lval.d, endptr);
    return IMAG;
  }
<EQN>{ID} { /* identify identifier */
    netlist_lval.ident = strdup (netlist_text);
    return Identifier;
  }
<EQN>{CHR} {
    netlist_lval.chr = netlist_text[1];
    return Character;
  }
<EQN>{STR} {
    netlist_lval.str = strdup (&netlist_text[1]);
    netlist_lval.str[strlen (netlist_lval.str) - 1] = '\0';
    return STRING;
  }
<EQN>\r?\n { /* detect end of line */ BEGIN(INITIAL); return Eol; }

<EQN>. { /* any other character in invalid */
    logprint (LOG_ERROR,
	      "line %d: syntax error, unrecognized character: `%s'\n",
	      netlist_lineno, netlist_text);
    return InvalidCharacter;
  }

%%
