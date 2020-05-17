import strutils, strformat, math, times
when defined(posix):
  import posix except Time
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

proc systemRealTime*(): Timestamp = 
  ## create a timestamp with current system time
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
  var self = hour * HOUR + minute * MINUTE + second * SECOND + milli * MILLI_SECOND + micro * MICRO_SECOND + nano * NANO_SECOND
  if day < 0: 
    # try avoid underflow. params are supposed to be positive
    self += (day + 1) * DAY
    self -= DAY
  else:
    self += day * DAY
  return Timestamp(self: self)

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
proc nanoSecond*(t: Timestamp): int64 = 
  ## Extract nano-second in zulu time, range from 0~999
  convert(t, NANO_SECOND, 1000)
proc microSecond*(t: Timestamp): int64 = 
  ## Extract micro-second in zulu time, range from 0~999
  convert(t, MICRO_SECOND, 1000)
proc milliSecond*(t: Timestamp): int64 = 
  ## Extract milli-second in zulu time, range from 0~999
  convert(t, MILLI_SECOND, 1000)
proc second*(t: Timestamp): int64 = 
  ## Extract minute in zulu time.
  convert(t, SECOND, 60)
proc minute*(t: Timestamp): int64 = 
  ## Extract hour in zulu time
  convert(t, MINUTE, 60)
proc hour*(t: Timestamp): int64 = 
  ## Extract day in zulu time
  convert(t, HOUR, 24)

proc subSecond*(t: Timestamp): int64 = 
  ## Number of nano-second since last whole second
  convert(t, NANO_SECOND, 1_000_000_000)

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

proc i64*(t: Timestamp): int64 = 
  ## Convert to number of nano-second since epoch time in int64
  t.self

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
        raise newException(TimestampInvalidFormatException, "Invalid format: position " & $k & " is not a digit: " & s)

  template checkChar(i, c) =
    if s[i] != c: 
      raise newException(TimestampInvalidFormatException, "Invalid format: position " & $i & " is not equal to " & c & ": " & s)

  if s.len < 20: 
    raise newException(TimestampInvalidFormatException, "Invalid format: too short: " & s)
  if s.len > 30:
    raise newException(TimestampInvalidFormatException, "Invalid format: too long: " & s)
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

proc inDay*(t: Timestamp): float = 
  ## Number of day since epoch time.
  t.self.float / DAY.float
proc inHour*(t: Timestamp): float = 
  ## Number of hour since epoch time.
  t.self.float / HOUR.float
proc inMinute*(t: Timestamp): float = 
  ## Number of minute since epoch time.
  t.self.float / MINUTE.float
proc inSecond*(t: Timestamp): float = 
  ## Number of second since epoch time.
  t.self.float / SECOND.float
proc inMilliSecond*(t: Timestamp): float = 
  ## Number of milli-second since epoch time.
  t.self.float / MILLI_SECOND.float
proc inMicroSecond*(t: Timestamp): float = 
  ## Number of micro-second since epoch time.
  t.self.float / MICRO_SECOND.float
proc inNanoSecond*(t: Timestamp): float = 
  ## Number of nano-second since epoch time.
  t.self.float

proc toTime*(t: Timestamp): Time =
  ## Convert Timestamp to Time
  let sub = t.subSecond
  let sec = (t.self - sub) div SECOND
  initTime(sec, sub)
  
proc toDateTime*(t: Timestamp): DateTime =
  ## Convert Timestmap to DateTime
  let (year, month, day) = t.yearMonthDay
  initDateTime(day, month.Month, year, t.hour, t.minute, t.second, t.subSecond, utc())

proc toTimestamp*(t: Time): Timestamp = 
  ## Convert Time to timestamp
  initTimestamp(t.toUnix * SECOND + t.nanosecond)

proc toTimestamp*(t: DateTime): Timestamp =
  ## Convert DateTime to Timestamp
  ## can use between
  t.toTime().toTimestamp()