{.used.}

# nim-result is also available stand-alone from https://github.com/arnetheduck/nim-result/

import ../stew/results

type R = Result[int, string]

# Basic usage, producer

block:
  func works(): R = R.ok(42)
  func works2(): R = result.ok(42)
  func works3(): R = ok(42)

  func fails(): R = R.err("dummy")
  func fails2(): R = result.err("dummy")
  func fails3(): R = err("dummy")

  let
    rOk = works()
    rOk2 = works2()
    rOk3 = works3()

    rErr = fails()
    rErr2 = fails2()
    rErr3 = fails3()

  doAssert rOk.isOk
  doAssert rOk2.isOk
  doAssert rOk3.isOk
  doAssert (not rOk.isErr)

  doAssert rErr.isErr
  doAssert rErr2.isErr
  doAssert rErr3.isErr

  # Mutate
  var x = rOk
  x.err("failed now")
  doAssert x.isErr
  doAssert x.error == "failed now"

  # Combine
  doAssert (rOk and rErr).isErr
  doAssert (rErr and rOk).isErr
  doAssert (rOk or rErr).isOk
  doAssert (rErr or rOk).isOk

  # Fail fast
  proc failFast(): int = raiseAssert "shouldn't evaluate"
  proc failFastR(): R = raiseAssert "shouldn't evaluate"

  doAssert (rErr and failFastR()).isErr
  doAssert (rOk or failFastR()).isOk

  # `and` heterogenous types
  doAssert (rOk and Result[string, string].ok($rOk.get())).get() == $(rOk[])

  # `or` heterogenous types
  doAssert (rErr or Result[int, int].err(len(rErr.error))).error == len(rErr.error)

  # Exception on access
  doAssert (try: (discard rOk.tryError(); false) except ResultError[int]: true)
  doAssert (try: (discard rErr.tryGet(); false) except ResultError[string]: true)

  # Value access or default
  doAssert rOk.get(100) == rOk.get()
  doAssert rErr.get(100) == 100

  doAssert rOk.get() == rOk.unsafeGet()

  rOk.isOkOr: raiseAssert "should not end up in here"
  rErr.isErrOr: raiseAssert "should not end up in here"

  rErr.isOkOr:
    doAssert error == rErr.error()

  rOk.isErrOr:
    doAssert value == rOk.value()

  doAssert rOk.valueOr(failFast()) == rOk.value()
  let rErrV = rErr.valueOr:
    error.len
  doAssert rErrV == rErr.error.len()

  let rOkV = rOk.errorOr:
    $value
  doAssert rOkV == $rOk.get()

  # Exceptions -> results
  func raises(): int =
    raise (ref CatchableError)(msg: "hello")

  let c = catch:
    raises()
  doAssert c.isErr

  # De-reference
  when (NimMajor, NimMinor) >= (1, 6):
    {.warning[BareExcept]:off.}

  try:
    echo rErr[]
    doAssert false
  except:
    discard

  when (NimMajor, NimMinor) >= (1, 6):
    {.warning[BareExcept]:on.}

  # Comparisons
  doAssert (rOk == rOk)
  doAssert (rErr == rErr)
  doAssert (rOk != rErr)

  # Mapping
  doAssert (rOk.map(func(x: int): string = $x)[] == $rOk.value)
  doAssert (rOk.map(func(x: int) = discard)).isOk()

  doAssert (rOk.flatMap(
    proc(x: int): Result[string, string] = Result[string, string].ok($x))[] == $rOk.value)

  doAssert (rErr.mapErr(func(x: string): string = x & "no!").error == (rErr.error & "no!"))

  # Casts and conversions
  doAssert rOk.mapConvert(int64)[] == int64(42)
  doAssert rOk.mapConvert(uint64)[] == uint64(42)
  doAssert rOk.mapCast(int8)[] == int8(42)

  doAssert (rErr.orErr(32)).error == 32
  doAssert (rOk.orErr(failFast())).get() == rOk.get()

  # string conversion
  doAssert $rOk == "ok(42)"
  doAssert $rErr == "err(dummy)"

  # Exception interop
  let e = capture(int, (ref ValueError)(msg: "test"))
  doAssert e.isErr
  doAssert e.error.msg == "test"

  try:
    discard rOk.tryError()
    doAssert false, "should have raised"
  except ValueError:
    discard

  try:
    discard e.tryGet()
    doAssert false, "should have raised"
  except ValueError as e:
    doAssert e.msg == "test"

  # Nice way to checks
  if (let v = works(); v.isOk):
    doAssert v[] == v.value

  # Expectations
  doAssert rOk.expect("testOk never fails") == 42

  # Question mark operator
  func testQn(): Result[int, string] =
    let x = ?works() - ?works()
    ok(x)

  func testQn2(): Result[int, string] =
    # looks like we can even use it creatively like this
    if ?fails() == 42: raise (ref ValueError)(msg: "shouldn't happen")

  func testQn3(): Result[bool, string] =
    # different T but same E
    let x = ?works() - ?works()
    ok(x == 0)

  doAssert testQn()[] == 0
  doAssert testQn2().isErr
  doAssert testQn3()[]

  proc heterOr(): Result[int, int] =
    let value = ? (rErr or err(42))  # TODO ? binds more tightly than `or` - can that be fixed?
    doAssert value + 1 == value, "won't reach, ? will shortcut execution"
    ok(value)

  doAssert heterOr().error() == 42

  # Flatten
  doAssert Result[R, string].ok(rOk).flatten() == rOk
  doAssert Result[R, string].ok(rErr).flatten() == rErr

  # Filter
  doAssert rOk.filter(proc(x: int): auto = Result[void, string].ok()) == rOk
  doAssert rOk.filter(proc(x: int): auto = Result[void, string].err("filter")).error == "filter"
  doAssert rErr.filter(proc(x: int): auto = Result[void, string].err("filter")) == rErr

# Exception conversions - toException must not be inside a block
type
  AnEnum = enum
    anEnumA
    anEnumB
  AnException = ref object of CatchableError
    v: AnEnum

func toException(v: AnEnum): AnException = AnException(v: v)

func testToException(): int =
  try:
    var r = Result[int, AnEnum].err(anEnumA)
    r.tryGet
  except AnException:
    42

doAssert testToException() == 42

type
  AnEnum2 = enum
    anEnum2A
    anEnum2B

func testToString(): int =
  try:
    var r = Result[int, AnEnum2].err(anEnum2A)
    r.tryGet
  except ResultError[AnEnum2]:
    42

doAssert testToString() == 42

block: # Result[void, E]
  type VoidRes = Result[void, int]

  func worksVoid(): VoidRes = VoidRes.ok()
  func worksVoid2(): VoidRes = result.ok()
  func worksVoid3(): VoidRes = ok()

  func failsVoid(): VoidRes = VoidRes.err(42)
  func failsVoid2(): VoidRes = result.err(42)
  func failsVoid3(): VoidRes = err(42)

  let
    vOk = worksVoid()
    vOk2 = worksVoid2()
    vOk3 = worksVoid3()

    vErr = failsVoid()
    vErr2 = failsVoid2()
    vErr3 = failsVoid3()

  doAssert vOk.isOk
  doAssert vOk2.isOk
  doAssert vOk3.isOk
  doAssert (not vOk.isErr)

  doAssert vErr.isErr
  doAssert vErr2.isErr
  doAssert vErr3.isErr

  vOk.get()
  vOk.unsafeGet()
  vOk.expect("should never fail")
  vOk[]

  # Comparisons
  doAssert (vOk == vOk)
  doAssert (vErr == vErr)
  doAssert (vOk != vErr)

  # Mapping
  doAssert vOk.map(proc (): int = 42).get() == 42
  vOk.map(proc () = discard).get()

  vOk.mapErr(proc(x: int): int = 10).get()
  vOk.mapErr(proc(x: int) = discard).get()

  doAssert vErr.mapErr(proc(x: int): int = 10).error() == 10

  # string conversion
  doAssert $vOk == "ok()"
  doAssert $vErr == "err(42)"

  # Question mark operator
  func voidF(): VoidRes =
    ok()

  func voidF2(): Result[int, int] =
    ? voidF()

    ok(42)

  doAssert voidF2().isOk

  # flatten
  doAssert Result[VoidRes, int].ok(vOk).flatten() == vOk
  doAssert Result[VoidRes, int].ok(vErr).flatten() == vErr

  # Filter
  doAssert vOk.filter(proc(): auto = Result[void, int].ok()) == vOk
  doAssert vOk.filter(proc(): auto = Result[void, int].err(100)).error == 100
  doAssert vErr.filter(proc(): auto = Result[void, int].err(100)) == vErr

block: # Result[T, void] aka `Opt`
  type OptInt = Result[int, void]

  func worksOpt(): OptInt = OptInt.ok(42)
  func worksOpt2(): OptInt = result.ok(42)
  func worksOpt3(): OptInt = ok(42)

  func failsOpt(): OptInt = OptInt.err()
  func failsOpt2(): OptInt = result.err()
  func failsOpt3(): OptInt = err()

  let
    oOk = worksOpt()
    oOk2 = worksOpt2()
    oOk3 = worksOpt3()

    oErr = failsOpt()
    oErr2 = failsOpt2()
    oErr3 = failsOpt3()

  doAssert oOk.isOk
  doAssert oOk2.isOk
  doAssert oOk3.isOk
  doAssert (not oOk.isErr)

  doAssert oErr.isErr
  doAssert oErr2.isErr
  doAssert oErr3.isErr

  # Comparisons
  doAssert (oOk == oOk)
  doAssert (oErr == oErr)
  doAssert (oOk != oErr)

  doAssert oOk.get() == oOk.unsafeGet()
  oErr.error()
  oErr.unsafeError()

  # Mapping
  doAssert oOk.map(proc(x: int): string = $x).get() == $oOk.get()
  oOk.map(proc(x: int) = discard).get()

  doAssert oOk.mapErr(proc(): int = 10).get() == oOk.get()
  doAssert oOk.mapErr(proc() = discard).get() == oOk.get()

  doAssert oErr.mapErr(proc(): int = 10).error() == 10

  # string conversion
  doAssert $oOk == "ok(42)"
  doAssert $oErr == "none()"

  proc optQuestion(): OptInt =
    let v = ? oOk
    ok(v)

  doAssert optQuestion().isOk()

  # Flatten
  doAssert Result[OptInt, void].ok(oOk).flatten() == oOk
  doAssert Result[OptInt, void].ok(oErr).flatten() == oErr

  # Filter
  doAssert oOk.filter(proc(x: int): auto = Result[void, void].ok()) == oOk
  doAssert oOk.filter(proc(x: int): auto = Result[void, void].err()).isErr()
  doAssert oErr.filter(proc(x: int): auto = Result[void, void].err()) == oErr

  doAssert oOk.filter(proc(x: int): bool = true) == oOk
  doAssert oOk.filter(proc(x: int): bool = false).isErr()
  doAssert oErr.filter(proc(x: int): bool = true) == oErr

  doAssert Opt.some(42).get() == 42
  doAssert Opt.none(int).isNone()

block: # `cstring` dangling reference protection
  type CSRes = Result[void, cstring]

  func cstringF(s: string): CSRes =
    when compiles(err(s)):
      doAssert false

  discard cstringF("test")

block: # Experiments
  # Can formalise it into a template (https://github.com/arnetheduck/nim-result/issues/8)
  template `?=`(v: untyped{nkIdent}, vv: Result): bool =
    (let vr = vv; template v: auto {.used.} = unsafeGet(vr); vr.isOk)

  if f ?= Result[int, string].ok(42):
    doAssert f == 42

  # TODO there's a bunch of operators that one could lift through magic - this
  #      is mainly an example
  template `+`(self, other: Result): untyped =
    ## Perform `+` on the values of self and other, if both are ok
    type R = type(other)
    if self.isOk:
      if other.isOk:
        R.ok(self.value + other.value)
      else:
        R.err(other.error)
    else:
      R.err(self.error)

  let rOk = Result[int, string].ok(42)
  # Simple lifting..
  doAssert (rOk + rOk)[] == rOk.value + rOk.value

  iterator items[T, E](self: Result[T, E]): T =
    ## Iterate over result as if it were a collection of either 0 or 1 items
    ## TODO should a Result[seq[X]] iterate over items in seq? there are
    ##      arguments for and against
    if self.isOk:
      yield self.value

  # Iteration
  var counter2 = 0
  for v in rOk:
    counter2 += 1

  doAssert counter2 == 1, "one-item collection when set"

block: # Constants
  # TODO https://github.com/nim-lang/Nim/issues/20699
  type
    WithOpt = object
      opt: Opt[int]
  const
    noneWithOpt =
      WithOpt(opt: Opt.none(int))
  proc checkIt(v: WithOpt) =
    doAssert v.opt.isNone()
  checkIt(noneWithOpt)
