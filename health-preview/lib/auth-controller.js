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
  async signOut(){
    const {error}=await this.client.auth.signOut();
    if(error)throw error;return true;
  }
  listen(handler){
    const {data:{subscription}}=this.client.auth.onAuthStateChange((event,session)=>handler(event,session));
    return ()=>subscription.unsubscribe();
  }
}
