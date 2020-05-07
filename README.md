# Timestamp.nim 

You may want to use this library if
- You do not want to obsess with the standard (times)[https://nim-lang.org/docs/times.html] library 
- Your mindset of time is an integer and comfortable with arithmetic operations of time
- You understand GMT (not UTC) and that 1 day equal to 1 rotation of earth and each day has exactly 86400 seconds.
- You only need *a point-in-time* and do not care representation of time e.g. timezone, daylight saving time
- You need nano-second precision p
- You want small data size (8 bytes) and fast operations
- You are okay with time range from 1677-09-21T00:12:43.145Z to 2262-04-11T23:47:16.854Z

## Usage

### Construction 

```nim
# from system time
echo systemTimestamp()

# from nano second since epoch time 
assert $initTimestamp(0) == "1970-01-01T00:00:00.000000000Z"
assert $initTimestamp(2 * DAY) == "1970-01-03T00:00:00.000000000Z"

# from year, month, day...
assert $initTimestamp(2001,2,3) == "2001-02-03T00:00:00.000000000Z"
assert $initTimestamp(2001,2,3,4) == "2001-02-03T04:00:00.000000000Z"
assert $initTimestamp(2001,2,3,4,5) == "2001-02-03T04:05:00.000000000Z"
assert $initTimestamp(2001,2,3,4,5,6) == "2001-02-03T04:05:06.000000000Z"
assert $initTimestamp(2001,2,3,4,5,6,7,8,9) == "2001-02-03T04:05:06.007008009Z"
```

### Operation 

`+`, `-` return a new timestamp.

```nim
let t = initTimestamp(0)
assert $(t + DAY) == "1970-01-02T00:00:00.000000000Z"
assert $(t + HOUR) == "1970-01-01T01:00:00.000000000Z"
assert $(t + MINUTE) == "1970-01-01T00:01:00.000000000Z"
assert $(t + SECOND) == "1970-01-01T00:00:01.000000000Z"
assert $(t + MILLI_SECOND) == "1970-01-01T00:00:00.001000000Z"
assert $(t + MICRO_SECOND) == "1970-01-01T00:00:00.000001000Z"
assert $(t + NANO_SECOND) == "1970-01-01T00:00:00.000000001Z"
```

#### Comparison 

```nim
let a = initTimestamp(0)
let b = initTimestamp(1)
assert a < b
assert a <= b
assert max(a,b) == b
assert min(a,b) == a
```

#### Extraction 

```nim
let t = initTimestamp(2001,2,3,4,5,6,7,8,9)
assert t.yearMonthday == (2001,2,3)
assert t.hour == 4
assert t.minute == 5
assert t.second == 6
assert t.milliSecond == 7
assert t.microSecond == 8
assert t.nanoSecond == 9
assert t.subSecond == 7008009
assert t.daySinceEpoch == 11356
```

