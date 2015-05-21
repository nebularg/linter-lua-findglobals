fs = require 'fs'
util = require 'util'
{BufferedProcess} = require 'atom'
{MessagePanelView} = require 'atom-message-panel'
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
    atom.config.observe 'linter-lua-findglobals.luac', =>
      luac = atom.config.get 'linter-lua-findglobals.luac'
      @cmd = [luac, '-p', '-l']

    atom.config.observe 'linter-lua-findglobals.whitelist', =>
      files = atom.config.get 'linter-lua-findglobals.whitelist'
      return unless files?

      @whitelist = {}

      if files.length > 0
        for file in files.split(',')
          file = file.trim()
          fs.readFile file, (err, data) =>
            if not err
              for name in data.toString().split('\n')
                name = name.trim()
                if name.length > 0
                  @whitelist[name] = true

            else if err.code is 'ENOENT'
              # Show a small notification at the bottom of the screen
              title = "#{@linterName}: Unable to open file \"#{file}\""
              title = title + " (#{err.path})" if file != err.path
              message = new MessagePanelView(title: title)
              message.attach()
              message.toggle() # Fold the panel

  destroy: ->
    super()
    atom.config.unobserve 'linter-lua-findglobals.luac'

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
          globals[match[0]] = true if j > 0 # don't match GLOBALS from the first capture (?!)
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
    process.onWillThrowError (err) =>
      return unless err?
      if err.error.code is 'ENOENT'
        ignored = atom.config.get('linter.ignoredLinterErrors')
        subtle = atom.config.get('linter.subtleLinterErrors')
        warningMessageTitle = "The linter binary '#{@linterName}' cannot be found."
        if @linterName in subtle
          # Show a small notification at the bottom of the screen
          message = new MessagePanelView(title: warningMessageTitle)
          message.attach()
          message.toggle() # Fold the panel
        else if @linterName not in ignored
          # Prompt user, ask if they want to fully or partially ignore warnings
          atom.confirm
            message: warningMessageTitle
            detailedMessage: 'Is it on your path? Please follow the installation
            guide for your linter. Would you like further notifications to be
            fully or partially suppressed? You can change this later in the
            linter package settings.'
            buttons:
              Fully: =>
                ignored.push @linterName
                atom.config.set('linter.ignoredLinterErrors', ignored)
              Partially: =>
                subtle.push @linterName
                atom.config.set('linter.subtleLinterErrors', subtle)
        else
          console.log warningMessageTitle
        err.handle()

    # Kill the linter process if it takes too long
    if @executionTimeout > 0
      setTimeout =>
        return if exited
        process.kill()
        warn "command `#{command}` timed out after #{@executionTimeout} ms"
      , @executionTimeout

module.exports = LinterLuaFindGlobals
