const EventEmitter = require('events');
const util = require('util');
const bunyan = require('bunyan');
const FsDb = require('./fs-db');

const VERB_DESCRIPTOR = /^\s*\/\/\s*verb\s*:\s*(.*?)\s*;\s*(.*?)\s*;\s*(.*?)\s*;\s*(.*?)\s*$/;

function* entries(obj) {
  for (const key of Object.keys(obj)) {
    yield [key, obj[key]];
  }
}

class MooDB {
  constructor(directory, logger) {
    EventEmitter.call(this);

    this.logger = logger;
    this.fsdb = new FsDb(directory, logger);
    this.db = new Map();
    this.load();
    this.setupListeners();
  }

  setupListeners() {
    this.fsdb.on('added', this.onFileAddedOrChanged.bind(this));
    this.fsdb.on('changed', this.onFileAddedOrChanged.bind(this));
    this.fsdb.on('removed', this.onFileRemoved.bind(this));
  }

  load() {
    const ids = this.fsdb.lsDirs('');
    ids.forEach(id => {
      this.loadObject(id);
    });
  }

  filenameFor(id) {
    return `${id}/${id}.json`;
  }

  loadObject(id) {
    try {
      const fileContents = this.fsdb.read(this.filenameFor(id));
      const object = JSON.parse(fileContents);
      object.id = id;
      this.loadCallables(id, object.properties);
      this.db.set(id, object);
      this.logger.trace({ objectId: id }, 'loaded object');
      return true;
    } catch (err) {
      this.logger.warn(
        { err: bunyan.stdSerializers.err(err), objectId: id },
        'tried loading object from fsdb, but failed'
      );
      return false;
    }
  }

  loadCallables(id, properties) {
    for (const [key, value] of entries(properties)) {
      if (value.verb || value.function) {
        properties[key] = this.loadCallable(id, value.file);
      }
    }
  }

  loadCallable(id, file) {
    const source = this.fsdb.read(`${id}/${file}`);
    return this.parseCallable(file, source);
  }

  parseCallable(file, source) {
    try {
      const lines = source.split('\n');
      const firstLineMatch = (lines[0] || '').match(VERB_DESCRIPTOR);
      if (firstLineMatch) {
        const [pattern, dobjarg, preparg, iobjarg] = firstLineMatch.slice(1);
        return {
          verb: lines.slice(1).join('\n'),
          pattern, dobjarg, preparg, iobjarg,
          file,
        };
      }
      return { function: source, file };
    } catch (err) {
      this.logger.warn({ err: bunyan.stdSerializers.err(err), file }, 'unable to parse callable');
      return { function: "function invalid() { return 'invalid source'; }", file };
    }
  }

  idFromFilepath(filepath) {
    return filepath.split('/')[0];
  }

  onFileAddedOrChanged(file) {
    const id = this.idFromFilepath(file);
    if (file.endsWith('.json') || file.endsWith('.js')) {
      this.addOrUpdateObject(id);
    }
  }

  onFileRemoved(file) {
    const id = this.idFromFilepath(file);
    if (file.endsWith('.json')) {
      this.removeById(id);
      this.emit('object-removed', id);
    } else if (file.endsWith('.js')) {
      this.addOrUpdateObject(id);
    }
  }

  addOrUpdateObject(id) {
    try {
      const object = this.findById(id);
      const fileContents = this.fsdb.read(this.filenameFor(id));
      const newObjectProperties = JSON.parse(fileContents);
      if (object) {
        object.name = newObjectProperties.name;
        object.aliases = newObjectProperties.aliases;
        object.traitIds = newObjectProperties.traitIds;
        object.locationId = newObjectProperties.locationId;
        object.userId = newObjectProperties.userId;
        object.properties = newObjectProperties.properties;
        this.loadCallables(id, object.properties);
        this.logger.trace({ objectId: id }, 'reloaded object');
      } else {
        this.loadObject(id);
        this.emit('object-added', id);
      }
    } catch (err) {
      this.logger.warn(
        { err: bunyan.stdSerializers.err(err), objectId: id },
        'unable to add or update object'
      );
    }
  }

  serializeAndSaveCallable(id, key, value) {
    const file = value.file || `${key}.js`;
    const filepath = `${id}/${file}`;
    if (value.function) {
      this.fsdb.write(filepath, value.function);
      return { function: true, file };
    } else if (value.verb) {
      const verbDef =
        `// verb: ${value.pattern}; ${value.dobjarg}; ${value.preparg}; ${value.iobjarg}`;
      const source = `${verbDef}\n${value.verb}`;
      this.fsdb.write(filepath, source);
      return { verb: true, file };
    }
    throw new Error('invalid callable');
  }

  savableProperties(object) {
    const properties = {};
    for (const [key, value] of entries(object.properties)) {
      if (value.verb || value.function) {
        properties[key] = this.serializeAndSaveCallable(object.id, key, value);
      } else {
        properties[key] = value;
      }
    }
    return properties;
  }

  serializeObject(object) {
    const obj = {
      name: object.name,
      aliases: object.aliases,
      traitIds: object.traitIds,
      locationId: object.locationId,
      userId: object.userId,
      properties: this.savableProperties(object),
    };
    return `${JSON.stringify(obj, null, '  ')}\n`;
  }

  saveObject(object) {
    this.fsdb.write(`${object.id}/${object.id}.json`, this.serializeObject(object));
    this.logger.trace({ objectId: object.id }, 'saved object');
  }

  removeFilesFor(id) {
    const object = this.findById(id);
    for (const [key, value] of entries(object.properties)) {
      if (value.function || value.verb) {
        const file = value.file || `${key}.js`;
        const filepath = `${id}/${file}`;
        this.fsdb.rm(filepath);
      }
    }
    this.fsdb.rm(`${id}/${id}.json`);
    this.fsdb.rmDir(id); // cleanup; FsDb should do this for us, but it doesn't.
  }

  markObjectDirty(id) {
    this.saveObject(this.findById(id));
  }

  removeProperty(id, key, value) {
    if (value.function || value.verb) {
      const file = value.file || `${key}.js`;
      const filepath = `${id}/${file}`;
      this.fsdb.rm(filepath);
    }
    this.saveObject(this.findById(id));
  }

  insert(object) {
    if (typeof object.id !== 'string') {
      throw new Error('Object must contain a string id property.');
    }
    if (this.db.has(object.id)) {
      throw new Error('An object with that id already exists.');
    }
    this.db.set(object.id, object);
    this.saveObject(object);
    return object;
  }

  remove({ id }) {
    return this.removeById(id);
  }

  removeById(id) {
    this.removeFilesFor(id);
    return this.db.delete(id);
  }

  findById(id) {
    return this.db.get(id);
  }

  findBy(field, value) {
    return [...this.db.values()].filter(object => object[field] === value);
  }

  all() {
    return this.db;
  }

  ids() {
    return [...this.db.keys()];
  }

  playerIds() {
    return [...this.db.values()].filter(object => !!object.userId).map(o => o.id);
  }
}
util.inherits(MooDB, EventEmitter);

module.exports = MooDB;