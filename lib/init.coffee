module.exports =
  config:
    luac:
      type: 'string'
      default: 'luac'
      description: 'The executable path to luac.'
    level:
      type: 'string'
      enum: ['info', 'warning', 'error']
      default: 'warning'
      description: 'The error level used for messages. (Note: info messages are hidden by default in Linter\'s settings)'
    whitelist:
      type: 'array'
      default: []
      description: 'Path to a text file with global names one per line to exclude from messages. (You may include multiple files separated with a comma)'
    SETGLOBALFILE:
      type: 'boolean'
      default: true
      description: 'Enable/disable SETGLOBAL checks in the global scope.'
    SETGLOBALFUNC:
      type: 'boolean'
      default: true
      description: 'Enable/disable SETGLOBAL checks in functions.'
    GETGLOBALFILE:
      type: 'boolean'
      default: false
      description: 'Enable/disable GETGLOBAL checks in the global scope.'
    GETGLOBALFUNC:
      type: 'boolean'
      default: true
      description: 'Enable/disable GETGLOBAL checks in functions.'

  activate: ->
    console.log 'activate linter-lua-findglobals'
