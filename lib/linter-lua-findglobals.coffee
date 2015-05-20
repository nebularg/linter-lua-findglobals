fs = require 'fs'
util = require 'util'
{Range, Point, BufferedProcess} = require 'atom'
XRegExp = null

packagePath = atom.packages.resolvePackagePath 'linter-lua-findglobals'

linterPath = atom.packages.resolvePackagePath 'linter'
Linter = require "#{linterPath}/lib/linter"

class LinterLuaFindGlobals extends Linter
  @syntax: 'source.lua'

  linterName: 'lua-findglobals'

  errorStream: 'stdout'

  defaultLevel: 'warning'

  constructor: (@editor) ->
    super(@editor)
    atom.config.observe 'linter-lua-findglobals.lua', => @updateCommand()
    atom.config.observe 'linter-lua-findglobals.luac', => @updateCommand()
    atom.config.observe 'linter-lua-findglobals.level', => @updateOptions()

  updateOptions: ->
    @defaultLevel = atom.config.get 'linter-lua-findglobals.level'

  updateCommand: ->
    luac = atom.config.get 'linter-lua-findglobals.luac'
    @cmd = [luac, '-p', '-l']

  lintFile: (filePath, callback) ->
    #console.log 'lintFile', @editor
    # build the command with arguments to lint the file
    {command, args} = @getCmdAndArgs(filePath)

    # options for BufferedProcess, same syntax with child_process.spawn
    options = {cwd: @cwd}

    GLOBALS = {}
    messages = []
    exited = false

    XRegExp ?= require('xregexp').XRegExp

    # check for excluded globals in the source file
    XRegExp.forEach @editor.getText(), /^\s*\-\-\s*GLOBALS:\s*(.*)$/gm, (match, i) ->
        XRegExp.forEach match, /[\w_]+/, (match, j) ->
          GLOBALS[match[0]] = true if j > 0 # don't match GLOBALS from the first capture (?!)
    #console.log 'GLOBALS', GLOBALS

    stdout = (data) =>
      # grep the bytecode output for GETGLOBAL and SETGLOBAL
      XRegExp.forEach data, /\[(\d+)\]\s+((GET|SET)GLOBAL).+; ([\w]+)/, (match) =>
        [ _, line, command, _, name ] = match
        if not GLOBALS[name]
          colStart = @editor.lineTextForScreenRow(+line - 1).search(name) + 1
          colEnd = colStart + name.length
          #console.log util.format("[%d] %d-%d %s\t%s", line, colStart, colEnd, command, name)

          messages.push {
            line: line,
            col: 0,
            level: @defaultLevel,
            message: "#{command} #{name}",
            linter: @linterName,
            range: @computeRange {
              line: line,
              col: 0,
              colStart: colStart,
              colEnd: colEnd
            }
          }

    exit = (code) =>
      exited = true
      callback messages

    console.log 'findglobals', {command, args, options}
    process = new BufferedProcess({command, args, options, stdout, stderr: null, exit})
    process.onWillThrowError (err) =>
      return unless err?
      if err.error.code is 'ENOENT'
        console.log "The linter binary '#{@linterName}' cannot be found."
        err.handle()

    # Kill the linter process if it takes too long
    if @executionTimeout > 0
      setTimeout =>
        return if exited
        process.kill()
        warn "command `#{command}` timed out after #{@executionTimeout} ms"
      , @executionTimeout

  destroy: ->
    super()
    atom.config.unobserve 'linter-lua-findglobals.lua'
    atom.config.unobserve 'linter-lua-findglobals.luac'
    atom.config.unobserve 'linter-lua-findglobals.level'

module.exports = LinterLuaFindGlobals
