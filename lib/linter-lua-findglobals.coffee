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
    @subscriptions.add atom.config.observe 'linter-lua-findglobals.luac', (luac) =>
      @cmd = [luac, '-p', '-l']

    @subscriptions.add atom.config.observe 'linter-lua-findglobals.whitelist', (files) =>
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
        XRegExp.forEach match[1...], /[\w_]+/, (match, j) -> # don't match GLOBALS from the first capture
          globals[match[0]] = true
    log 'GLOBALS', globals, @whitelist

    stdout = (output) =>
      # grep the bytecode output for GETGLOBAL and SETGLOBAL
      XRegExp.forEach output, /\[(\d+)\]\s+((GET|SET)GLOBAL).+; ([\w]+)/, (match) =>
        log 'stdout', match
        [_, line, command, _, name] = match
        if not globals[name] and not @whitelist[name]
          line = +line
          colStart = @editor.lineTextForBufferRow(line - 1).search(name) + 1
          colEnd = colStart + name.length
          level = atom.config.get 'linter-lua-findglobals.level'
          #console.log util.format("%s:%d:%d:%d %s\t%s", @editor.getTitle(), line, colStart, colEnd, command, name)

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
