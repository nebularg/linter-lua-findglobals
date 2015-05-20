module.exports =
  config:
    lua:
      type: 'string'
      default: 'lua'
      description: 'The executable path to lua.'
    luac:
      type: 'string'
      default: 'luac'
      description: 'The executable path to luac.'
    level:
      type: 'string'
      enum: ['info', 'warning', 'error']
      default: 'warning'
      description: 'The error level used for messages. (Note: info messages are hidden by default in Linter\'s settings)'

  activate: ->
    console.log 'activate linter-lua-findglobals'
