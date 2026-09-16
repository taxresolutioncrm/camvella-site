export class Repository {
  constructor(driver){this.driver=driver}
  list(resource,query={}){return this.driver.list(resource,query)}
  get(resource,id){return this.driver.get(resource,id)}
  create(resource,payload){return this.driver.create(resource,payload)}
  update(resource,id,payload){return this.driver.update(resource,id,payload)}
  remove(resource,id){return this.driver.remove(resource,id)}
}

export class MemoryDriver {
  constructor(seed={}){this.db=structuredClone(seed)}
  list(resource){return Promise.resolve([...(this.db[resource]||[])])}
  get(resource,id){return Promise.resolve((this.db[resource]||[]).find(x=>x.id===id)||null)}
  create(resource,payload){const row={id:crypto.randomUUID(),...payload,created_at:new Date().toISOString()};(this.db[resource]??=[]).push(row);return Promise.resolve(row)}
  update(resource,id,payload){const rows=this.db[resource]||[];const i=rows.findIndex(x=>x.id===id);if(i<0)throw new Error('Not found');rows[i]={...rows[i],...payload,updated_at:new Date().toISOString()};return Promise.resolve(rows[i])}
  remove(resource,id){const rows=this.db[resource]||[];const i=rows.findIndex(x=>x.id===id);if(i<0)return Promise.resolve(false);rows.splice(i,1);return Promise.resolve(true)}
}
