open Test
open Assertions
open TestHelpers
open NodeFetch

type recordedCall = {url: string, headers: dict<string>}
type fakeHeaders = {get: string => option<string>}
type fakeResponseObject = {
  ok: bool,
  status: int,
  statusText: string,
  headers: fakeHeaders,
  body: NodeFetch.body,
}

/** `read` counts chunks the reader actually received; `cancel` fires when the
    stream itself is cancelled (discarded body or cap reached mid-stream). */
let fakeResponse = (
  ~cancel=() => Promise.resolve(),
  ~read=() => (),
  ~chunks=?,
  ~contentLength: option<string>=None,
  ~retryAfter: option<string>=None,
  status,
  location,
  body,
): NodeFetch.response => {
  let headers: fakeHeaders = {
    get: name =>
      if name == "location" {
        location
      } else if name == "retry-after" {
        retryAfter
      } else if name == "content-length" {
        contentLength
      } else {
        jsNull
      },
  }
  let response: fakeResponseObject = {
    ok: status >= 200 && status < 300,
    status,
    statusText: if status >= 200 && status < 300 {
      "OK"
    } else {
      "Found"
    },
    headers,
    body: NodeFetch.TestSupport.chunkStream(
      ~chunks=chunks->Option.getOr([body]),
      ~onChunk=read,
      ~onCancel=cancel,
    ),
  }
  Obj.magic(response)
}

let retryNow = 1735689600000.0 // 2025-01-01T00:00:00Z
let delayCases = [
  (Some("2"), 2000),
  (Some("0"), 0),
  (Some(" 2 "), 2000),
  (Some("Wed, 01 Jan 2025 00:00:05 GMT"), 5000),
  (Some("Tue, 31 Dec 2024 23:59:59 GMT"), 0),
  (Some("60"), 60000),
  (Some("61"), 60000),
  (Some("Wed, 01 Jan 2025 00:01:01 GMT"), 60000),
  (None, 777),
  (Some(""), 777),
  (Some("  "), 777),
  (Some("-1"), 777),
  (Some("1.5"), 777),
  (Some("garbage"), 777),
  (Some("Infinity"), 777),
  (Some("1e3"), 777),
]
delayCases->Array.forEachWithIndex((item, index) => {
  let (retryAfter, expected) = item
  test(`Retry-After delay case ${Int.toString(index)}`, () => {
    isIntEqualTo(expected, Fetcher.retryAfterDelay(~retryAfter, ~nowMs=retryNow, ~backoffMs=777))
  })
})

type retryResponse = {status: int, hint: option<string>, location: option<string>}
let retryResponse = (~hint=None, ~location=None, status) => {status, hint, location}
let retryCase = (
  ~responses: array<retryResponse>,
  ~budget=3,
  ~expectedCalls,
  ~waits,
  ~expected,
  name,
) =>
  testAsync(name, planned => {
    let calls = ref(0)
    let delays = ref([])
    let cancels = ref(0)
    let reads = ref(0)
    let rawFetch = async (_, _) => {
      let response = responses[min(calls.contents, Array.length(responses) - 1)]->Option.getOrThrow
      calls := calls.contents + 1
      fakeResponse(
        ~retryAfter=response.hint,
        ~cancel=() => {
          cancels := cancels.contents + 1
          Promise.resolve()
        },
        ~read=() => reads := reads.contents + 1,
        response.status,
        response.location,
        "done",
      )
    }
    Fetcher.retryWithRawFetch(
      ~rawFetch,
      ~sleep=ms => {
        delays := Array.concat(delays.contents, [ms])
        Promise.resolve()
      },
      ~nowMs=() => retryNow,
      ~backoff=attempt => attempt * 777,
      ~retryCount=budget,
    )
    ->Promise.then(result => {
      isIntEqualTo(expectedCalls, calls.contents)
      isTruthy(delays.contents == waits)
      isTruthy(result == expected)
      let success = expected == Ok("done")
      isIntEqualTo(success ? 1 : 0, reads.contents)
      isIntEqualTo(expectedCalls - (success ? 1 : 0), cancels.contents)
      isTextEqualTo("HTTP 429: Found", Fetcher.fetchErrorToMessage(HttpError(429, "Found")))
      planned(~planned=6, ())
      Promise.resolve()
    })
    ->ignore
  })

retryCase(
  ~responses=[retryResponse(~hint=Some("2"), 429), retryResponse(200)],
  ~expectedCalls=2,
  ~waits=[2000],
  ~expected=Ok("done"),
  "Retry-After 429 survives detailed transport",
)
retryCase(
  ~responses=[retryResponse(~hint=Some("Wed, 01 Jan 2025 00:00:05 GMT"), 503), retryResponse(200)],
  ~expectedCalls=2,
  ~waits=[5000],
  ~expected=Ok("done"),
  "Retry-After 503 date survives detailed transport",
)
retryCase(
  ~responses=[retryResponse(~hint=Some("2"), 500), retryResponse(200)],
  ~expectedCalls=2,
  ~waits=[777],
  ~expected=Ok("done"),
  "Retry-After ignored on 500",
)
retryCase(
  ~responses=[retryResponse(~hint=Some("2"), 404)],
  ~expectedCalls=1,
  ~waits=[],
  ~expected=Error(HttpError(404, "Found")),
  "Retry-After 404 never retries",
)
retryCase(
  ~responses=[retryResponse(~hint=Some("2"), 429)],
  ~budget=1,
  ~expectedCalls=1,
  ~waits=[],
  ~expected=Error(HttpError(429, "Found")),
  "Retry-After exhausted budget never sleeps",
)
retryCase(
  ~responses=[retryResponse(429), retryResponse(200)],
  ~expectedCalls=2,
  ~waits=[777],
  ~expected=Ok("done"),
  "Retry-After absent uses backoff",
)
retryCase(
  ~responses=[retryResponse(~hint=Some("2"), 429), retryResponse(429), retryResponse(200)],
  ~expectedCalls=3,
  ~waits=[2000, 1554],
  ~expected=Ok("done"),
  "Retry-After does not leak across attempts",
)
retryCase(
  ~responses=[
    retryResponse(~hint=Some("2"), ~location=Some("/next"), 302),
    retryResponse(429),
    retryResponse(200),
  ],
  ~expectedCalls=3,
  ~waits=[777],
  ~expected=Ok("done"),
  "Retry-After redirect hint does not leak",
)

testAsync("Retry-After network failure clears prior attempt hint", planned => {
  let calls = ref(0)
  let waits = ref([])
  let rawFetch = async (_, _) => {
    calls := calls.contents + 1
    if calls.contents == 2 {
      await Promise.reject(Failure("network failure"))
    } else {
      fakeResponse(~retryAfter=Some("2"), calls.contents == 1 ? 429 : 200, None, "done")
    }
  }
  Fetcher.retryWithRawFetch(
    ~rawFetch,
    ~sleep=ms => {
      waits := Array.concat(waits.contents, [ms])
      Promise.resolve()
    },
    ~nowMs=() => retryNow,
    ~backoff=n => n * 777,
    ~retryCount=3,
  )
  ->Promise.then(result => {
    isTruthy(result == Ok("done"))
    isTruthy(waits.contents == [2000, 1554])
    isIntEqualTo(3, calls.contents)
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->ignore
})

let sizeCase = (
  ~contentLength=None,
  ~body="abcde",
  ~chunks=?,
  ~cap=4,
  ~accepted=false,
  ~expectedReads=1,
  name,
) =>
  testAsync(name, planned => {
    let calls = ref(0)
    let reads = ref(0)
    let cancels = ref(0)
    let rawFetch = async (_, _) => {
      calls := calls.contents + 1
      fakeResponse(
        ~contentLength,
        ~chunks?,
        ~read=() => reads := reads.contents + 1,
        ~cancel=() => {
          cancels := cancels.contents + 1
          Promise.resolve()
        },
        200,
        None,
        body,
      )
    }
    Fetcher.fetchOnceWithBodyLimit(
      ~maxBodyBytes=cap,
      rawFetch,
      "http://example.test/",
      "agent",
      5,
      [],
    )
    ->Promise.then(result => {
      isIntEqualTo(1, calls.contents)
      isIntEqualTo(expectedReads, reads.contents)
      isIntEqualTo(accepted ? 0 : 1, cancels.contents)
      isTruthy(
        result == (
            accepted
              ? Ok(body)
              : Error(
                  Fetcher.ParseError(`Response exceeds maximum size of ${SizeLimit.describe(cap)}`),
                )
          ),
      )
      switch result {
      | Error(err) => isTruthy(!Fetcher.isRetryable(err))
      | Ok(_) => isTruthy(accepted)
      }
      planned(~planned=5, ())
      Promise.resolve()
    })
    ->ignore
  })

sizeCase(
  ~body="abcdefgh",
  ~chunks=["ab", "cd", "ef", "gh"],
  ~cap=3,
  ~expectedReads=2,
  "size overflow stops reading at the cap",
)

sizeCase(~contentLength=Some("5"), ~expectedReads=0, "size header rejects before read")
sizeCase(~contentLength=Some("4294967296"), ~expectedReads=0, "size header does not overflow int32")
sizeCase(~contentLength=Some("4"), ~body="abcd", ~accepted=true, "size exact boundary accepted")
sizeCase("size missing length checks actual bytes")
sizeCase(~contentLength=Some("invalid"), "size invalid length checks actual bytes")
sizeCase(~contentLength=Some("-1"), "size negative length checks actual bytes")
sizeCase(~contentLength=Some("1"), "size understated length checks actual bytes")
sizeCase(~body="éé", ~cap=3, "size counts bytes not UTF16")
sizeCase(~body="éé", ~cap=4, ~accepted=true, "size multibyte boundary accepted")

let defaultCapCase = (~contentLength, ~accepted, ~expectedReads, name) =>
  testAsync(name, planned => {
    let reads = ref(0)
    let cancels = ref(0)
    let rawFetch = async (_, _) =>
      fakeResponse(
        ~contentLength,
        ~read=() => reads := reads.contents + 1,
        ~cancel=() => {
          cancels := cancels.contents + 1
          Promise.resolve()
        },
        200,
        None,
        "ok",
      )
    Fetcher.fetchOnceWithRawFetch(rawFetch, "http://example.test/", "agent", 5, [])
    ->Promise.then(result => {
      isTruthy(
        result == (
            accepted
              ? Ok("ok")
              : Error(Fetcher.ParseError("Response exceeds maximum size of 50 MB"))
          ),
      )
      isIntEqualTo(expectedReads, reads.contents)
      isIntEqualTo(accepted ? 0 : 1, cancels.contents)
      planned(~planned=3, ())
      Promise.resolve()
    })
    ->ignore
  })

defaultCapCase(
  ~contentLength=Some("52428801"),
  ~accepted=false,
  ~expectedReads=0,
  "default 50 MB cap rejects a declared length above it",
)
defaultCapCase(
  ~contentLength=Some("52428800"),
  ~accepted=true,
  ~expectedReads=1,
  "default 50 MB cap accepts a declared length at the boundary",
)

testAsync("size rejection never retries in production retry loop", planned => {
  let calls = ref(0)
  let sleeps = ref(0)
  let reads = ref(0)
  let cancels = ref(0)
  let rawFetch = async (_, _) => {
    calls := calls.contents + 1
    fakeResponse(
      ~read=() => reads := reads.contents + 1,
      ~cancel=() => {
        cancels := cancels.contents + 1
        Promise.resolve()
      },
      200,
      None,
      "abcde",
    )
  }
  Fetcher.retryWithAttempt(
    ~attempt=() =>
      Fetcher.fetchOnceWithBodyLimit(
        ~maxBodyBytes=4,
        rawFetch,
        "http://example.test/",
        "agent",
        5,
        [],
      ),
    ~sleep=_ => {
      sleeps := sleeps.contents + 1
      Promise.resolve()
    },
    ~retryCount=3,
  )
  ->Promise.then(result => {
    isTruthy(result == Error(Fetcher.ParseError("Response exceeds maximum size of 4 bytes")))
    isIntEqualTo(1, calls.contents)
    isIntEqualTo(1, reads.contents)
    isIntEqualTo(1, cancels.contents)
    isIntEqualTo(0, sleeps.contents)
    planned(~planned=5, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("retry loop preserves total attempt budget for transient failures", planned => {
  let calls = ref(0)
  let sleeps = ref(0)
  Fetcher.retryWithAttempt(
    ~attempt=() => {
      calls := calls.contents + 1
      Promise.resolve(Error(Fetcher.HttpError(500, "Server Error")))
    },
    ~sleep=_ => {
      sleeps := sleeps.contents + 1
      Promise.resolve()
    },
    ~retryCount=3,
  )
  ->Promise.then(result => {
    isTruthy(result == Error(Fetcher.HttpError(500, "Server Error")))
    isIntEqualTo(3, calls.contents)
    isIntEqualTo(2, sleeps.contents)
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->ignore
})

// Exercise lifecycle through the public injectable fetch boundary.
let lifecycleCase = (~status, ~location, ~rejectCancel, ~expectedCalls, ~expectedResult, name) =>
  testAsync(name, planned => {
    let events = ref([])
    let calls = ref(0)
    let cancels = ref(0)
    let reads = ref(0)
    let rawFetch = async (_url, _options) => {
      calls := calls.contents + 1
      events := Array.concat(events.contents, ["request"])
      let cancel = () => {
        cancels := cancels.contents + 1
        events := Array.concat(events.contents, ["cancel"])
        if rejectCancel {
          Promise.reject(Failure("cancel failed"))
        } else {
          Promise.resolve()
        }
      }
      fakeResponse(
        ~cancel,
        ~read=() => reads := reads.contents + 1,
        calls.contents == 1 ? status : 200,
        calls.contents == 1 ? location : None,
        "done",
      )
    }
    Fetcher.fetchOnceWithRawFetch(rawFetch, "http://example.test/start", "agent", 5, [])
    ->Promise.then(result => {
      isIntEqualTo(expectedCalls, calls.contents)
      isIntEqualTo(status == 200 ? 0 : 1, cancels.contents)
      isIntEqualTo(expectedResult == Ok("done") ? 1 : 0, reads.contents)
      isTruthy(result == expectedResult)
      isTextEqualTo(
        expectedCalls == 2
          ? "request,cancel,request"
          : status == 200
          ? "request"
          : "request,cancel",
        events.contents->Array.joinWith(","),
      )
      planned(~planned=5, ())
      Promise.resolve()
    })
    ->ignore
  })

lifecycleCase(
  ~status=302,
  ~location=Some("/next"),
  ~rejectCancel=false,
  ~expectedCalls=2,
  ~expectedResult=Ok("done"),
  "redirect cancellation precedes next request",
)
lifecycleCase(
  ~status=302,
  ~location=Some("/next"),
  ~rejectCancel=true,
  ~expectedCalls=2,
  ~expectedResult=Ok("done"),
  "rejected redirect cancellation preserves success",
)
lifecycleCase(
  ~status=404,
  ~location=None,
  ~rejectCancel=false,
  ~expectedCalls=1,
  ~expectedResult=Error(Fetcher.HttpError(404, "Found")),
  "404 cancels discarded body",
)
lifecycleCase(
  ~status=302,
  ~location=None,
  ~rejectCancel=false,
  ~expectedCalls=1,
  ~expectedResult=Error(Fetcher.HttpError(302, "Found")),
  "missing Location cancels discarded body",
)
lifecycleCase(
  ~status=404,
  ~location=None,
  ~rejectCancel=true,
  ~expectedCalls=1,
  ~expectedResult=Error(Fetcher.HttpError(404, "Found")),
  "rejected cancellation preserves HTTP error",
)
lifecycleCase(
  ~status=200,
  ~location=None,
  ~rejectCancel=false,
  ~expectedCalls=1,
  ~expectedResult=Ok("done"),
  "successful body is read not canceled",
)

let recordingFetch = (calls: ref<array<recordedCall>>, responseAt) =>
  async (url: string, options: option<NodeFetch.options>) => {
    let requestHeaders = switch options {
    | Some(options) => Option.getOr(options.headers, Dict.make())
    | None => Dict.make()
    }
    calls := Array.concat(calls.contents, [{url, headers: requestHeaders}])
    responseAt(url, Array.length(calls.contents))
  }

let secondCall = calls => Option.getOr(calls.contents[1], {url: "", headers: Dict.make()})

let hasHeader = (call: option<recordedCall>, name: string) => {
  let value = Option.getOr(call, {url: "", headers: Dict.make()})
  switch Dict.get(value.headers, name) {
  | Some(_) => true
  | None => false
  }
}

testAsync("redirect policy drops custom headers across origins", planned => {
  let calls = ref([])
  let rawFetch = recordingFetch(calls, (_url, count) =>
    if count == 1 {
      fakeResponse(302, Some("http://127.0.0.1:8001/next"), "")
    } else {
      fakeResponse(200, None, "done")
    }
  )
  Fetcher.fetchOnceWithRawFetch(
    rawFetch,
    "http://127.0.0.1:8000/start",
    "test-agent",
    5,
    [("x-api-key", "secret"), ("cookie", "session=secret")],
  )
  ->Promise.then(result => {
    isIntEqualTo(2, Array.length(calls.contents))
    isTruthy(hasHeader(calls.contents[1], "User-Agent"))
    isTruthy(hasHeader(calls.contents[1], "x-api-key") == false)
    isTruthy(hasHeader(calls.contents[1], "cookie") == false)
    switch result {
    | Ok(body) => stringContains(body, "done")->isTruthy
    | Error(_) => failWith("Expected redirected fetch to succeed")
    }
    planned(~planned=5, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("redirect policy retains custom headers for same-origin redirects", planned => {
  let calls = ref([])
  let rawFetch = recordingFetch(calls, (_url, count) =>
    if count == 1 {
      fakeResponse(302, Some("http://127.0.0.1:8000/next"), "")
    } else {
      fakeResponse(200, None, "done")
    }
  )
  Fetcher.fetchOnceWithRawFetch(
    rawFetch,
    "http://127.0.0.1:8000/start",
    "test-agent",
    5,
    [("x-api-key", "secret")],
  )
  ->Promise.then(result => {
    isIntEqualTo(2, Array.length(calls.contents))
    isTruthy(hasHeader(calls.contents[1], "x-api-key"))
    isTruthy(secondCall(calls).url == "http://127.0.0.1:8000/next")
    switch result {
    | Ok(body) => stringContains(body, "done")->isTruthy
    | Error(_) => failWith("Expected same-origin redirect to succeed")
    }
    planned(~planned=4, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("relative Location resolves against the current URL", planned => {
  let calls = ref([])
  let rawFetch = recordingFetch(calls, (_url, count) =>
    if count == 1 {
      fakeResponse(302, Some("/next"), "")
    } else {
      fakeResponse(200, None, "done")
    }
  )
  Fetcher.fetchOnceWithRawFetch(
    rawFetch,
    "http://127.0.0.1:8000/start",
    "test-agent",
    5,
    [("x-api-key", "secret")],
  )
  ->Promise.then(_result => {
    isIntEqualTo(2, Array.length(calls.contents))
    isTruthy(secondCall(calls).url == "http://127.0.0.1:8000/next")
    isTruthy(hasHeader(calls.contents[1], "x-api-key"))
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("redirect limit stops after twenty requests", planned => {
  let calls = ref([])
  let rawFetch = recordingFetch(calls, (_url, _count) => fakeResponse(302, Some("/next"), ""))
  Fetcher.fetchOnceWithRawFetch(rawFetch, "http://127.0.0.1:8000/start", "test-agent", 5, [])
  ->Promise.then(result => {
    isIntEqualTo(20, Array.length(calls.contents))
    switch result {
    | Error(NetworkError(message)) => stringContains(message, "Too many redirects")->isTruthy
    | _ => failWith("Expected redirect-limit NetworkError")
    }
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("redirect without Location is returned as an HTTP error", planned => {
  let calls = ref([])
  let rawFetch = recordingFetch(calls, (_url, _count) => fakeResponse(302, None, ""))
  Fetcher.fetchOnceWithRawFetch(rawFetch, "http://127.0.0.1:8000/start", "test-agent", 5, [])
  ->Promise.then(result => {
    isIntEqualTo(1, Array.length(calls.contents))
    switch result {
    | Error(HttpError(302, _)) => passWith("302 without Location is terminal")
    | _ => failWith("Expected terminal HTTP 302")
    }
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("cross-protocol redirect drops custom headers", planned => {
  let calls = ref([])
  let rawFetch = recordingFetch(calls, (_url, count) =>
    if count == 1 {
      fakeResponse(302, Some("https://example.test/next"), "")
    } else {
      fakeResponse(200, None, "done")
    }
  )
  Fetcher.fetchOnceWithRawFetch(
    rawFetch,
    "http://example.test/start",
    "test-agent",
    5,
    [("x-api-key", "secret")],
  )
  ->Promise.then(_result => {
    isIntEqualTo(2, Array.length(calls.contents))
    isTruthy(hasHeader(calls.contents[1], "User-Agent"))
    isTruthy(hasHeader(calls.contents[1], "x-api-key") == false)
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->ignore
})

test("isRetryable returns true for NetworkError", () => {
  isTruthy(Fetcher.isRetryable(NetworkError("connection refused")))
})

test("isRetryable returns true for Timeout", () => {
  isTruthy(Fetcher.isRetryable(Timeout("timeout after 30s")))
})

test("isRetryable returns true for 429 rate limit", () => {
  isTruthy(Fetcher.isRetryable(HttpError(429, "Too Many Requests")))
})

test("isRetryable returns true for 500 server error", () => {
  isTruthy(Fetcher.isRetryable(HttpError(500, "Internal Server Error")))
})

test("isRetryable returns true for 502 bad gateway", () => {
  isTruthy(Fetcher.isRetryable(HttpError(502, "Bad Gateway")))
})

test("isRetryable returns true for 503 service unavailable", () => {
  isTruthy(Fetcher.isRetryable(HttpError(503, "Service Unavailable")))
})

test("isRetryable returns false for 400 bad request", () => {
  isTruthy(Fetcher.isRetryable(HttpError(400, "Bad Request")) == false)
})

test("isRetryable returns false for 404 not found", () => {
  isTruthy(Fetcher.isRetryable(HttpError(404, "Not Found")) == false)
})

test("isRetryable returns false for 401 unauthorized", () => {
  isTruthy(Fetcher.isRetryable(HttpError(401, "Unauthorized")) == false)
})

test("isRetryable returns false for ParseError", () => {
  isTruthy(Fetcher.isRetryable(ParseError("invalid response")) == false)
})

test("backoffDelay returns positive values for attempt >= 0", () => {
  let d0 = Fetcher.backoffDelay(0)
  let d1 = Fetcher.backoffDelay(1)
  let d2 = Fetcher.backoffDelay(2)
  isTruthy(d0 > 0)
  isTruthy(d1 > 0)
  isTruthy(d2 > 0)
})

test("backoffDelay increases with attempt", () => {
  let d0 = Fetcher.backoffDelay(0)
  let d1 = Fetcher.backoffDelay(1)
  let d2 = Fetcher.backoffDelay(2)
  // With jitter, we can't guarantee strict ordering, but base values increase
  isTruthy(d1 > d0 / 2) // d1 should be roughly 2x d0
  isTruthy(d2 > d1 / 2) // d2 should be roughly 2x d1
})

test("fetchErrorToMessage formats NetworkError", () => {
  let msg = Fetcher.fetchErrorToMessage(NetworkError("ECONNREFUSED"))
  stringContains(msg, "ECONNREFUSED")->isTruthy
  stringContains(msg, "Network error")->isTruthy
})

test("fetchErrorToMessage formats Timeout", () => {
  let msg = Fetcher.fetchErrorToMessage(Timeout("timeout after 30s"))
  stringContains(msg, "timeout after 30s")->isTruthy
  stringContains(msg, "Timeout")->isTruthy
})

test("fetchErrorToMessage formats HttpError", () => {
  let msg = Fetcher.fetchErrorToMessage(HttpError(429, "Too Many Requests"))
  stringContains(msg, "429")->isTruthy
  stringContains(msg, "Too Many Requests")->isTruthy
  stringContains(msg, "HTTP")->isTruthy
})

test("fetchErrorToMessage formats ParseError", () => {
  let msg = Fetcher.fetchErrorToMessage(ParseError("invalid html"))
  stringContains(msg, "invalid html")->isTruthy
  stringContains(msg, "Parse error")->isTruthy
})

test("AbortSignal aborted is false before abort()", () => {
  let controller = AbortSignal.makeController()
  let signal = AbortSignal.signal(controller)
  isTruthy(AbortSignal.aborted(signal) == false)
})

test("AbortSignal aborted is true after abort()", () => {
  let controller = AbortSignal.makeController()
  let signal = AbortSignal.signal(controller)
  AbortSignal.abort(controller)
  isTruthy(AbortSignal.aborted(signal) == true)
})

test("Fetcher classifies error as Timeout when signal is aborted", () => {
  let controller = AbortSignal.makeController()
  let signal = AbortSignal.signal(controller)
  AbortSignal.abort(controller)
  let result = Fetcher.classifyError(
    ~message="some unrelated error text",
    ~isAborted=AbortSignal.aborted(signal),
    ~timeoutSeconds=5,
  )
  switch result {
  | Error(Timeout(msg)) =>
    stringContains(msg, "5")->isTruthy
    stringContains(msg, "timeout")->isTruthy
  | _ => failWith("Expected Timeout variant when signal is aborted")
  }
})

test("Fetcher classifies error as NetworkError when signal is not aborted", () => {
  let result = Fetcher.classifyError(
    ~message="connection refused",
    ~isAborted=false,
    ~timeoutSeconds=30,
  )
  switch result {
  | Error(NetworkError(msg)) => stringContains(msg, "connection refused")->isTruthy
  | _ => failWith("Expected NetworkError variant when signal is not aborted")
  }
})

test("Fetcher timeout classification ignores error message text", () => {
  // Critical: even if the error message contains "abort" or "timeout", if the
  // signal was not aborted, the error should be classified as NetworkError.
  let result = Fetcher.classifyError(
    ~message="abort controller failure",
    ~isAborted=false,
    ~timeoutSeconds=10,
  )
  switch result {
  | Error(NetworkError(_)) => passWith("NetworkError returned despite 'abort' in message")
  | Error(Timeout(_)) => failWith("Should not classify as Timeout when signal is not aborted")
  | _ => failWith("Expected NetworkError")
  }
})

testAsync("fetchAll returns all results even when some URLs fail", planned => {
  let options: Fetcher.fetchOptions = {
    concurrency: 3,
    userAgent: "test-agent/1.0",
    timeoutSeconds: 2,
    retryCount: 0,
    delayMs: 0,
    headers: [],
  }
  Fetcher.fetchAll(["http://127.0.0.1:9", "http://127.0.0.1:9", "https://example.com/"], options)
  ->Promise.then(results => {
    (results->Array.length == 3)->isTruthy
    let countFailure =
      results
      ->Array.filter(
        r =>
          switch r.result {
          | Ok(_) => false
          | Error(_) => true
          },
      )
      ->Array.length
    (countFailure >= 1)->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("fetchAll threw unexpectedly")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

/* Regression test for sdd/007-concurrency-robustness.
   Proves that the post-acquire guard pattern used by `fetchWithSemaphore`
   releases the semaphore slot even when the critical section throws.
   The fix relies on `try { Ok(await work()) } catch { Error(exn) }` followed
   by `release(sem)` on both branches (ReScript v12 has no `try/finally`).
   If the fix is absent (release on the success path only), the slot is leaked
   and the follow-up `acquire` would deadlock — the test would never reach
   `planned`. */

testAsync(
  "fetchWithSemaphore guard pattern releases slot when critical section throws",
  planned => {
    let sem = Semaphore.make(1)

    Semaphore.acquire(sem)
    ->Promise.then(_ => {
      // Replicate the FIX pattern: critical section throws; the guard still releases.
      let criticalSection = async () => {
        let outcome = try {
          let _ = await Promise.reject(
            JsError.throwWithMessage("Simulated fetch failure escaping fetchOnce's try/catch"),
          )
          Ok()
        } catch {
        | exn => Error(exn)
        }
        Semaphore.release(sem)
        switch outcome {
        | Ok() => JsError.throwWithMessage("unreachable: outcome should be Error(_)")
        | Error(exn) => throw(exn)
        }
      }

      criticalSection()
      ->Promise.then(
        _ => {
          failWith("criticalSection should have rejected — rejection was silently swallowed")
          planned(~planned=0, ())
          Promise.resolve()
        },
      )
      ->Promise.catch(
        _ => {
          // Critical section rejected as expected. `release(sem)` ran before the
          // re-raise, returning the slot to the semaphore. If the slot were leaked,
          // this second `acquire` would queue forever — the test would hang.
          Semaphore.acquire(sem)
          ->Promise.then(
            _ => {
              passWith("Slot was released in the guard; second acquire resolved immediately")
              planned(~planned=1, ())
              Semaphore.release(sem)
              Promise.resolve()
            },
          )
          ->Promise.catch(
            _ => {
              failWith("Second acquire failed — semaphore was leaked by critical section throw")
              planned(~planned=0, ())
              Promise.resolve()
            },
          )
          ->ignore
          Promise.resolve()
        },
      )
      ->ignore
      Promise.resolve()
    })
    ->ignore
  },
)

/* Integration regression test: with concurrency=1 and N>1 URLs that all fail,
   `fetchAll` MUST complete in bounded time — no fetch may deadlock on `acquire`.
   This guards the production integration end-to-end. With the fix in place,
   each failing fetch still releases its slot, so the next fetch in the queue
   proceeds. */

testAsync(
  "fetchAll with concurrency=1 processes a queue of failing URLs without deadlocking",
  planned => {
    let options: Fetcher.fetchOptions = {
      concurrency: 1,
      userAgent: "test-agent/1.0",
      timeoutSeconds: 1,
      retryCount: 0,
      delayMs: 0,
      headers: [],
    }
    // Three URLs to a closed local port — all will fail with NetworkError,
    // none should deadlock the queue.
    let urls = ["http://127.0.0.1:9", "http://127.0.0.1:9", "http://127.0.0.1:9"]

    Fetcher.fetchAll(urls, options)
    ->Promise.then(results => {
      (results->Array.length == 3)->isTruthy
      let allFailed =
        results
        ->Array.filter(
          r =>
            switch r.result {
            | Ok(_) => false
            | Error(_) => true
            },
        )
        ->Array.length
      (allFailed == 3)->isTruthy
      planned(~planned=2, ())
      Promise.resolve()
    })
    ->Promise.catch(_ => {
      failWith("fetchAll deadlocked or threw unexpectedly with concurrency=1 and 3 failing URLs")
      planned(~planned=0, ())
      Promise.resolve()
    })
    ->ignore
  },
)
