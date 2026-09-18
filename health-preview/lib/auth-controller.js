export class AuthController{
  constructor(client,{redirectTo}={}){
    if(!client) throw new Error('Supabase client is required');
    this.client=client;
    this.redirectTo=redirectTo||null;
  }
  async signInWithPassword(email,password){
    const {data,error}=await this.client.auth.signInWithPassword({email,password});
    if(error)throw error;return data;
  }
  async sendMagicLink(email){
    const options=this.redirectTo?{emailRedirectTo:this.redirectTo}:{};
    const {data,error}=await this.client.auth.signInWithOtp({email,options});
    if(error)throw error;return data;
  }
  async resetPassword(email){
    const options=this.redirectTo?{redirectTo:this.redirectTo}:{};
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
  async signOut(){
    const {error}=await this.client.auth.signOut();
    if(error)throw error;return true;
  }
  listen(handler){
    const {data:{subscription}}=this.client.auth.onAuthStateChange((event,session)=>handler(event,session));
    return ()=>subscription.unsubscribe();
  }
}
