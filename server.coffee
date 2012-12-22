##############
# Web server #
##############

express = require 'express'
http = require 'http'
io = require 'socket.io'
less = require 'less-middleware'
coffeescript = require 'coffee-script'
coffeescript_middleware = require 'connect-coffee-script'
require './color'

xp = express()

xp.configure ->
  xp.set 'port', 8888
  xp.set 'views', __dirname + '/views'
  xp.set 'view engine', 'jade'
  xp.use express.favicon()
  xp.use less
    src: __dirname + '/public_src'
    dest: __dirname + '/public'
  xp.use coffeescript_middleware
    src: __dirname + '/public_src'
    dest: __dirname + '/public'
    bare: true
  xp.use express.static __dirname + '/public'

xp.get '/', (req, res) ->
  res.render 'index'

xp.get '/colors', (req, res) ->
  res.render 'color_test'

http_server = http.createServer(xp).listen xp.get('port'), ->
  console.log "jsmoo http server listening on port " + xp.get 'port'

ws_server = io.listen(http_server)

ws_server.sockets.on 'connection', (socket) ->
  socket.emit 'output', {msg: "Welcome to #{"jsmoo".blue.bold}!"}
  socket.emit 'output', {msg: "Type #{"help".magenta.bold} for a list of available commands."}

  socket.on 'disconnect', ->
    # TODO (or not?  we don't care if an anonymous socket leaves...)

  socket.on 'input', (data) ->
    str = data.msg
    console.log "received: #{str}"
    switch str
      when "help"
        msg = """
        \nAvailable commands:
        * #{"login".magenta.bold}  - login to an existing account
        * #{"create".magenta.bold} - create a new account
        * #{"delete".magenta.bold} - delete an existing account
        * #{"help".magenta.bold}   - show this message
        """
        socket.emit 'output', {msg: msg}
      when "login"
        socket.emit 'output', {msg: "\n"+"not yet implemented".red.inverse.bold}
      when "create"
        socket.emit 'output', {msg: "\n"+"not yet implemented".red.inverse.bold}
      when "delete"
        socket.emit 'output', {msg: "\n"+"not yet implemented".red.inverse.bold}
      else
        socket.emit 'output', {msg: "\n"+"unknown command".grey}
