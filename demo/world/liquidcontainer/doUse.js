function doUse(agent) {
  this.rmAlias(this.containedLiquid);
  this.name = `empty ${this.containerObject}`;
  this.finished = true;
}