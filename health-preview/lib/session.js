export const Roles=Object.freeze({ADMIN:'agency_admin',MANAGER:'manager',AGENT:'agent',COMPLIANCE:'compliance',REVENUE:'revenue'});
const permissions={
  agency_admin:['*'],
  manager:['clients.read','clients.write','enrollment.read','enrollment.write','reports.read','team.read','commissions.read','compliance.read'],
  agent:['clients.read','clients.write','enrollment.read','enrollment.write','communications.write','tasks.write'],
  compliance:['clients.read','enrollment.read','evidence.write','compliance.write','audit.read'],
  revenue:['clients.read','policies.read','commissions.read','commissions.write']
};
export function can(role,permission){const p=permissions[role]||[];return p.includes('*')||p.includes(permission)}
export function assertCan(role,permission){if(!can(role,permission))throw new Error('Permission denied: '+permission)}
