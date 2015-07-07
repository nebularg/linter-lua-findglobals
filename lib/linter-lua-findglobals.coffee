fs = require 'fs'
util = require 'util'
{BufferedProcess, Range} = require 'atom'
{XRegExp} = require 'xregexp'
stds = require './stds'

linterPath = atom.packages.resolvePackagePath 'linter'
Linter = require "#{linterPath}/lib/linter"
{log, warn} = require "#{linterPath}/lib/utils"

class LinterLuaFindGlobals extends Linter
  @syntax: 'source.lua'

  linterName: 'findglobals'

  whitelist: {}

  constructor: (@editor) ->
    super(@editor)
    @subscriptions.add atom.config.observe 'linter-lua-findglobals.luac', (luac) =>
      @cmd = [luac, '-p', '-l']

    @subscriptions.add atom.config.observe 'linter-lua-findglobals.whitelist', (files) =>
      return unless files?

      @whitelist = {}

      for file in files
        fs.readFile file, (err, data) =>
          return warn 'Unable to open file', file if err

          for name in data.toString().split('\n')
            name = name.trim()
            @whitelist[name] = true if name.length > 0

  lintFile: (filePath, callback) ->
    # build the command with arguments to lint the file
    {command, args} = @getCmdAndArgs(filePath)

    # options for BufferedProcess, same syntax with child_process.spawn
    options = {cwd: @cwd}

    stdGlobals = stds[atom.config.get 'linter-lua-findglobals.ignoreStandardGlobals']
    globals = {}
    messages = []
    exited = false
    funcScope = false

    # check for excluded globals in the source file
    source = @editor.getText()
    XRegExp.forEach source, /^\s*\-\-\s*GLOBALS:\s*(.*)$/gm, (match, i) ->
        XRegExp.forEach match[1...], /[\w_]+/, (match, j) -> # don't match GLOBALS from the first capture
          globals[match[0]] = true
    log 'GLOBALS', globals, @whitelist

    # set directives from the source file
    GETGLOBALFILE = atom.config.get 'linter-lua-findglobals.GETGLOBALFILE'
    result = /^\s*\-\-\s*GETGLOBALFILE\s+(ON|OFF)$/m.exec source
    if result?
      if result[1] == 'ON' then GETGLOBALFILE = true
      if result[1] == 'OFF' then GETGLOBALFILE = false

    GETGLOBALFUNC = atom.config.get 'linter-lua-findglobals.GETGLOBALFUNC'
    result = /^\s*\-\-\s*GETGLOBALFUNC\s+(ON|OFF)$/m.exec source
    if result?
      if result[1] == 'ON' then GETGLOBALFUNC = true
      if result[1] == 'OFF' then GETGLOBALFUNC = false

    SETGLOBALFILE = atom.config.get 'linter-lua-findglobals.SETGLOBALFILE'
    result = /^\s*\-\-\s*SETGLOBALFILE\s+(ON|OFF)$/m.exec source
    if result?
      if result[1] == 'ON' then SETGLOBALFILE = true
      if result[1] == 'OFF' then SETGLOBALFILE = false

    SETGLOBALFUNC = atom.config.get 'linter-lua-findglobals.SETGLOBALFUNC'
    result = /^\s*\-\-\s*SETGLOBALFUNC\s+(ON|OFF)$/m.exec source
    if result?
      if result[1] == 'ON' then SETGLOBALFUNC = true
      if result[1] == 'OFF' then SETGLOBALFUNC = false

    stdout = (output) =>
      # grep the bytecode output for GETGLOBAL and SETGLOBAL
      for line in output.split('\n')
          if /^main </.test line
            funcScope = false
          else if /^function </.test line
            funcScope = true
          else if (/SETGLOBAL/.test(line) and ((funcScope and SETGLOBALFUNC) or (not funcScope and SETGLOBALFILE))) or
                  (/GETGLOBAL/.test(line) and ((funcScope and GETGLOBALFUNC) or (not funcScope and GETGLOBALFILE)))
            result = /\[(\d+)\]\s+((GET|SET)GLOBAL).+; ([\w]+)/.exec line
            [_, lineNumber, command, type, name] = result if result?
            if name? and not globals[name] and not @whitelist[name] and not stdGlobals[name]
              lineNumber = +lineNumber - 1
              text = @editor.lineTextForBufferRow(lineNumber)
              colStart = text.search(name) or 0
              colEnd = if colStart == -1 then text.length else colStart + name.length
              level = if type is 'GET' then atom.config.get 'linter-lua-findglobals.levelGet' else atom.config.get 'linter-lua-findglobals.levelSet'

              message =
                line: lineNumber + 1
                level: level
                message: "#{command} #{name}"
                linter: @linterName
                range: new Range(
                  [lineNumber, colStart],
                  [lineNumber, colEnd]
                )
              messages.push message
              #console.log message

    stderr = (output) ->
      warn 'stderr', output

    exit = (code) =>
      exited = true
      callback messages

    log 'beforeSpawnProcess:', command, args, options
    process = new BufferedProcess({command, args, options, stdout, stderr, exit})
    process.onWillThrowError (err) =>
      if err? and err.error.code is 'ENOENT'
        warn "The linter binary '#{@linterName}' cannot be found."
        err.handle()

    # Kill the linter process if it takes too long
    if @executionTimeout > 0
      setTimeout =>
        return if exited
        process.kill()
        warn "command `#{command}` timed out after #{@executionTimeout} ms"
      , @executionTimeout

module.exports = LinterLuaFindGlobals
