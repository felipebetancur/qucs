/*
 * cpwshort.cpp - coplanar waveguide short class implementation
 *
 * Copyright (C) 2005 Stefan Jahn <stefan@lkcc.org>
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
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * $Id: cpwshort.cpp,v 1.1 2005/05/02 06:51:01 raimi Exp $
 *
 */

#if HAVE_CONFIG_H
# include <config.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "logging.h"
#include "complex.h"
#include "object.h"
#include "node.h"
#include "circuit.h"
#include "component_id.h"
#include "substrate.h"
#include "constants.h"
#include "cpwshort.h"
#include "cpwline.h"

cpwshort::cpwshort () : circuit (1) {
  type = CIR_CPWSHORT;
}

// Returns the coplanar short inductance.
nr_double_t cpwshort::calcLend (nr_double_t frequency) {

  // get properties of substrate and coplanar open
  nr_double_t W =  getPropertyDouble ("W");
  nr_double_t s =  getPropertyDouble ("S");
  substrate * subst = getSubstrate ();
  nr_double_t er = subst->getPropertyDouble ("er");
  nr_double_t h  = subst->getPropertyDouble ("h");
  nr_double_t t  = subst->getPropertyDouble ("t");
  int backMetal  = !strcmp (getPropertyString ("Backside"), "Metal");

  nr_double_t ZlEff, ErEff, ZlEffFreq, ErEffFreq;
  cpwline::analyseQuasiStatic (W, s, h, t, er, backMetal, ZlEff, ErEff);
  cpwline::analyseDispersion  (W, s, h, er, ZlEff, ErEff, frequency,
			       ZlEffFreq, ErEffFreq);
  nr_double_t dl = (W / 2 + s) / 4;
  return dl * ErEffFreq / C0 * ZlEffFreq;
}

void cpwshort::initSP (void) {
  allocMatrixS ();
  checkProperties ();
}

void cpwshort::calcSP (nr_double_t frequency) {
  setS (NODE_1, NODE_1, ztor (calcZ (frequency)));
}

void cpwshort::checkProperties (void) {
  nr_double_t s = getPropertyDouble ("S");
  substrate * subst = getSubstrate ();
  nr_double_t t = subst->getPropertyDouble ("t");
  if (t >= s / 3) {
    logprint (LOG_ERROR, "WARNING: Model for coplanar short valid for "
	      "t < s/3 (s/3 = %g)\n", s / 3);
  }
}

complex cpwshort::calcZ (nr_double_t frequency) {
  nr_double_t o = 2 * M_PI * frequency;
  nr_double_t l = calcLend (frequency);
  return rect (0, l * o);
}

void cpwshort::initDC (void) {
  setVoltageSources (1);
  setInternalVoltageSource (1);
  allocMatrixMNA ();
  setY (NODE_1, NODE_1, 0);
  setB (NODE_1, VSRC_1, 1);
  setC (VSRC_1, NODE_1, 1);
  setD (VSRC_1, VSRC_1, 0);
  setE (VSRC_1, 0);
}

void cpwshort::initAC (void) {
  setVoltageSources (0);
  allocMatrixMNA ();
  checkProperties ();
}

void cpwshort::calcAC (nr_double_t frequency) {
  setY (NODE_1, NODE_1, 1 / calcZ (frequency));
}