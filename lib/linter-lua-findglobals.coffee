fs = require 'fs'
util = require 'util'
{BufferedProcess} = require 'atom'
{XRegExp} = require 'xregexp'

log = (args...) ->
  console.log args... if atom.config.get 'linter.lintDebug'

warn = (args...) ->
  console.warn args... if atom.config.get 'linter.lintDebug'

linterPath = atom.packages.resolvePackagePath 'linter'
Linter = require "#{linterPath}/lib/linter"

class LinterLuaFindGlobals extends Linter
  @syntax: 'source.lua'

  linterName: 'lua-findglobals'

  whitelist: {}

  constructor: (@editor) ->
    super(@editor)
    atom.config.observe 'linter-lua-findglobals.luac', (luac) =>
      @cmd = [luac, '-p', '-l']

    atom.config.observe 'linter-lua-findglobals.whitelist', (files) =>
      return unless files?

      @whitelist = {}

      for file in files.split(',')
        file = file.trim()
        fs.readFile file, (err, data) =>
          return warn 'Unable to open file', file if err

          for name in data.toString().split('\n')
            name = name.trim()
            @whitelist[name] = true if name.length > 0

  destroy: ->
    super()
    atom.config.unobserve 'linter-lua-findglobals.luac'
    atom.config.unobserve 'linter-lua-findglobals.whitelist'

  lintFile: (filePath, callback) ->
    # build the command with arguments to lint the file
    {command, args} = @getCmdAndArgs(filePath)

    # options for BufferedProcess, same syntax with child_process.spawn
    options = {cwd: @cwd}

    globals = {}
    messages = []
    exited = false

    # check for excluded globals in the source file
    XRegExp.forEach @editor.getText(), /^\s*\-\-\s*GLOBALS:\s*(.*)$/gm, (match, i) ->
        XRegExp.forEach match, /[\w_]+/, (match, j) ->
          globals[match[0]] = true if j > 0 # don't match GLOBALS from the first capture
    log 'GLOBALS', globals, @whitelist

    stdout = (output) =>
      log 'stdout', output
      # grep the bytecode output for GETGLOBAL and SETGLOBAL
      XRegExp.forEach output, /\[(\d+)\]\s+((GET|SET)GLOBAL).+; ([\w]+)/, (match) =>
        [_, line, command, _, name] = match
        if not globals[name] and not @whitelist[name]
          line = +line
          colStart = @editor.lineTextForScreenRow(line - 1).search(name) + 1
          colEnd = colStart + name.length
          level = atom.config.get 'linter-lua-findglobals.level'
          #console.log util.format("[%d] %d-%d %s\t%s", line, colStart, colEnd, command, name)

          messages.push {
            line: line,
            level: level,
            message: "#{command} #{name}",
            linter: @linterName,
            range: @computeRange {
              line: line,
              col: 0,
              colStart: colStart,
              colEnd: colEnd
            }
          }

    stderr = (output) ->
      warn 'stderr', output

    exit = (code) =>
      exited = true
      callback messages

    log 'beforeSpawnProcess:', command, args, options
    process = new BufferedProcess({command, args, options, stdout, stderr, exit})

    # Kill the linter process if it takes too long
    if @executionTimeout > 0
      setTimeout =>
        return if exited
        process.kill()
        warn "command `#{command}` timed out after #{@executionTimeout} ms"
      , @executionTimeout

module.exports = LinterLuaFindGlobals
