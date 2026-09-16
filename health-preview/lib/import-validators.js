const markets=new Set(['aca','medicare']);
export function validateLead(row){const e=[];if(!row.first_name)e.push('first_name');if(!row.last_name)e.push('last_name');if(!markets.has(row.market))e.push('market');if(row.score!==''&&row.score!=null&&(Number(row.score)<0||Number(row.score)>100))e.push('score');return e}
export function validateClient(row){const e=[];if(!row.first_name)e.push('first_name');if(!row.last_name)e.push('last_name');if(!markets.has(row.market))e.push('market');return e}
export function validateCarrierProduct(row){const e=[];if(!row.carrier)e.push('carrier');if(!markets.has(row.market))e.push('market');if(!row.product_name)e.push('product_name');if(!row.state)e.push('state');return e}
export function validateCommission(row){const e=[];if(!row.carrier)e.push('carrier');for(const k of ['gross_amount','net_amount'])if(row[k]===''||Number.isNaN(Number(row[k])))e.push(k);return e}
