export class AuthController{
  constructor(client,{magicLinkRedirectTo,recoveryRedirectTo,redirectTo}={}){
    if(!client) throw new Error('Supabase client is required');
    this.client=client;
    this.magicLinkRedirectTo=magicLinkRedirectTo||redirectTo||null;
    this.recoveryRedirectTo=recoveryRedirectTo||redirectTo||null;
  }
  async signInWithPassword(email,password){
    const {data,error}=await this.client.auth.signInWithPassword({email,password});
    if(error)throw error;return data;
  }
  async sendMagicLink(email){
    const options=this.magicLinkRedirectTo?{emailRedirectTo:this.magicLinkRedirectTo}:{};
    const {data,error}=await this.client.auth.signInWithOtp({email,options});
    if(error)throw error;return data;
  }
  async resetPassword(email){
    const options=this.recoveryRedirectTo?{redirectTo:this.recoveryRedirectTo}:{};
    const {data,error}=await this.client.auth.resetPasswordForEmail(email,options);
    if(error)throw error;return data;
  }
  async updatePassword(password){
    const {data,error}=await this.client.auth.updateUser({password});
    if(error)throw error;return data;
  }
  async enrollTotp(friendlyName='Authenticator'){
    const {data,error}=await this.client.auth.mfa.enroll({factorType:'totp',friendlyName});
    if(error)throw error;return data;
  }
  async challengeTotp(factorId){
    const {data,error}=await this.client.auth.mfa.challenge({factorId});
    if(error)throw error;return data;
  }
  async verifyTotp(factorId,challengeId,code){
    const {data,error}=await this.client.auth.mfa.verify({factorId,challengeId,code});
    if(error)throw error;return data;
  }
  async listMfaFactors(){
    const {data,error}=await this.client.auth.mfa.listFactors();
    if(error)throw error;return data;
  }
  async getAuthenticatorAssuranceLevel(){
    const {data,error}=await this.client.auth.mfa.getAuthenticatorAssuranceLevel();
    if(error)throw error;return data;
  }
  async signOut(){
    const {error}=await this.client.auth.signOut();
    if(error)throw error;return true;
  }
  listen(handler){
    const {data:{subscription}}=this.client.auth.onAuthStateChange((event,session)=>handler(event,session));
    return ()=>subscription.unsubscribe();
  }
}