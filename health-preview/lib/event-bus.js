export class EventBus {
  constructor(){this.listeners=new Map()}
  on(type,fn){const set=this.listeners.get(type)||new Set();set.add(fn);this.listeners.set(type,set);return()=>set.delete(fn)}
  emit(type,payload){for(const fn of this.listeners.get(type)||[])fn(payload)}
}
export const events=new EventBus();
