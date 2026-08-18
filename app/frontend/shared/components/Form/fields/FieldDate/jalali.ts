// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

// Jalali (Solar Hijri / Shamsi) calendar utilities.
// Conversion algorithm adapted from jalaali-js (MIT licence).
// https://github.com/jalaali/jalaali-js
//
// The MIT License (MIT)
// Copyright (c) 2014 Reza Akhlaghpour
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.

function _div(a: number, b: number): number {
  return Math.trunc(a / b)
}

function _mod(a: number, b: number): number {
  return a - Math.trunc(a / b) * b
}

// Years where the official Iranian astronomical calendar (Taqvim-e Rasmi) places
// Nowruz 1 day later than the algorithmic 2820-year cycle predicts. Add entries
// as they are confirmed against the official calendar.
const NOWRUZ_CORRECTION: Record<number, number> = {
  1405: 1, // Nowruz 1405 = 21 March 2026; algorithm gives 20 March 2026
  1406: 1, // Nowruz 1406 = 21 March 2027; algorithm gives 20 March 2027
}

function jalCal(jy: number): { leap: number; gy: number; march: number } {
  const breaks = [
    -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, 2097, 2192, 2262, 2324,
    2394, 2456, 3178,
  ]
  const gy = jy + 621
  let leapJ = -14
  let jp = breaks[0]

  for (let i = 1; i < breaks.length; i++) {
    const jm = breaks[i]
    const jump = jm - jp
    if (jy < jm) {
      let n = jy - jp
      leapJ += _div(n, 33) * 8 + _div(_mod(n, 33), 4)
      const leapG = _div(gy, 4) - _div((_div(gy, 100) + 1) * 3, 4) - 150
      const march = 20 + leapJ - leapG + (NOWRUZ_CORRECTION[jy] ?? 0)
      if (jump - n < 6) n = n - jump + _div(jump + 4, 33) * 33
      let leap = _mod(_mod(n + 1, 33) - 1, 4)
      if (leap === -1) leap = 4
      return { leap, gy, march }
    }
    leapJ += _div(jump, 33) * 8 + _div(_mod(jump, 33), 4)
    jp = jm
  }
  throw new Error(`Jalali year ${jy} is outside the supported range.`)
}

function g2d(gy: number, gm: number, gd: number): number {
  return (
    _div((gy + _div(gm - 8, 6) + 100100) * 1461, 4) +
    _div(153 * _mod(gm + 9, 12) + 2, 5) +
    gd -
    34840408 -
    _div(_div(gy + 100100 + _div(gm - 8, 6), 100) * 3, 4) +
    752
  )
}

function d2g(jdn: number): { gy: number; gm: number; gd: number } {
  let j = 4 * jdn + 139361631
  j += _div(_div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908
  const i = _div(_mod(j, 1461), 4) * 5 + 308
  const gd = _div(_mod(i, 153), 5) + 1
  const gm = _mod(_div(i, 153), 12) + 1
  const gy = _div(j, 1461) - 100100 + _div(8 - gm, 6)
  return { gy, gm, gd }
}

function j2d(jy: number, jm: number, jd: number): number {
  const r = jalCal(jy)
  return g2d(r.gy, 3, r.march) + (jm - 1) * 30 + Math.min(jm, 7) - 1 + jd - 1
}

function d2j(jdn: number): { jy: number; jm: number; jd: number } {
  const { gy } = d2g(jdn)
  let jy = gy - 621
  const r = jalCal(jy)
  const jdn1f = g2d(gy, 3, r.march)
  let k = jdn - jdn1f
  if (k >= 0) {
    if (k <= 185) {
      return { jy, jm: 1 + _div(k, 31), jd: _mod(k, 31) + 1 }
    }
    k -= 186
  } else {
    jy -= 1
    k += 179
    if (jalCal(jy).leap === 1) k += 1
  }
  const jm = 7 + _div(k, 30)
  const jd = _mod(k, 30) + 1
  return { jy, jm, jd }
}

// ── Public API ────────────────────────────────────────────────────────────────

/** Convert a Gregorian Date to Jalali {jy, jm, jd}. */
export function dateToJalali(date: Date): { jy: number; jm: number; jd: number } {
  return d2j(g2d(date.getFullYear(), date.getMonth() + 1, date.getDate()))
}

/** Convert a Jalali {jy, jm, jd} to a Gregorian Date. */
export function jalaliToDate(jy: number, jm: number, jd: number): Date {
  const { gy, gm, gd } = d2g(j2d(jy, jm, jd))
  return new Date(gy, gm - 1, gd)
}

/** Number of days in a given Jalali month. */
export function jalaliMonthLength(jy: number, jm: number): number {
  if (jm <= 6) return 31
  if (jm <= 11) return 30
  return jalCal(jy).leap === 0 ? 30 : 29
}

export const JALALI_MONTH_NAMES = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
] as const

/** Week-day short names starting from Saturday (Iranian week start). */
export const JALALI_WEEKDAY_SHORT = ['ش', 'ی', 'د', 'سه', 'چ', 'پ', 'ج'] as const

export function jalaliMonthName(jm: number): string {
  return JALALI_MONTH_NAMES[jm - 1] ?? ''
}

/** Replace ASCII digits 0-9 with Eastern Arabic (Persian) equivalents. */
export function toPersianDigits(value: string | number): string {
  return String(value).replace(/[0-9]/g, (d) => String.fromCharCode(0x06f0 + Number(d)))
}
