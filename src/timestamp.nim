import strutils, strformat, math, times
when defined(posix):
  from posix import Timespec, clock_gettime, CLOCK_REALTIME
elif defined(windows):
  from winlean import FILETIME, getSystemTimeAsFileTime
  
# nano second since epoch time in GMT
type
  TimestampError* = object of CatchableError
  TimestampInvalidFormatError* = object of TimestampError
  TimestampOutOfRangeError* = object of TimestampError
  TimespanError* = object of CatchableError
  TimespanInvalidFormatError* = object of TimespanError

  Timespan* = distinct int64
  Timestamp* = object
    self: int64

proc i64*(span: Timespan): int64 {.inline.} = 
  ## Convert to number of nano-second
  span.int64
proc i64*(stamp: Timestamp): int64 = 
  ## Convert to number of nano-second since epoch time in int64
  stamp.self

proc `==`*(a,b: Timespan): bool {.borrow.}
proc `<`*(a,b: Timespan): bool {.borrow.}
proc `<=`*(a,b: Timespan): bool {.borrow.}
proc `*`*[T: SomeInteger](n: T, span: Timespan): Timespan {.inline.} = Timespan(n.int64 * span.int64)
proc `div`*[T: SomeInteger](span: Timespan, n: T): Timespan {.inline.} = Timespan(span.int64 div n.int64)
proc `div`*(a,b: Timespan): int64 {.inline.} = a.int64 div b.int64
proc `+`*(a, b: Timespan): Timespan {.inline.} = Timespan(a.int64 + b.int64)
proc `-`*(a, b: Timespan): Timespan {.inline.} = Timespan(a.int64 - b.int64)
let NANO_SECOND* = 1.Timespan
let MICRO_SECOND* = 1000 * NANO_SECOND
let MILLI_SECOND* = 1000 * MICRO_SECOND
let SECOND* = 1000 * MILLI_SECOND
let MINUTE* = 60 * SECOND
let HOUR* = 60 * MINUTE
let DAY* = 24 * HOUR

proc `==`*(a,b: Timestamp): bool = a.self == b.self
proc `<`*(a,b: Timestamp): bool = a.self < b.self
proc `<=`*(a,b: Timestamp): bool = a.self <= b.self
proc max*(a,b: Timestamp): Timestamp = Timestamp(self: max(a.self, b.self))
proc min*(a,b: Timestamp): Timestamp = Timestamp(self: min(a.self, b.self))

proc systemRealTime*(): Timestamp = 
  ## create a timestamp with current system time
  when defined(posix):
    var ts: Timespec
    let success = clock_gettime(CLOCK_REALTIME, ts)
    if success != 0: raise newException(TimestampError, "clock_gettime failed")
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

proc initTimestamp*(): Timestamp {.inline.} = systemRealTime()

proc initTimestamp*(ns: int64): Timestamp = 
  ## create a timestamp with number of nano-second since epoch
  Timestamp(self: ns)

proc initTimestamp*(year, month, day: int, hour=0, minute=0, second=0, milli=0, micro=0, nano=0): Timestamp =
  ## create a timestamp with normal written units
  # http://howardhinnant.github.io/date_algorithms.html#days_from_civil
  var y = year.int64
  if month <= 2: y -= 1
  let era = (if y >= 0: y else: y-399) div 400
  let yoe = y - era * 400
  let doy = (153 * (month + (if month > 2: -3 else: 9)) + 2) div 5 + day-1
  let doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
  let day = era * 146097 + doe - 719468
  var span = hour * HOUR + minute * MINUTE + second * SECOND + milli * MILLI_SECOND + micro * MICRO_SECOND + nano * NANO_SECOND
  if day < 0: 
    # try avoid underflow. params are supposed to be positive
    span = span + (day + 1) * DAY
    span = span - DAY
  else:
    span = span + day * DAY
  return Timestamp(self: span.int64)

proc `+`*(a: Timestamp, ns: Timespan): Timestamp {.inline.} = Timestamp(self: a.self + ns.int64)
proc `-`*(a: Timestamp, ns: Timespan): Timestamp {.inline.} = Timestamp(self: a.self - ns.int64)
proc `-`*(a,b: Timestamp): Timespan = Timespan(a.self - b.self)

proc epoch*(t: Timestamp): float = t.self.float / 1_000_000_000.0
proc daySinceEpoch*(t: Timestamp): int64 = floorDiv(t.self, DAY.int64).int64

proc convert(t: Timestamp, d: Timespan, m: int64): int64 {.inline.} =
  var n = floorDiv(t.self, d.int64) mod m
  if n < 0: result = n + m
  else: result = n
proc nanoSecond*(t: Timestamp): int = 
  ## Extract nano-second in zulu time, range from 0~999
  convert(t, NANO_SECOND, 1000).int
proc microSecond*(t: Timestamp): int = 
  ## Extract micro-second in zulu time, range from 0~999
  convert(t, MICRO_SECOND, 1000).int
proc milliSecond*(t: Timestamp): int = 
  ## Extract milli-second in zulu time, range from 0~999
  convert(t, MILLI_SECOND, 1000).int
proc second*(t: Timestamp): int = 
  ## Extract minute in zulu time.
  convert(t, SECOND, 60).int
proc minute*(t: Timestamp): int = 
  ## Extract hour in zulu time
  convert(t, MINUTE, 60).int
proc hour*(t: Timestamp): int = 
  ## Extract day in zulu time
  convert(t, HOUR, 24).int

proc subSecond*(t: Timestamp): int = 
  ## Number of nano-second since last whole second
  convert(t, NANO_SECOND, 1_000_000_000).int

proc yearMonthDay*(t: Timestamp): tuple[year: int, month: int, day: int] = 
  ## Convert Timestamp to calendar year month and day
  
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

proc addMonth*(a: Timestamp, m: int): Timestamp =
  ## Add `m` month to a. `m` could be negative
  let (year, month, day) = a.yearMonthDay
  initTimestamp(year, month + m, day, a.hour, a.minute, a.second, a.milliSecond, a.microSecond, a.nanoSecond)

proc addYear*(a: Timestamp, y: int): Timestamp =
  let (year, month, day) = a.yearMonthDay
  initTimestamp(year + y, month, day, a.hour, a.minute, a.second, a.milliSecond, a.microSecond, a.nanoSecond)

proc add*(
  a: Timestamp, 
  year: int = 0, 
  month: int = 0, 
  day: int = 0, 
  hour: int = 0,
  minute: int = 0,
  second: int = 0,
  millisecond: int = 0,
  microsecond: int = 0,
  nanosecond: int = 0
): Timestamp =
  if year != 0 or month != 0:
    let (y, m, d) = a.yearMonthDay
    result = initTimestamp(
      year + y, month + m, day + d, 
      a.hour + hour, a.minute + minute, a.second + second, 
      a.milliSecond + millisecond, 
      a.microSecond + microsecond, 
      a.nanoSecond + nanosecond
    )
  else:
    result = a + 
      day * DAY +
      hour * HOUR  +
      minute * MINUTE  +
      second * SECOND +
      millisecond * MILLI_SECOND +
      microsecond * MICRO_SECOND +
      nanosecond * NANO_SECOND 

proc zulu*(t: Timestamp): string =
  ## Convert timestamp to string with milli-second precision
  ## Use `$` if you need full (nano-second) precision 
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
  ## Convert Timestamp to string
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
  ## The following format are supported. 
  ## 
  ## ```
  ## 2001-02-03T04:05:06Z
  ## 2001-02-03T04:05:06.1Z
  ## 2001-02-03T04:05:06.12Z
  ## 2001-02-03T04:05:06.123Z
  ## 2001-02-03T04:05:06.123456Z
  ## 2001-02-03T04:05:06.123456789Z
  ## ```
  template checkIsDigit(i,j) =
    for k in i..j:
      if not isDigit(s[k]): 
        raise newException(TimestampInvalidFormatError, "Invalid format: position " & $k & " is not a digit: " & s)

  template checkChar(i, c) =
    if s[i] != c: 
      raise newException(TimestampInvalidFormatError, "Invalid format: position " & $i & " is not equal to " & c & ": " & s)

  if s.len < 20: 
    raise newException(TimestampInvalidFormatError, "Invalid format: too short: " & s)
  if s.len > 30:
    raise newException(TimestampInvalidFormatError, "Invalid format: too long: " & s)
  checkIsDigit(0,3)
  checkChar(4,'-')
  checkIsDigit(5,6)
  checkChar(7, '-')
  checkIsDigit(8,9)
  checkChar(10, 'T')
  checkIsDigit(11,12)
  checkChar(13, ':')
  checkIsDigit(14,15)
  checkChar(16, ':')
  if s.len > 20: 
    checkChar(19, '.')
    checkIsDigit(20,s.len-2)
  if s[^1] != 'Z': raise newException(TimestampInvalidFormatError, "Invalid format: missing Z: " & s)

  # http://howardhinnant.github.io/date_algorithms.html#civil_from_days
  var t: int64 = 0
  var y: int64 = parseInt(s[0..3])
  # int64.high.Time.zulu == 2262-04-11T23:47:16.854Z
  if y > 2262: raise newException(TimestampOutOfRangeError, "Time out of range: " & s)
  # int64.low.Time.zulu == 1677-09-21T00:12:43.145Z
  if y < 1678: raise newException(TimestampOutOfRangeError, "Time out of range: " & s)

  var m: int64 = parseInt(s[5..6])
  var d: int64 = parseInt(s[8..9])
  if m <= 2: y -= 1
  let era = (if y > 0: y else: y - 399) div 400
  let yoe = y - era * 400
  let doy = (153*(m + (if m > 2: -3 else: 9)) + 2) div 5 + d - 1
  let doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
  t += (146097 * era + doe - 719468) * DAY.int64
  t += parseInt(s[11..12]) * HOUR.int64
  t += parseInt(s[14..15]) * MINUTE.int64
  t += parseInt(s[17..18]) * SECOND.int64
  if s.len > 20:
    t += parseInt(s[20..s.len-2]) * 10^(30 - s.len)
  result = Timestamp(self: t)

proc inDay*(t: Timespan): float = 
  ## Number of day since epoch time.
  t.float / DAY.float
proc inHour*(t: Timespan): float = 
  ## Number of hour since epoch time.
  t.float / HOUR.float
proc inMinute*(t: Timespan): float = 
  ## Number of minute since epoch time.
  t.float / MINUTE.float
proc inSecond*(t: Timespan): float = 
  ## Number of second since epoch time.
  t.float / SECOND.float
proc inMilliSecond*(t: Timespan): float = 
  ## Number of milli-second since epoch time.
  t.float / MILLI_SECOND.float
proc inMicroSecond*(t: Timespan): float = 
  ## Number of micro-second since epoch time.
  t.float / MICRO_SECOND.float
proc inNanoSecond*(t: Timespan): float = 
  ## Number of nano-second since epoch time.
  t.float

proc toTime*(t: Timestamp): Time =
  ## Convert Timestamp to Time
  let sub = t.subSecond
  let sec = (t.self - sub) div SECOND.int64
  initTime(sec, sub)
  
proc toDateTime*(t: Timestamp): DateTime =
  ## Convert Timestmap to DateTime
  let (year, month, day) = t.yearMonthDay
  initDateTime(day, month.Month, year, t.hour, t.minute, t.second, t.subSecond, utc())

proc toTimestamp*(t: Time): Timestamp = 
  ## Convert Time to timestamp
  initTimestamp(t.toUnix * SECOND.int64 + t.nanosecond)

proc toTimestamp*(t: DateTime): Timestamp =
  ## Convert DateTime to Timestamp
  t.toTime().toTimestamp()

proc `$`*(t: Timespan): string =
  if t.i64 < 0: 
    return '-' & $Timespan(-t.i64)
  if t.i64 == 0:
    return "0"

  var n = t
  template run(unit, name: untyped) = 
    if t >= `unit`:
      let x = n div `unit`
      n = n - x*unit
      if x != 0:
        result &= $x & `name`
      
  run(DAY, "d")
  run(HOUR, "h")
  run(MINUTE, "m")
  run(SECOND, "s")
  run(MILLI_SECOND, "ms")
  run(MICRO_SECOND, "us")
  run(NANO_SECOND, "ns")

proc parseTimespan*(s: string): Timespan =
  if s == "0":
    return Timespan(0)
  if s[0] == '-':
    let t = parseTimespan(s[1..s.len-1])
    return Timespan(-t.i64)
  
  result = Timespan(0)
  var n: int64 = 0
  var i = 0

  template read(i: untyped): untyped =
    if i >= s.len: '\0'
    else: s[i]
  template add(t: untyped): untyped =
    result = result + n * `t`
    n = 0
  template addAndMove(t: untyped): untyped =
    result = result + n * `t`
    n = 0
    i += 1

  while i < s.len:
    let c = s[i]
    case c:
    of '0'..'9':
      n = 10*n + c.ord.int64 - 48
    of 'd': add(DAY)
    of 'h': add(HOUR)
    of 's': add(SECOND)
    of 'm':
      let c1 = read(i+1)
      if c1 == 's': addAndMove(MILLI_SECOND)
      elif c1 == '\0' or isDigit(c1): add(MINUTE)
      else: raise newException(TimespanInvalidFormatError, "invalid format: " & s)
    of 'u':
      let c1 = read(i+1)
      if c1 == 's': addAndMove(MICRO_SECOND)
      else: raise newException(TimespanInvalidFormatError, "invalid format: " & s)
    of 'n':
      let c1 = read(i+1)
      if c1 == 's': addAndMove(NANO_SECOND)
      else: raise newException(TimespanInvalidFormatError, "invalid format: " & s)
    else:
      raise newException(TimespanInvalidFormatError, "invalid format: " & s)
    i += 1
