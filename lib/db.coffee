fs = require 'fs'
util = require 'util'
_ = require 'underscore'

c = require('./color').color

connections = require './connection_manager'
mooUtil = require './util'
context = require './context'

RoomJsObject = require('./object').RoomJsObject
RoomJsPlayer = require('./player').RoomJsPlayer

# some constants
NO_MATCH = 0
EXACT_MATCH = 1
PARTIAL_MATCH = 2

# A RoomJsDb is a collection of RoomJsObjects
exports.RoomJsDb = class
  # @objects: Array[RoomJsObject]
  # @players: Array[RoomJsPlayer]

  objects: {}
  players: []

  constructor: (@filename) ->
    startTime = mooUtil.tstart()
    for id, dbObject of JSON.parse fs.readFileSync @filename
      if dbObject.player
        newMooObj = new RoomJsPlayer dbObject, @
      else
        newMooObj = new RoomJsObject dbObject, @
      @objects[parseInt(dbObject.id)] = newMooObj
      if newMooObj.player
        @players.push newMooObj
    @specials()
    util.log "#{@filename} loaded in #{mooUtil.tend startTime}"

    @saveInterval = setInterval @save, 5*60*1000

    # call server started verb
    verb = @sys.findVerbByName 'server_started'
    if verb?
      context.runVerb @, @nothing, verb.code, @sys

  exit: ->
    for player in @players
      socket = connections.socketFor player
      if socket?
        socket.emit 'output', c 'Server shutting down.', 'red'
        socket.disconnect()
    @saveSync()

  blankObject: (id, name) ->
    x =
      id: id
      parent_id: null
      name: name
      aliases: []
      location_id: null
      contents_ids: []
      player: false
      programmer: false
      properties: []
      verbs: []
    new RoomJsObject x, @

  specials: ->
    @objects[-1] = @blankObject -1, 'nothing'
    @objects[-2] = @blankObject -2, 'ambiguous_match'
    @objects[-3] = @blankObject -3, 'failed_match'
    @nothing = @objects[-1]
    @ambiguous_match = @objects[-2]
    @failed_match = @objects[-3]
    @sys = @objects[0]

    @nothing.send = (msg) ->
      console.log msg

  save: =>
    startTime = mooUtil.tstart()
    fs.writeFile '_' + @filename, @serialize(), (err) =>
      throw err if err
      fs.rename '_' + @filename, @filename, (err) =>
        throw err if err
        util.log "#{@filename} saved in #{mooUtil.tend startTime}"

  saveSync: ->
    startTime = mooUtil.tstart()
    fs.writeFileSync '_' + @filename, @serialize()
    fs.renameSync '_' + @filename, @filename
    util.log "#{@filename} saved in #{mooUtil.tend startTime}"

  serialize: ->
    # don't safe the special objects
    objects = _.clone(@objects)
    delete objects[-1]
    delete objects[-2]
    delete objects[-3]
    JSON.stringify objects

  findById: (id) ->
    if @objects[id]? then @objects[id] else null

  findByNum: (numStr) ->
    @findById parseInt numStr.match(/^#([0-9]+)$/)?[1]

  # find the objects matched by the command
  matchObjects: (player, command) ->
    dobj: if command.dobjstr? then @findObject command.dobjstr, player else @nothing
    iobj: if command.iobjstr? then @findObject command.iobjstr, player else @nothing

  # search string can be:
  # 'me', 'here'
  # or an object name or alias, in which case we search "nearby"
  findObject: (search, player) ->
    return player if search == 'me'
    return player.location() if search == 'here'
    #return @findByNum search if search.match /^#[0-9]+$/
    @findNearby search, player

  # find objects "nearby"
  # i.e. objects the player is holding, or objects in the room
  findNearby: (search, player) ->
    return @failed_match if search == ''

    searchItems = player.contents().concat player.location().contents().filter (o) -> o != player
    matches = searchItems.map (item) -> [item.matches(search), item]
    exactMatches = matches.filter (match) -> match[0] == EXACT_MATCH
    partialMatches = matches.filter (match) -> match[0] == PARTIAL_MATCH

    if exactMatches.length == 1
      return exactMatches[0][1]
    else if exactMatches.length > 1
      return @ambiguous_match

    if partialMatches.length == 1
      return partialMatches[0][1]
    else if partialMatches.length > 1
      return @ambiguous_match

    return @failed_match

  # return a list of matched objects for moo-side use
  mooMatch: (search, player) =>
    return [] if search == ''

    searchItems = player.contents().concat player.location().contents().filter (o) -> o != player
    matches = searchItems.map (item) -> [item.matches(search), item]
    exactMatches = matches.filter (match) -> match[0] == EXACT_MATCH
    partialMatches = matches.filter (match) -> match[0] == PARTIAL_MATCH

    if exactMatches.length == 1
      return [exactMatches[0][1]]
    else if exactMatches.length > 1
      return exactMatches.map (match) -> match[1]

    if partialMatches.length == 1
      return [partialMatches[0][1]]
    else if partialMatches.length > 1
      return partialMatches.map (match) -> match[1]

    return []

  matchVerb: (player, command, objects) ->
    if (verb = player.findVerb command, objects)
      self = player
    else if (verb = player.location()?.findVerb command, objects)
      self = player.location()
    else if (verb = objects.dobj?.findVerb command, objects)
      self = objects.dobj
    else if (verb = objects.iobj?.findVerb command, objects)
      self = objects.iobj
    if verb and not verb.hidden
      verb: verb
      self: self
    else
      null

  objectsAsArray: ->
    for id,object of @objects
      object

  globalAliases: ->
    @sys.properties.filter((prop) -> prop.value._mooObject?).reduce(((map, prop) ->
      map[prop.value._mooObject] = '$' + prop.key
      map
    ), {})

  list: ->
    aliases = @globalAliases()
    for id,object of @objects
      x =
        id: object.id
        name: object.name
      if aliases[id]?
        x.alias = aliases[id]
      x

  search: (search) ->
    regex = new RegExp "#{search}", 'i'
    @list().filter (object) ->
      !!object.name.match regex

  inheritance_tree: (root_id) ->
    aliases = @globalAliases()

    children = (o) =>
      child_os = @objectsAsArray().filter (other_o) ->
        other_o.parent_id == o.id
      child_os.map show

    show = (o) ->
      x =
        id: o.id
        name: o.name
      if aliases[o.id]?
        x.alias = aliases[o.id]
      x.children = children o
      x

    if root_id?
      root = @findById root_id
      if root?
        top = [root]
      else
        throw new Error "Invalid root object"
    else
      top = @objectsAsArray().filter (o) ->
        o? and o.parent_id == null
    top.map show

  location_tree: (root_id) ->
    aliases = @globalAliases()

    contents = (o) =>
      o.contents().map show

    show = (o) ->
      x =
        id: o.id
        name: o.name
      if aliases[o.id]?
        x.alias = aliases[o.id]
      x.contents = contents o
      x

    if root_id?
      root = @findById root_id
      if root?
        top = [root]
      else
        throw new Error "Invalid root object"
    else
      top = @objectsAsArray().filter (o) ->
        o? and o.location_id == null
    top.map show

  usernameTaken: (username) ->
    !!(@players.filter (player) -> player.username == username).length

  playerNameTaken: (name) ->
    !!(@players.filter (player) -> player.name == name).length

  createNewPlayer: (name, username, password, programmer = false) ->
    nextId = @nextId()

    object =
      id: nextId
      parent_id: null
      name: name
      aliases: []
      location_id: null
      contents_ids: []
      username: username
      password: password
      player: true
      programmer: programmer
      properties: []
      verbs: []

    newPlayer = new RoomJsPlayer object, @

    @objects[nextId] = newPlayer
    @players.push newPlayer

    newPlayer

  # create a clone of this object with copies of all it's properties and verbs
  clone: (object, newName, newAliases) ->
    if not (newName? and newName.toString?)
      throw new Error "Invalid name for new object"
    for alias in newAliases
      if not (alias? and alias.toString?)
        throw new Error "Invalid alias '#{alias}'"
    nextId = @nextId()
    rawObject = JSON.parse JSON.stringify object
    rawObject.id = nextId
    rawObject.parent_id = object.parent_id
    rawObject.name = newName
    rawObject.aliases = newAliases
    newObject = new RoomJsObject rawObject, @
    newObject.moveTo object.location()
    @objects[nextId] = newObject

  # Create a child of object
  # this child will inherit any of it's parent's properties and verbs
  createChild: (object, newName, newAliases) ->
    if not (newName? and newName.toString?)
      throw new Error "Invalid name for new object"
    for alias in newAliases
      if not (alias? and alias.toString?)
        throw new Error "Invalid alias '#{alias}'"
    nextId = @nextId()
    rawObject = JSON.parse JSON.stringify object
    rawObject.properties = []
    rawObject.verbs = []
    rawObject.id = nextId
    rawObject.parent_id = object.id
    rawObject.name = newName
    rawObject.aliases = newAliases
    newObject = new RoomJsObject rawObject, @
    newObject.moveTo object.location()
    @objects[nextId] = newObject

  rm: (id) ->
    if id > -1 and @findById(id)?
      if @objects[id].player
        @players = @players.filter (p) -> p.id != id
      delete @objects[id]
      true
    else
      false

  # terrible way to get the next available id in the DB
  nextId: ->
    # the sorted keys of the objects hash not including the 3 special objects (-1, -2 and -3)
    sortedKeys = (Object.keys @objects).sort((a,b)->a-b)[3..]
    nextId = 0
    for i in [0..sortedKeys.length+1]
      if !@objects[i]
        break
      nextId++
    nextId

  toString: ->
    "[RoomJsDb]"