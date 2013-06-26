/*
 * trsolver.h - transient solver class definitions
 *
 * Copyright (C) 2004, 2005, 2006, 2007, 2008 Stefan Jahn <stefan@lkcc.org>
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

#ifndef __M_TRSOLVER_H__
#define __M_TRSOLVER_H__

class m_trsolver : public trsolver
{
public:

    m_trsolver (char *);
    m_trsolver (trsolver &);
    ~m_trsolver ();

private:

    int MaxIterations;
    nr_double_t reltol;
    nr_double_t abstol;
    nr_double_t vntol;
    nr_double_t time;
    nr_double_t saveCurrent;
    int running;
    int rejected;

};

#endif /* __M_TRSOLVER_H__ */
