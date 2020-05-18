# Timestamp.nim 

You may want to use this library if:

- You want a small data structure (int64) and very fast operations on them. e.g. Time-series data procesing
- You speak in GMT (not UTC) that 1 day equal to 1 rotation of earth and each day has exactly 86400 seconds.
- You are comfortable with arthmetic with time.

Limitations and this libray may not for you:

- Your use case beyond time bound from `1677-09-21T00:12:43.145Z` to `2262-04-11T23:47:16.854Z`
- You need to compile to JS backend
- You need smaller than nano-second precision.
- You have complex requirement of presentation of time e.g. timezone, daylight saving time.

## Installation

```
$ nimble install timestamp
```

## Usage

### Construction 

```nim
# from system real time (now)
echo initTimestamp()

# from nano second since epoch time 
assert $initTimestamp(0) == "1970-01-01T00:00:00.000000000Z"
assert $initTimestamp(2 * DAY) == "1970-01-03T00:00:00.000000000Z"

# from year, month, day...
assert $initTimestamp(2001,2,3) == "2001-02-03T00:00:00.000000000Z"
assert $initTimestamp(2001,2,3,4) == "2001-02-03T04:00:00.000000000Z"
assert $initTimestamp(2001,2,3,4,5) == "2001-02-03T04:05:00.000000000Z"
assert $initTimestamp(2001,2,3,4,5,6) == "2001-02-03T04:05:06.000000000Z"
assert $initTimestamp(2001,2,3,4,5,6,7,8,9) == "2001-02-03T04:05:06.007008009Z"

# from string
assert parseZulu("1970-01-01T00:00:00Z") == initTimestamp(0)
assert parseZulu("1970-01-01T00:00:00.1Z") == initTimestamp(100000000)
assert parseZulu("1970-01-01T00:00:00.12Z") == initTimestamp(120000000)
assert parseZulu("1970-01-01T00:00:00.123Z") == initTimestamp(123000000)
assert parseZulu("1970-01-01T00:00:00.123456Z") == initTimestamp(123456000)
assert parseZulu("1970-01-01T00:00:00.123456789Z") == initTimestamp(123456789)

# from Time
assert getTime().toTimestamp is Timestamp
assert now().toTimestamp is Timestamp
```

### Operation 


DAY, HOUR, SECOND, MINUTE, MILLI_SECOND, MICRO_SECOND, NANO_SECOND are 7 predefined `Timespan`
Timestamp `+`/`-` Timespan return another timestamp.

```nim
let t = initTimestamp(0)

# DAY, HOUR, MINUTE... are pre-defined constants of `Timespan`
assert $(t + DAY) == "1970-01-02T00:00:00.000000000Z"
assert $(t + HOUR) == "1970-01-01T01:00:00.000000000Z"
assert $(t + MINUTE) == "1970-01-01T00:01:00.000000000Z"
assert $(t + SECOND) == "1970-01-01T00:00:01.000000000Z"
assert $(t + MILLI_SECOND) == "1970-01-01T00:00:00.001000000Z"
assert $(t + MICRO_SECOND) == "1970-01-01T00:00:00.000001000Z"
assert $(t + NANO_SECOND) == "1970-01-01T00:00:00.000000001Z"
assert $(t - NANO_SECOND) == "1969-12-31T23:59:59.999999999Z"
assert $(t + 5 * MINUTE) == "1970-01-01T00:00:05.000000000Z"

# substraction between two timestamps return Timespan
let t2 = t + DAY 
assert t2 - t == 86400 * SECOND
```

### Comparison 

```nim
let a = initTimestamp(0)
let b = initTimestamp(1)
assert a < b
assert a <= b
assert max(a,b) == b
assert min(a,b) == a
```

### Extraction 

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
assert initTimestamp(1970,1,2).daySinceEpoch == 1
```

### Presentation

```nim
let t = initTimestamp(2001,2,3,4,5,6,7,8,9)
let t0 = initTimespan(0)

# convert Timestamp to string
assert $t == "2001-02-03T04:05:06.007008009Z"

# convert Timestamp to string at milli-second precision (same as javascript toISOString())
assert t.zulu == "2001-02-03T04:05:06.007Z"

# convert Timestamp to int64
assert t.i64 is int64

# convert Timestamp to DateTime 
assert t.toDateTime == initDateTime(3, mFeb, 2001, 4, 5, 6, 7008009, utc())

# convert Timestamp to Time
assert t.toTime == t.toDateTime.toTime

# convert Timespan to int64
assert (t - t0).i64 is int64

# convert Timespan to float
assert (t - t0).inDay is float
assert (t - t0).inHour is float
assert (t - t0).inMinute is float
assert (t - t0).inSecond is float
assert (t - t0).inMilliSecond is float
assert (t - t0).inMicroSecond is float
assert (t - t0).inNanoSecond is float
```



## API

see [here](https://jackhftang.github.io/timestamp.nim/)