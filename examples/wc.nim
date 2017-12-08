# wc - word, line, character, and byte count
# - http://pubs.opengroup.org/onlinepubs/9699919799/utilities/wc.html POSIX wc
# - https://www.freebsd.org/cgi/man.cgi?query=wc FreeBSD man page for wc

import os, sequtils, strutils, system, tables, terminal, unicode, pegs

import strfmt
import parseopt

const
  VERSION = "0.0.1"
  TOTAL = "total"
  WIDTH = 7

const help = """
Usage: $# [OPTIONS] [FILES]...

  The wc utility displays the number of lines, words, and bytes contained in
  each input file, or standard input (if no file is specified) to the
  standard output. A line is defined as a string of characters delimited by
  a <newline> character. Characters beyond the final <newline> character
  will not be included in the line count.

  A word is defined as a string of characters delimited by white space
  characters. White space characters are the set of characters for which the
  iswspace(3) function returns true. If more than one input file is
  specified, a line of cumulative counts for all the files is displayed on a
  separate line after the output for the last file.

Options:
  -c         The number of bytes in each input file is written to the standard
             output. This will cancel out any prior usage of the -m option.
  -l         The number of lines in each input file is written to the standard
             output.
  -m         The number of characters in each input file is written to the
             standard output. If the current locale does not support multibyte
             characters, this is equivalent to the -c option. This will cancel
             out any prior usage of the -c option.
  -w         The number of words in each input file is written to the standard
             output.
  --version  Show the version and exit.
  --help     Show this message and exit.
"""

type
  Count = enum cBytes, cLines, cMulti, cWords

type
  Context = tuple
    optBytes: bool
    optLines: bool
    optMulti: bool
    optWords: bool
    counts: TableRef[Count, int64]

# Experimental
proc c_memchr(s: pointer, c: cint, n: csize): pointer {.
  importc: "memchr", header: "<string.h>".}
proc c_memset(p: pointer, value: cint, size: csize): pointer {.
  importc: "memset", header: "<string.h>", discardable.}
proc c_fgets(c: cstring, n: cint, f: File): cstring {.
  importc: "fgets", header: "<stdio.h>", tags: [ReadIOEffect].}
proc c_clearerr(f: File): void {.
  importc: "clearerr", header: "<stdio.h>".}

const
  seqShallowFlag = low(int)

type
  TGenSeq {.compilerproc, pure, inheritable.} = object
    len, reserved: int
    when defined(gogc):
      elemSize: int
  PGenSeq {.exportc.} = ptr TGenSeq

template space(s: PGenSeq): int {.dirty.} =
  s.reserved and not seqShallowFlag

proc readLn(f: File, line: var TaintedString, eol: var bool): bool =
  var pos = 0
  var sp: cint = 80
  # Use the currently reserved space for a first try
  if line.string.isNil:
    line = TaintedString(newStringOfCap(80))
  else:
    sp = cint(cast[PGenSeq](line.string).space)
    line.string.setLen(sp)
  while true:
    # memset to \l so that we can tell how far fgets wrote, even on EOF, where
    # fgets doesn't append an \l
    c_memset(addr line.string[pos], '\l'.ord, sp)
    if c_fgets(addr line.string[pos], sp, f) == nil:
      line.string.setLen(0)
      return false
    let m = c_memchr(addr line.string[pos], '\l'.ord, sp)
    if m != nil:
      eol = true
      # \l found: Could be our own or the one by fgets, in any case, we're done
      var last = cast[ByteAddress](m) - cast[ByteAddress](addr line.string[0])
      if last > 0 and line.string[last-1] == '\c':
        line.string.setLen(last+1) # Preserve all characters
        return true
        # We have to distinguish between two possible cases:
        # \0\l\0 => line ending in a null character.
        # \0\l\l => last line without newline, null was put there by fgets.
      elif last > 0 and line.string[last-1] == '\0':
        if last < pos + sp - 1 and line.string[last+1] != '\0':
          dec last
          eol = false # Line without new line
          line.string.setLen(last)
        else:
          line.string.setLen(last+1) # Preserve end of line to count all characters
      else:
        line.string.setLen(last+1)
      return true
    else:
      # fgets will have inserted a null byte at the end of the string.
      dec sp
    # No \l found: Increase buffer and read more
    inc pos, sp
    sp = 128 # read in 128 bytes at a time
    line.string.setLen(pos+sp)

iterator lineIter(f: File): (TaintedString , bool){.tags: [ReadIOEffect].} =
  var res = TaintedString(newStringOfCap(80))
  var eol = false
  while f.readLn(res, eol): yield (res, eol)
# End experimental

proc appName(): string =
  splitFile(getAppFilename())[1]

proc printHelp() =
  styledEcho(fgGreen, help % appName())
  quit QuitSuccess

proc printVersion() =
  styledEcho(fgGreen, "$# version $#" % [appName(), VERSION])
  quit QuitSuccess

proc printError(msg: string) =
  styledWriteLine(stderr, fgRed, "$#: $#" % [appName(), strip(msg)])

proc unexpectedOption(key: string, long:bool=false) =
  var k: string
  if long:
    k = "--$#" % key
  else:
    k = "-$#" % key
  printError("$#: Unexpected option" % k)

proc printCounter(cpt: int64, width: int) =
  stdout.write " {:>{}}".fmt(cpt, width)

proc printCounters(ctx: Context, cptBytes: int64, cptLines: int64,
  cptMulti: int64, cptWords: int64, filename: string=nil) =

  if ctx.optLines:
    printCounter(cptLines, WIDTH)

  if ctx.optWords:
    printCounter(cptWords, WIDTH)

  if ctx.optBytes:
    printCounter(cptBytes, WIDTH)

  if ctx.optMulti:
    printCounter(cptMulti, WIDTH)

  if filename != nil:
    echo " {}".fmt(filename)
  else:
    echo()

proc countWords(s: string): int =
  ## Count words when byte count is set (option -c)
  for w in s.splitWhitespace:
    inc result

proc countRuneWords(s: string): int =
  ## Count words when multibytes (unicode) is set (option -m)
  var isWord = false
  for r in s.runes:
    if r.isWhiteSpace():
      if isWord:
        isWord = false
    else:
      if not isWord:
        isWord = true
        inc result

proc processFile(ctx: Context, filename: string=nil) =
  ## Process each file. For each file, iterate through each line.
  ## A file named '-' it is treated as standard input. The arguments may
  ## include more than one '-' (standard input). See POSIX:
  ## http://pubs.opengroup.org/onlinepubs/9699919799/utilities/wc.html#tag_20_154_06
  var cptBytes = 0i64
  var cptLines = 0i64
  var cptMulti = 0i64
  var cptWords = 0i64
  var f: File

  try:

    # '-' is treated as stdin
    if filename == "-" or filename == nil:
      f = stdin
    else:
      f = open(filename)

    # Just need to count the bytes
    if f != stdin and
       ctx.optBytes and
       allIt([ctx.optLines, ctx.optMulti, ctx.optWords], not it):
      cptBytes = f.getFileSize()

    else:
      for ln in f.lineIter:
        # ln is a tuple containing the line and a boolean
        # the boolean is false when there is no eol, true otherwise
        #echo "[" & ln[0] & "]"
        if ctx.optBytes:
          cptBytes += ln[0].len
        if ctx.optLines:
          if ln[1]:
            # The line has an eol (\l). If no EOL, don't increment the counter.
            inc cptLines
        if ctx.optWords:
          if ctx.optMulti:
            cptWords += countRuneWords ln[0]
          else:
            cptWords += countWords ln[0]
        if ctx.optMulti:
          cptMulti += runeLen(ln[0])

    ctx.counts[cBytes] += cptBytes
    ctx.counts[cLines] += cptLines
    ctx.counts[cMulti] += cptMulti
    ctx.counts[cWords] += cptWords

    printCounters(ctx, cptBytes, cptLines, cptMulti, cptWords, filename)

  except IOError:
    let msg = getCurrentExceptionMsg()
    printError("$#: $#" % [filename, msg])

  finally:
    if f != nil and f != stdin:
      f.close()
    if f == stdin:
      # Reset stdin if list of files includes another one ('-')
      c_clearerr f

proc printTotal(ctx: Context) =
  printCounters(ctx, ctx.counts[cBytes], ctx.counts[cLines], ctx.counts[cMulti],
   ctx.counts[cWords], TOTAL)

proc doCommand(ctx: Context, inFilenames: seq[string] = nil) =
  var filenames: seq[string] = @[]
  if inFilenames != nil and inFilenames.len > 0:
    for pattern in inFilenames:
      var foundFile = false
      for filename in walkPattern(pattern):
        foundFile = true
        filenames.add filename
      if not foundFile:
        filenames.add pattern

  # if no file: read from stdin
  if filenames.len > 0:
    for filename in filenames:
      processFile(ctx, filename)
  else:
    processFile(ctx)

  if filenames.len > 1:
      printTotal(ctx)

proc initContext(optBytes:bool, optLines:bool,
  optMulti:bool, optWords:bool): Context =
    result = (
      optBytes: optBytes,
      optLines: optLines,
      optMulti: optMulti,
      optWords: optWords,
      counts: {cBytes: 0i64, cLines: 0i64, cMulti: 0i64, cWords: 0i64}.newTable
    )

proc ctrlC() {.noconv.} =
  styledEcho(fgYellow, "$#: manually interruped." % appName())
  quit QuitSuccess

proc main() =

  # Options
  var optBytes = false # -c
  var optLines = false # -l
  var optMulti = false # -m
  var optWords = false # -w

  # Arguments
  var inFilenames: seq[string] = @[]

  var errorOption = false
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      inFilenames.add(key)
    of cmdLongOption:
      case key
      of "help": printHelp(); return
      of "version": printVersion(); return
      else: unexpectedOption(key, true); errorOption = true
    of cmdShortOption:
      case key
      # last of -c -m takes precedence
      of "c": (optMulti, optBytes) = (false, true)
      of "l": optLines = true
      # last of -c -m takes precedence
      of "m": (optMulti, optBytes) = (true, false)
      of "w": optWords = true
      else: unexpectedOption key; errorOption = true
    of cmdEnd: assert(false)

  if errorOption:
    quit(QuitFailure)

  # Default action: -c, -l and -w options
  if allIt([optBytes, optLines, optMulti, optWords], not it):
    (optBytes, optLines, optWords) = (true, true, true)

  var ctx = initContext(optBytes, optLines, optMulti, optWords)

  setControlCHook(ctrlC)

  doCommand(ctx, inFilenames)

when isMainModule:
  main()