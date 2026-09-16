export class MarketplaceAdapter {
  constructor(config={}){this.config=config}
  async getPlans(input){return {source:'mock-marketplace',query:input,plans:[]}}
  async checkEligibility(input){return {source:'mock-marketplace',query:input,status:'mock_only'}}
  async getProviderDirectory(input){return {source:'mock-marketplace',query:input,providers:[]}}
  async checkDrugCoverage(input){return {source:'mock-marketplace',query:input,results:[]}}
}
