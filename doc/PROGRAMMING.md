# Building and programming your own RoomJS MUD/MOO world

This guide is intended for "builders", i.e. players with developer privileges in the game.

## Introduction

Once you have been given developer privileges (or by default, on the demo), you can use the **eval** command to prefix code instructions, or preferably cycle to the EVAL mode.

> For the reminder, you can cycle between different modes by hitting TAB. 
> Modes effectively just prefix whatever you type with another word. 
 
You can then use any JavaScript (ES6) construct to start creating new rooms and objects. This document therefore assumes the reader has pre-existing JavaScript knowledge. You will need to learn but a few basic RoomJS-specific concepts only:

- Toplevel functions: there are a few convenience global functions, such as **all()** and **nextId()**, etc. They are seldom used in actual code, but are provided as utilities for you to invoke on the command line.
- World objects:
  - Each object in the world has a unique identifier, which also corresponds to its name in the global scope.
    - You may reference an object by its identifier: `$('lib_room')`
    - Or rather, directy by its global variable:  `lib_room`
    - Identifiers are internally mapped to a file path by the DB, with the underscore character corresponding to the path separator (e.g. "lib_room" will be mapped to "lib/room"). This allows  organizing the objects logically -- You can create objects at any level, but it is a **good practice** to enquire your game administrator regarding the recommended naming scheme. Please also refer to the [Customization guide](CUSTOMIZING.md)
  - Objects can include, as usual, properties and functions, but they can also have verbs.
    - To add a new function: `obj.foo = function foo()` {} 
    - To add a new verb: `obj.bar = Verb("bar")`
    - In the web client, to edit verbs and functions, use **Ctrl-p** (or **Cmd-p**) to open the fuzzy-search. Search for a function or verb by name and hit enter to start editing.
- Verbs: these are special functions invoked when a corresponding command from the player has succesfully been parsed.
- Traits: the object-oriented programming in RoomJS relies on traits. Any world object can be used as a trait in other objects, and can have several traits. This is how an object can be used to extend the functionality of another object.

For more details, see also the [Reference guide](#reference-guide) further below.

## Example

But for now, let's create our first object: a (very) basic lantern!
First, switch to EVAL mode, so that you do not have to prefix every JavaScript command.

- Create a new object. In the demo mudlib, **lib_item** is a gettable and describable object. So we will start from it (i.e. it will be the base trait for our object)
```
lib_item.new('tests_lantern');
```
- By default, its short name is the same as its identifier, and it doesn't have a long description. It doesn't have aliases either. This is not very convenient, so let's add all these things:
```
tests_lantern.name = "lantern";
tests_lantern.addAlias("lamp");
tests_lantern.description = "a portable lamp in a case, protected from the wind and rain";
```
- Since it is intended for being lit, let's add a boolean property to keep track of that state:
```
tests_lantern.lighted = false; 
```
- This is a step-by-step example, but actually note that we could rather have added most of the properties directly at creation, specified as options:
```
lib_item.new('tests_lantern', { name: "lantern", lighted: false });
```

- Anyhow, let's now declare the available command verbs:
```
tests_lantern.light = Verb("light", "this", "none", "none");
tests_lantern.extinguish = Verb("extinguish", "this", "none", "none");
```
- Hit Ctrl-p and look for our newly created "light" verb. In the editor, copy the following function body into the default template (i.e. keep the surrounding function definition!)
```
  if (!this.lighted) {
    this.doLight(player);
  } else {
    player.tell(`The ${this.name} is already lit.`);
  }
```
- Save with Ctrl-s, and then proceed similarly for the "extinguish" verb:
```
  if (this.lighted) {
    this.doExtinguish(player);
  } else {
    player.tell(`The ${this.name} is not lit.`);
  }
```
- Close the editing tabs and return to the MUD tab. Here, for the sake of illustration, we decided to use two additional functions, that will be responsible for changing the state flag and announce something to other people in the room. So let's first create them:
```
tests_lantern.doLight = function(player) {};
tests_lantern.doExtinguish = function(player) {};
```
- And again, hit Ctrl-p and look for these functions. Insert the following content in the body for the doLight method, and save with Ctrl-s:
```
  function announce(sender, recipient, object) {
    if (sender === recipient) {
      return `You light the ${object.name}.`;
    }
    return `${sender.name} lights a ${object.name}.`;
  }
  
  if (player.location) {
    player.location.announce(announce, player, this);
  }
  this.lighted = true;
```
- And likewise for doExtinguish...
```
  function announce(sender, recipient, object) {
    if (sender === recipient) {
      return `You extinguish the ${object.name}.`;
    }
    return `${sender.name} extinguishes a ${object.name}.`;
  }
  
  if (player.location) {
    player.location.announce(announce, player, this);
  }
  this.lighted = false;
```
- Go back to the MUD tab. We will want to test our new object, so let's bring it to our current room (and notice how the *this* object conveniently here points to you, the player/builder):
```
tests_lantern.location = this.location
```

- Leave the EVAL mode, and play:
```
look lamp
extinguish lamp
light lamp
light lamp
extinguish lamp
```

Yeah, there you go. Now, the description should probably indicate whether our little lantern is lit or not. That's basic programming, so it's up to you!

## Reference guide

### Toplevel global functions

##### all() ⇒ Array.WorldObject
Returns a list of all existing world objects.

##### nextId( String ) ⇒ String
Returns a new unique identifier from the text provided. Very useful when you create objects, and want an identifier following the same naming scheme, and as long as no one else takes that identifier in the meantime -- So usually, this is used directly in the object creation call.

##### players() ⇒ Array.WorldObject
Returns a list of all existing player world objects (i.e. player characters).

##### color.*( String ) ⇒ String
Colorizes a string.
```
var boldBlueText = color.bold.blue("Some text");
```

##### $( String ) ⇒ WorldObject|undefined
Returns a world object by its identifier, if it exits.

##### Verb( command, dobj?, prep?, iobj? ) ⇒ Command
Creates a command verb.

| Parameter | Type      | Comment  | 
| --------- | --------- | ------------ |
| command   | String    | Command name(s) |
| dobj      | String?   | Direct object |
| prep      | String?   | Preposition   |
| iobj      | String?   | Indirect object |

- The command can include several patterns separated by a space, that will be recognized alike. Each pattern can include a \* sign for defining shortcuts. E.g., "l\*ook ex\*amine" will match "look", "l", "examine" and "ex".
- Possible values for optional direct/indirect objects are "this", "any", "none" (default).
- Several prepositions may be provided, separated with a /.
- Recognized propositions: "with", "using", "at", "to", "in front of", "in", "inside", "into", "on top of", "on", "onto", "upon", "out of", "from inside", "from", "over", "through", "under", "underneath", "beneath", "behind", "beside", "for", "about", "is", "as", "off of", "off".

Example:
```
Verb("put", "any", "in/into", "this");
```

Verbs then have the following signature:
```
function({ player, dobj, iobj, verbstr, argstr, dobjstr, prepstr, iobjstr })
```

When the function is invoked:
- The *this* variable refers to the world object implementing the command,
- *player* is the player world object who triggered the command,
- *dobj* and *iobj* are the direct and indirect object of the command, that is either a world object (if found) or one of the core objects **fail**, **nothing** and **ambiguous**.
- *verbstr, argstr, dobjstr, prepstr, iobjstr* are the parsed strings, see **parse()** just below.

##### parse( String ) ⇒ Command
Invokes the command parser on a string. Explanation by example is easier:
```
parse("put trash in can");
⇒ { verb: 'put', dobjstr: 'trash', prepstr: 'in', iobjstr: 'can', argstr: 'trash in can' }
}
```

This may be used to check how a command will be split and passed to a Verb function.

### World objects

#### Base properties
All world objects have at least the following properties:

| Property  | Type                | Comment  |
| --------- | ------------------- | ------------ |
| player    | Boolean             | true if object is a player (read-only) |
| online    | Boolean             | true when connected player (read-only) |
| id        | String              | unique identifier (read-only) |
| name      | String              | name |
| aliases   | Array.String        | list of aliases |
| traits    | Array.WorldObject   | list of applicable traits |
| location  | WorldObject\|null   | location |
| contents  | Array.WorldObject   | Objects can therefore all be containers |

For the record:
- The *player* property actually checks whether the object has an *userId* property (which can't be added manually),
- The *online* is a getter querying the connection controller,
- The *id* property is internally mapped to a file path by the DB. 

Moreover, for there are a few optional properties used by the game engine:

| Property  | Type                | Comment  |
| --------- | ------------------- | ------------ |
| userId    | String              | (On a player.) User login name |
| extraMatchObjects | Array.WorldObject\|Function | (On a location.) See look-up functions below. For advanced usage |
| verbMissing | Verb              | (On a location.) For advanced usage |

#### Base methods
As a programmer, these are the methods you will most likely use very often.

##### new(String, Object?) ⇒ WorldObject
Creates a new world object, deriving from its parent (i.e. having it in its traits array).

| Parameter  | Type                | Comment  |
| ---------- | ------------------- | ------------ |
| id         | String              | unique identifier |
| props      | Object              | Optional properties to be copied into the object |

Example:
```
lib_chest.new("items_chest2", { name: "large chest", opened: false, locked: false });
```

Note: The identifier is 'sanitized', i.e. non-authorized characters are removed or replaced.

##### destroy() ⇒ Boolean
Removes an object from the world and its database. Currently returns true.

##### addAlias( ...String ) ⇒ Integer
Add alias strings to the object and returns the number of aliases.

> Warning: it doesn't prevent from adding an existing alias. Maybe it should, there's
> no real point having the same alias declared more than once.

##### rmAlias( ...String ) ⇒ Integer
Remove alias strings from the object (any duplicates will be removed), and returns the number of aliases.

##### addTrait( ...WorldObject ) ⇒ Integer
Add traits to the object and returns the number of traits. Traits are what makes the object inherit properties and methods.

> Warning: it doesn't prevent from adding an already existing trait. Maybe it should, 
> otherwise the object gets broken, with a 'duplicate parent'.

##### rmTrait( ...String ) ⇒ Integer
Remove traits from the object and returns the number of traits.

> Warning: removing an object used as trait in other objects leads to very bad things. 
> Maybe a more graceful protection may be implemented, but anyhow it is probably a bad
> idea to remove a trait object, as the child objects may likely be broken anyhow.

#### Look-up methods
These are methods you may need when implementing complex verbs, where you may want to
check if an item can be found in a container, a location, etc.

##### findNearby( String ) ⇒ WorldObject
Looks if a string can be matched to an object in the environment, that is:
- the object's contents,
- its location's contents,
- the location's extraMatchObjects, if defined.

Returns:
- the core object **fail** when there is no match,
- the core object **ambiguous** if there are more than one match,
- otherwise, the matched object.

##### findObject( String ) ⇒ WorldObject
Looks if a string can be matched to an object in the environment. This is a convenience function over findNearby(), accepting the strings "me", "myself" and "here" to be matched.

Returns: 
- the object itself (= *this*) if the string is "me" or "myself",
- the location (= *this.location*) if the string is "here",
- otherwise, **fail**, **ambiguous** or a matched object.
  
##### findInside( String ) ⇒ WorldObject
Looks inside the object's contents if a string can be matched to an object.

Returns:
- the core object **fail** when there is no match,
- the core object **ambiguous** if there are more than one match,
- otherwise, the matched object.

#### Verb related methods
For advanced usage. 

##### matchObjects( String ) ⇒ Object
##### matchVerb( String, Object ) ⇒ Object

Check the **items_builderstaff** item in the demo for a possible use case. 

#### Other methods
They exist in the execution context, but are propably of lower interest.

##### send( String\|Object ) ⇒ Boolean
Sends a message to the client.

This is normally not intended to be used directly (e.g. check the **tell()** method, defined by the **lib_root** object inherited by allmost all objects in the demo mudlib).

Returns true upon success, false upon failure (no controller, e.g. not a player, or player not connected). 

Note: Sending an object also works, assuming it is transferable. 

##### linearize() ⇒ Array.WorldObject
Returns the trait inheritance hierarchy. It could be useful to check if an object has a given trait via inheritance, see instanceOf() below for that purpose.

##### instanceOf( WorldObject ) ⇒ Boolean
Checks if the object is an instance of another object, i.e. if the former has the latter in its trait inheritance hierarchy.

Basically, it just linearizes the object, and checks whether the other object is in the returned list of traits. (Obviously, since the object-oriented programming in RoomJS is trait-based, the usual JavaScript `instanceof` operator, which operates on object's prototypes, would not work as intended.)

##### setPrompt( String ) ⇒ Boolean
Notifies the user to change his/her prompt. This is used by the mode system, when cycling between the modes (normal, say, chat, programming).

Returns true upon success, false upon failure (no controller, e.g. not a player, or player not connected).

##### toString() ⇒ String
Returns [object identifier]

##### keys() ⇒ Array.String
Returns an array of a given object's own enumerable properties.

##### values() ⇒ Array.Object
Returns an array of a given object's own enumerable property values.

#### Other methods (internal/undocumented)

This section is provided for reference only. You are normally not supposed to need these methods -- but these are therefore reserved property names.

##### matches( String ) ⇒ 0..2
##### findMatch( Array, Array ) ⇒ WorldObject
##### findVerb( Object, Object, WorldObject ) ⇒ Verb
