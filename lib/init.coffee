module.exports =
  config:
    luac:
      type: 'string'
      default: 'luac'
      description: 'The executable path to luac.'
    levelGet:
      type: 'string'
      enum: ['info', 'warning', 'error']
      default: 'warning'
      title: 'Error Level for GETGLOBAL Messages'
    levelSet:
      type: 'string'
      enum: ['info', 'warning', 'error']
      default: 'warning'
      title: 'Error Level for SETGLOBAL Messages'
    ignoreStandardGlobals:
      type: 'string'
      enum: ['none', 'lua51', 'lua52', 'lua53', 'luajit', 'min', 'max']
      default: 'none'
      description: '\'min\' is the intersection and \'max\' is the union of globals for the different versions.'
    whitelist:
      type: 'array'
      default: []
      description: 'Path to a text file with global names one per line to exclude from messages. (You may include multiple files separated with a comma)'
    SETGLOBALFILE:
      type: 'boolean'
      default: true
      title: 'SETGLOBALFILE'
      description: 'Enable/disable SETGLOBAL checks in the global scope.'
    SETGLOBALFUNC:
      type: 'boolean'
      default: true
      title: 'SETGLOBALFUNC'
      description: 'Enable/disable SETGLOBAL checks in functions.'
    GETGLOBALFILE:
      type: 'boolean'
      default: false
      title: 'GETGLOBALFILE'
      description: 'Enable/disable GETGLOBAL checks in the global scope.'
    GETGLOBALFUNC:
      type: 'boolean'
      default: true
      title: 'GETGLOBALFUNC'
      description: 'Enable/disable GETGLOBAL checks in functions.'

  activate: ->
    console.log 'activate linter-lua-findglobals'
