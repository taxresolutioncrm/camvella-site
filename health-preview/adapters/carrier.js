export class CarrierAdapter {
  constructor(config={}){this.config=config}
  async syncProducts(input){return {provider:this.config.provider||'mock',status:'mock_only',input,products:[]}}
  async syncContracting(input){return {provider:this.config.provider||'mock',status:'mock_only',input,appointments:[]}}
  async syncEnrollmentStatus(input){return {provider:this.config.provider||'mock',status:'mock_only',input}}
  async syncCommissionStatement(input){return {provider:this.config.provider||'mock',status:'mock_only',input,lines:[]}}
}
