import unittest, asyncdispatch, times, random
import timestamp

suite "timestamp":

  test "sizeof(Timestamp)":
    check: sizeof(Timestamp) == 8
    
  test "comparison":
    proc doTest {.async.} =
      let s = initTimestamp()
      await sleepAsync(1)
      let e = initTimestamp()
      check: s < e
      check: s <= e
      check: s == s
      check: s != e
      check: e > s
      check: e >= s
    waitFor doTest()
    
  test "unit":
    check: initTimestamp(123_123_123_123_000).microSecond == 123
    check: initTimestamp(123_123_123_123_000).second == 3
    check: initTimestamp(123_123_123_123_000).minute == 12
    check: initTimestamp(123_123_123_123_000).hour == 10

  test "zulu":
    check: initTimestamp(0).zulu == "1970-01-01T00:00:00.000Z"
    check: initTimestamp(123_123_123_123_000).zulu == "1970-01-02T10:12:03.123Z"
    check: initTimestamp(1_000_000_000_000).zulu == "1970-01-01T00:16:40.000Z"
    check: initTimestamp(1_000_000_000_000_000).zulu == "1970-01-12T13:46:40.000Z"
    check: initTimestamp(1_000_000_000_000_000_000).zulu == "2001-09-09T01:46:40.000Z"
    check: initTimestamp(1571199015670_000_000).zulu == "2019-10-16T04:10:15.670Z"
    check: initTimestamp(-1000).zulu == "1969-12-31T23:59:59.999Z"
    check: initTimestamp(-1571199015670_000_000).zulu == "1920-03-18T19:49:44.330Z"

  test "initTimestamp":
    check: $initTimestamp(1970, 1, 1) == "1970-01-01T00:00:00.000000000Z"
    check: $initTimestamp(1970, 1, 2) == "1970-01-02T00:00:00.000000000Z"
    check: $initTimestamp(1970, 1, 0) == "1969-12-31T00:00:00.000000000Z"
    check: $initTimestamp(1969, 12, 31) == "1969-12-31T00:00:00.000000000Z"
    check: $initTimestamp(1970, 1, 1, milli=1) == "1970-01-01T00:00:00.001000000Z"
    check: $initTimestamp(1970, 1, 1, micro=1) == "1970-01-01T00:00:00.000001000Z"
    check: $initTimestamp(1970, 1, 1, nano=1) == "1970-01-01T00:00:00.000000001Z"
    # not overflow/underflow
    check: initTimestamp(2262, 4, 11, 23, 47, 16, 854, 775, 807).i64 == int64.high
    check: initTimestamp(1677, 9, 21, 0, 12, 43, 145, 224, 192).i64 == int64.low

  test "parseZulu":
    check: parseZulu("2001-09-09T01:46:40.000Z") == initTimestamp(1_000_000_000_000_000_000)
    check: parseZulu("1970-01-02T10:12:03.123Z") == initTimestamp(123_123_123_000_000)
    check: parseZulu("1970-01-01T00:00:00Z") == initTimestamp(0)
    check: parseZulu("1970-01-01T00:00:00.1Z") == initTimestamp(100000000)
    check: parseZulu("1970-01-01T00:00:00.12Z") == initTimestamp(120000000)
    check: parseZulu("1970-01-01T00:00:00.123Z") == initTimestamp(123000000)
    check: parseZulu("1970-01-01T00:00:00.123456Z") == initTimestamp(123456000)
    check: parseZulu("1970-01-01T00:00:00.123456789Z") == initTimestamp(123456789)
    
  test "special timepoint":
    check: $initTimestamp(0) == "1970-01-01T00:00:00.000000000Z"
    check: $initTimestamp(-1) == "1969-12-31T23:59:59.999999999Z"
    check: $initTimestamp(1 shl 60) == "2006-07-14T23:58:24.606846976Z"
    check: $initTimestamp(1 shl 61) == "2043-01-25T23:56:49.213693952Z"
    check: $initTimestamp(1 shl 62) == "2116-02-20T23:53:38.427387904Z"
    check: $initTimestamp(1 shl 63) == "1677-09-21T00:12:43.145224192Z"
    check: $initTimestamp(int64.high) == "2262-04-11T23:47:16.854775807Z"
    check: $initTimestamp(int64.low) == "1677-09-21T00:12:43.145224192Z"
    
  test "toTime":
    var tc = @[0'i64, 1, -1]
    for i in 1..1000: 
      let n = rand(2'i64 .. int64.high)
      tc.add n
      tc.add -n

    for n in tc:
      let ts = initTimestamp(n)
      let time = ts.toTime
      check: time.nanoSecond == ts.subsecond
      check: time == ts.toDateTime.toTime

  test "toDateTime":
    var tc = @[0'i64, 1, -1]
    for i in 1..1000: 
      let n = rand(2'i64 .. int64.high)
      tc.add n
      tc.add -n

    for n in tc:
      let ts = initTimestamp(n)
      let s0 = $ts
      var s1 = ts.toDateTime().format("yyyy-MM-dd HH:mm:ss fffffffff")
      s1[10] = 'T'
      s1[19] = '.'
      s1 &= 'Z'
      check: s0 == s1

  test "Time to Timestamp":
    var tc = @[0'i64, 1, -1]
    for i in 1..1000: 
      let n = rand(2'i64 .. int64.high)
      tc.add n
      tc.add -n
    for n in tc:
      let ts = initTimestamp(n)
      check: ts == ts.toTime.toTimestamp

  test "DateTime to Timestamp":
    var tc = @[0'i64, 1, -1]
    for i in 1..1000: 
      let n = rand(2'i64 .. int64.high)
      tc.add n
      tc.add -n
    for n in tc:
      let ts = initTimestamp(n)
      check: ts == ts.toDateTime.toTimestamp

  test "example on readme":
    block:
      assert $initTimestamp(0) == "1970-01-01T00:00:00.000000000Z"
      assert $initTimestamp(2 * DAY) == "1970-01-03T00:00:00.000000000Z"

      assert $initTimestamp(2001,2,3) == "2001-02-03T00:00:00.000000000Z"
      assert $initTimestamp(2001,2,3,4) == "2001-02-03T04:00:00.000000000Z"
      assert $initTimestamp(2001,2,3,4,5) == "2001-02-03T04:05:00.000000000Z"
      assert $initTimestamp(2001,2,3,4,5,6) == "2001-02-03T04:05:06.000000000Z"
      assert $initTimestamp(2001,2,3,4,5,6,7,8,9) == "2001-02-03T04:05:06.007008009Z"

      assert getTime().toTimestamp is Timestamp
      assert now().toTimestamp is Timestamp

    block:
      let t = initTimestamp(0)
      assert $(t + DAY) == "1970-01-02T00:00:00.000000000Z"
      assert $(t + HOUR) == "1970-01-01T01:00:00.000000000Z"
      assert $(t + MINUTE) == "1970-01-01T00:01:00.000000000Z"
      assert $(t + SECOND) == "1970-01-01T00:00:01.000000000Z"
      assert $(t + MILLI_SECOND) == "1970-01-01T00:00:00.001000000Z"
      assert $(t + MICRO_SECOND) == "1970-01-01T00:00:00.000001000Z"
      assert $(t + NANO_SECOND) == "1970-01-01T00:00:00.000000001Z"
      assert $(t - NANO_SECOND) == "1969-12-31T23:59:59.999999999Z"
      
      assert $(t + 1) == "1970-01-01T00:00:00.000000001Z"
      assert $(t + 5*MINUTE + 30*SECOND) == "1970-01-01T00:05:30.000000000Z"

      let t2 = t + DAY 
      assert t2 - t == 86400 * SECOND

    block:
      let a = initTimestamp(0)
      let b = initTimestamp(1)
      assert a < b
      assert a <= b
      assert max(a,b) == b
      assert min(a,b) == a

    block:
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

    block:
      let t = initTimestamp(2001,2,3,4,5,6,7,8,9)
      # human readable time
      assert $t == "2001-02-03T04:05:06.007008009Z"

      # zulu is provided at milli-second precision same as javascript
      assert t.zulu == "2001-02-03T04:05:06.007Z"

      # convert to int64
      assert t.i64 is int64

      assert t.toDateTime == initDateTime(3, mFeb, 2001, 4, 5, 6, 7008009, utc())