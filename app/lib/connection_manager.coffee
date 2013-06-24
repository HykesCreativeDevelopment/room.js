# This module keeps track of two maps:
# sockets -> players
# players -> sockets

util = require 'util'

sockets = {}
players = {}
lastActivity = {}

add = (player, socket) ->
  throw new Error 'invalid player added to connection manager' if not player? or not player.id?
  throw new Error 'invalid socket added to connection manager' if not socket? or not socket.id?
  sockets[player.id] = socket
  players[socket.id] = player
  util.log "#{player.toString()} connected" if process.env.NODE_ENV != 'test'

remove = (socket) ->
  throw new Error 'invalid socket removed from connection manager' if not socket? or not socket.id?
  player = playerFor socket
  delete sockets[player.id] if player?
  delete players[socket.id] if socket?
  util.log "#{player.toString()} disconnected" if process.env.NODE_ENV != 'test' and player? and player.username?

socketFor = (player) ->
  throw new Error 'invalid player passed to socketFor' if not player? or not player.id?
  sockets[player.id] || null

playerFor = (socket) ->
  throw new Error 'invalid socket passed to playerFor' if not socket? or not socket.id?
  players[socket.id] || null

activity = (player) ->
  throw new Error 'invalid player passed to activity' if not player? or not player.id?
  lastActivity[player.id] = new Date()

idleTimeFor = (player) ->
  throw new Error 'invalid player passed to idleTimeFor' if not player? or not player.id?
  return null if not lastActivity[player.id]?
  now = new Date()
  parseInt (now - lastActivity[player.id]) / 1000

exports.add = add
exports.remove = remove
exports.socketFor = socketFor
exports.playerFor = playerFor
exports.activity = activity
exports.idleTimeFor = idleTimeFor