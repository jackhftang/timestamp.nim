# Timestamp.nim 

You may want to use this library if
- You do not want to obsess with the standard (times)[https://nim-lang.org/docs/times.html] library 
- Your mind model of time is an integer and comfortable with arithmetic operations of time
- You understand GMT (not UTC) and that 1 day equal to 1 rotation of earth and each day has exactly 86400 seconds.
- You only need *a point in time* and do not care representation of time e.g. timezone, daylight saving time
- You need nano-second precision p
- You want small data size (8 bytes) and fast operations
- You are okay with time range from 1677-09-21T00:12:43.145Z to 2262-04-11T23:47:16.854Z

## Usage

### Construction 

```nim
# from system time
echo systemTimestamp()

# from int64
assert $initTimestamp(0) == "1970-01-01T00:00:00.000000Z"

# from year, month, day


```

### Operation 

All operations are immutable. 

```nim

```

