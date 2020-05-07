import unittest, asyncdispatch
import timestamp

suite "timestamp":

  test "sizeof(Timestamp)":
    check: sizeof(Timestamp) == 8
    
  test "comparison":
    proc doTest {.async.} =
      let s = systemTimestamp()
      await sleepAsync(1)
      let e = systemTimestamp()
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
    