import strutils, strformat, math
when defined(posix):
  import posix
elif defined(windows):
  import winlean, std/time_t  

const NANO_SECOND* = 1.int64
const MICRO_SECOND* = 1000 * NANO_SECOND
const MILLI_SECOND* = 1000 * MICRO_SECOND
const SECOND* = 1000 * MILLI_SECOND
const MINUTE* = 60 * SECOND
const HOUR* = 60 * MINUTE
const DAY* = 24 * HOUR

# nano second since epoch time in GMT
type
  TimestampException = object of Exception
  TimestampInvalidFormatException* = object of TimestampException
  TimestampOutOfRangeException* = object of TimestampException
  Timestamp* = object
    self: int64

proc initTimestamp*(ns: int64): Timestamp = Timestamp(self: ns)

proc initTimestamp*(year, month, day: int, hour=0, minute=0, second=0, milli=0, micro=0, nano=0): Timestamp =
  # http://howardhinnant.github.io/date_algorithms.html#days_from_civil
  var y = year.int64
  if month <= 2: y -= 1
  let era = (if y >= 0: y else: y-399) div 400
  let yoe = y - era * 400
  let doy = (153 * (month + (if month > 2: -3 else: 9)) + 2) div 5 + day-1
  let doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
  let day = era * 146097 + doe - 719468
  var self = hour * HOUR + minute * MINUTE + second * SECOND + milli * MILLI_SECOND + micro * MICRO_SECOND + nano * NANO_SECOND
  if day < 0: 
    # try avoid underflow. params are supposed to be positive
    self += (day + 1) * DAY
    self -= DAY
  else:
    self += day * DAY
  return Timestamp(self: self)

proc systemTimestamp*(): Timestamp = 
  ## Use TimeService.now() for normal timestamp
  when defined(posix):
    var ts: Timespec
    let success = clock_gettime(CLOCK_REALTIME, ts)
    if success != 0: raise newException(TimestampException, "clock_gettime failed")
    result = Timestamp(self: ts.tv_sec.int64 * 1_000_000_000 + ts.tv_nsec.int64)
  elif defined(windows):
    var f: FILETIME
    getSystemTimeAsFileTime(f)
    # https://www.frenk.com/2009/12/convert-filetime-to-unix-timestamp/
    var t = f.dwHighDateTime.int64 shl 32 + f.dwLowDateTime.int64
    t -= 11644473600000 * 10000
    t *= 100
    result = Timestamp(self: t)
  else:
    {.failed "only windows and posix are supported".}

proc i64*(t: Timestamp): int64 = t.self

proc `==`*(a,b: Timestamp): bool = a.self == b.self
proc `<`*(a,b: Timestamp): bool = a.self < b.self
proc `<=`*(a,b: Timestamp): bool = a.self <= b.self
proc `+`*(a: Timestamp, ns: int64): Timestamp = Timestamp(self: a.self + ns)
proc `-`*(a: Timestamp, ns: int64): Timestamp = Timestamp(self: a.self - ns)
proc `-`*(a,b: Timestamp): int64 = a.self - b.self
proc max*(a,b: Timestamp): Timestamp = Timestamp(self: max(a.self, b.self))
proc min*(a,b: Timestamp): Timestamp = Timestamp(self: min(a.self, b.self))

proc daySinceEpoch*(t: Timestamp): int64 = floorDiv(t.self, DAY).int64

proc convert(t: Timestamp, d, m: int64): int64 {.inline.} =
  var n = floorDiv(t.self, d) mod m
  if n < 0: result = (n + m)
  else: result = n
proc nanoSecond*(t: Timestamp): int64 = convert(t, NANO_SECOND, 1000)
proc microSecond*(t: Timestamp): int64 = convert(t, MICRO_SECOND, 1000)
proc milliSecond*(t: Timestamp): int64 = convert(t, MILLI_SECOND, 1000)
proc second*(t: Timestamp): int64 = convert(t, SECOND, 60)
proc minute*(t: Timestamp): int64 = convert(t, MINUTE, 60)
proc hour*(t: Timestamp): int64 = convert(t, HOUR, 24)
proc subSecond*(t: Timestamp): int64 = convert(t, NANO_SECOND, 1_000_000_000)

proc yearMonthDay*(t: Timestamp): tuple[year: int, month: int, day: int] = 
  # http://howardhinnant.github.io/date_algorithms.html
  let z = 719468 + t.daySinceEpoch
  let era = (if z >= 0: z else: z - 146096) div 146097
  let doe = z - era * 146097
  let yoe = (doe - doe div 1460 + doe div 36524 - doe div 146096) div 365
  let y = yoe + era * 400;
  let doy = doe - (365 * yoe + yoe div 4 - yoe div 100)
  let mp = (5 * doy + 2) div 153
  let d = doy - (153 * mp + 2) div 5 + 1
  let m = mp + (if mp < 10: 3 else: -9)
  return ((y + ord(m <= 2)).int, m.int, d.int)

proc zulu*(t: Timestamp): string = 
  let (y, m, d) = t.yearMonthDay()
  let yr = ($y).align(4, '0')
  let mo = ($m).align(2, '0')
  let dy = ($d).align(2, '0')
  let hh = ($t.hour).align(2, '0')
  let mm = ($t.minute).align(2, '0')
  let ss = ($t.second).align(2, '0')
  let ms = ($t.milliSecond).align(3, '0')
  result = &"{yr}-{mo}-{dy}T{hh}:{mm}:{ss}.{ms}Z"

proc `$`*(t: Timestamp): string = 
  let (y, m, d) = t.yearMonthDay()
  let yr = ($y).align(4, '0')
  let mo = ($m).align(2, '0')
  let dy = ($d).align(2, '0')
  let hh = ($t.hour).align(2, '0')
  let mm = ($t.minute).align(2, '0')
  let ss = ($t.second).align(2, '0')
  let ns = ($t.subSecond).align(9, '0')
  result = &"{yr}-{mo}-{dy}T{hh}:{mm}:{ss}.{ns}Z"

proc parseZulu*(s: string): Timestamp =
  ## The following format are acceptable
  ## 2001-02-03T04:05:06Z
  ## 2001-02-03T04:05:06.1Z
  ## 2001-02-03T04:05:06.12Z
  ## 2001-02-03T04:05:06.123Z
  ## 2001-02-03T04:05:06.123456Z
  ## 2001-02-03T04:05:06.123456789Z
  template check(i,j) =
    for k in i..j:
      if not isDigit(s[k]): 
        raise newException(TimestampInvalidFormatException, "Invalid format: position " & $k & " is not a digit: " & s)

  if s.len < 20: 
    raise newException(TimestampInvalidFormatException, "Invalid format: too short: " & s)
  if s.len > 30:
    raise newException(TimestampInvalidFormatException, "Invalid format: too long: " & s)
  check(0,3)
  if s[4] != '-': raise newException(TimestampInvalidFormatException, "Invalid format: " & s)
  check(5,6)
  if s[7] != '-': raise newException(TimestampInvalidFormatException, "Invalid format: " & s)
  check(8,9)
  if s[10] != 'T': raise newException(TimestampInvalidFormatException, "Invalid format: " & s)
  check(11,12)
  if s[13] != ':': raise newException(TimestampInvalidFormatException, "Invalid format: " & s)
  check(14,15)
  if s[16] != ':': raise newException(TimestampInvalidFormatException, "Invalid format: " & s)
  if s.len > 20: 
    if s[19] != '.': raise newException(TimestampInvalidFormatException, "Invalid format: " & s)
    check(20,s.len-2)
  if s[^1] != 'Z': raise newException(TimestampInvalidFormatException, "Invalid format: missing Z: " & s)

  # http://howardhinnant.github.io/date_algorithms.html#civil_from_days
  var t: int64 = 0
  var y: int64 = parseInt(s[0..3])
  # int64.high.Time.zulu == 2262-04-11T23:47:16.854Z
  if y > 2262: raise newException(TimestampOutOfRangeException, "Time out of range: " & s)
  # int64.low.Time.zulu == 1677-09-21T00:12:43.145Z
  if y < 1678: raise newException(TimestampOutOfRangeException, "Time out of range: " & s)

  var m: int64 = parseInt(s[5..6])
  var d: int64 = parseInt(s[8..9])
  if m <= 2: y -= 1
  let era = (if y > 0: y else: y - 399) div 400
  let yoe = y - era * 400
  let doy = (153*(m + (if m > 2: -3 else: 9)) + 2) div 5 + d - 1
  let doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
  t += (146097 * era + doe - 719468) * DAY
  t += parseInt(s[11..12]) * HOUR
  t += parseInt(s[14..15]) * MINUTE
  t += parseInt(s[17..18]) * SECOND
  if s.len > 20:
    t += parseInt(s[20..s.len-2]) * 10^(30 - s.len)
  result = Timestamp(self: t)

proc inDay*(t: Timestamp): float = t.self.float / DAY.float
proc inHour*(t: Timestamp): float = t.self.float / HOUR.float
proc inMinute*(t: Timestamp): float = t.self.float / MINUTE.float
proc inSecond*(t: Timestamp): float = t.self.float / SECOND.float
proc inMilliSecond*(t: Timestamp): float = t.self.float / MILLI_SECOND.float
proc inMicroSecond*(t: Timestamp): float = t.self.float / MICRO_SECOND.float