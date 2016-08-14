# Description of the demo mudlib

This memorandum describes the demo mudlib (i.e. *lib_xxx* objects), which may be used as
a sample for designing you own world.

THIS IS A WORK IN PROGRESS

## Introduction

Lorem ipsum dolor sic amet...

### Pure traits

These objects are purely 'abstract' (i.e. they don't inherit from **lib_root**), and are
intended to be added to objects deriving from it, to extend their functionality).

##### lib_traits_describable

A trait for items than can be described

Traits: none

Verbs:

| Verb                        | 
| --------------------------- | 
| l\*ook/ex\*amine this       | 

Functions:

| Function                    | Description   |
| --------------------------- | ------------- |
| describe                    | Returns the object description if defined, or the object name. May be overloaded by derived objects. |

Properties: 

| Property                    | Description   |
| --------------------------- | ------------- |
| description : String        | Optional textual description for the object |

Triggers: none

##### lib_traits_gettable

A trait for items that can be taken or dropped.

Traits: none

Verbs:

| Verb                        | 
| --------------------------- | 
| get/take this               | 
| drop this                   | 
| keep this                   |

- Items marked for keeping cannot be dropped inadvertently.

Functions:

| Function                    | Description   |
| --------------------------- | ------------- |
| announceTakeItem            | Defines the message displayed in the room when the object is taken |
| announceDropItem            | Defines the message displayed in the room when the object is dropped |

Properties:

| Property                    | Description   |
| --------------------------- | ------------- |
| keepFlag : Boolean          | Optional flag marking the object as kept, when true. |

Triggers: none

**TODO** : Add onDropItem, onTakeItem events ?
**TODO** : canTake, canDrop ?
**FIX** : any/ambiguous/fail are poorly handled

##### lib_traits_closeable

A trait for items that can be opened/closed/locked/unlocked.

Traits: none

Verbs:

| Verb                         | 
| ---------------------------- | 
| open this                    | 
| close this                   | 
| unlock/open this with/using any |
| lock/close this with/using any |

Functions:

| Function                    | Description   |
| --------------------------- | ------------- |
| doOpen                      |               |
| doClose                     |               |
| doLock                      |               |
| doUnlock                    |               |
| addKeyId                    |               |
| rmKeyId                     |               |

Properties:

| Property                    | Description   |
| --------------------------- | ------------- |
| locked   : Boolean          | True if item is locked. Defaults to true |
| closed   : Boolean          | True if item is closed. Defaults to true |
| keySet   : Array.String     | Key identifiers (see **lib_key** below) for locking/unlocking the object. Default to [ "masterkey" ] |
| autolocking : Boolean       | Optional flag. If true, the object will lock itself when being closed |

- If you don't want the object to be lockable/unlockable, set the keySet to an empty array,
- The "masterkey" identifier stands for an all-purpose master key, so you may either remove it or rather just add specific key identifiers.

Triggers:

| Trigger                     | Description   |
| --------------------------- | ------------- |
| onOpen                      | Fired after object is opened |
| onClose                     | Fired after object is closed |
| onLock                      | Fired after object is locked |
| onUnlock                    | Fired after object is unlocked |

##### lib_traits_edible

A trait for items that can be eaten or drunk.

Traits: none

Verbs:

| Verb                         | 
| ---------------------------- | 
| eat/drink <this>             | 

Functions:

| Function                    | Description   |
| --------------------------- | ------------- |
| doUse                       |               |
| canUse                      |               |

Properties:

| Property                    | Description   |
| --------------------------- | ------------- |
| DRINK = 1, MEAL = 2         | Bit mask constants for type of food |
| foodType : Integer          | Current type (1) |
| destroyOnUse : Boolean      | True if the object should be destroyed after use. Defaults to false |

- To keep this as simple as possible, edibled object are either single use (when destroyOnUse is true) or inexhaustible (when false).
- Basically, the idea is that meal is usually for single use, and drink is inexhaustible, but the **lib_liquidcontainer** is probably what you'll rather use for single use drinks.

Triggers:

| Trigger                     | Description   |
| --------------------------- | ------------- |
| onUse                       | Fired after object is eaten or drunk |

### Root object

##### lib_root

A base parent trait for all other objects.

Traits: none

Verbs: none

Functions:

| Function                  | Description
| ------------------------- | -------------
| tell( msg : String )      | If the object is a player, sends a message to him/her

**TODO** add clone

Triggers: none

### Rooms and doors

##### lib_room

The base structure for rooms.

Traits: **lib_root**

Verbs:

| Verb                         | 
| ---------------------------- | 
| l\*ook                       |
| g\*o <any>                   |   
| n\*orth e\*ast s\*outh w\*est u\*p d\*own ne se nw sw northeast northwest southeast southwest |

Functions:

| Function                    | Description   |
| --------------------------- | ------------- |
| doEnter                     |               |
| doLeave                     |               |
| canEnter                    |               |
| canLeave                    |               |
| announceEnterRoom           |               |
| announceLeaveRoom           |               |
| describe                    |               |
| announce                    |               |
| addExit                     |               |

Properties:

| Property                    | Description   |
| --------------------------- | ------------- |
| exits : Object              | Object whose keys are the directions, and values are the target location |
| description : String        | Textual long description for the room ("An undescript room.") |

Triggers:

| Triggers                    | Description   |
| --------------------------- | ------------- |
| onEnter                     | Fired after the room is entered |
| onLeave                     | Fired when the room is being left |

##### lib_door

A door is a two-way traversable entity.

Traits: **lib_root**, **lib_describable**, **lib_closeable**

Verbs: none

Functions:

| Function                    | Description   |
| --------------------------- | ------------- |
| doEnter                     |               |
| canEnter                    |               |
| describe                    |               |
| announce                    |               |
| addExit                     |               |

Properties:

| Property                    | Description   |
| --------------------------- | ------------- |
| sides : Array[2]            | Up to two connected rooms |
| description : String        | Textual long description for the door ("A standard door.") |

Triggers:

| Triggers                    | Description   |
| --------------------------- | ------------- |
| onTraversal                 | Fired when the door is traversed.  |

- Technically, the player is still in the initial room when the trigger is fired.
- Example use: announce something to both sides of the door, when it is traversed

```
function onTraversal(player) {
  this.announce((sender, recipient) => {
    return "You hear a distant bell ring.";
  }, player)
}
```

### Items

##### lib_item

The base structure for items.

Traits: **lib_root**, **lib_describable**, **lib_gettable**

Verbs: none

Functions: none

Properties:

| Property                    | Description   |
| --------------------------- | ------------- |
| description : String        | Default textual description ("An undescript item.") |

Triggers: none

##### lib_key

A base object for designing key-like items, allowing to lock/unlock closeable objects.

Traits: **lib_item**

Verbs: none

Functions: none

Properties:

| Property                    | Description   |
| --------------------------- | ------------- |
| description : String        | Default textual description ("An undescript key.") |
| keyId : String              | Default key identifier for matching closeable objects ("masterkey") |

- The key identifier is set to "masterkey", which is also the initial setting for **lib_closeable**, so any derived object will by default be an all-purpose master key. It is up to you to change it, following you own identification pattern.

Triggers: none
    
##### lib_ediblecontainer

A base object for designing single use items containing edible things, such as a cup of tea, a plate of potatoes, etc. When used, they'd become an empty cup, an empty plate, etc.

Traits: **lib_item**, **lib_traits_edible**

Verbs: none

Functions: 

| Property                    | Description   |
| --------------------------- | ------------- |
| doUse                       | Set the exhausted flag, and resets aliases accordingly |
| canUse                      | Returns false if exhausted, true otherwise          |
| describe                    | Constructs a description from the object's own description, whether it's empty or not, and in the latter case the description of the content |
| setEdible                   | Convenience function for setting the name and description of the content, and resets all flags and aliases accordingly, i.e. refills the item |

Properties:

| Property                    | Description   |
| --------------------------- | ------------- |
| exhausted : String          | True when empty |
| containerObject : String    | Default container name ("bottle.") |
| containedEdible : String    | Default content name ("water") |
| edibleDescription : String  | Optional description for the content |

Triggers: none

### Living things

##### lib_player

The base structure for players.

Traits: **lib_root**

Verbs:

| Verb                         | 
| ---------------------------- |
| i*nventory                   | 
| say any                      |
| ch\*at any                   |   
| who                          |
| help                         |

Functions:

| Function                    | Description   |
| --------------------------- | ------------- |
| announceSay                 |               |
| setMode                     |               |
| nextMode                    |               |
| onTabKeyPress               |               |
| renderPrompt                |               |

Properties:

| Property                    | Description   |
| --------------------------- | ------------- |
| mode : WorldObject          | Current player mode |

Triggers: none
