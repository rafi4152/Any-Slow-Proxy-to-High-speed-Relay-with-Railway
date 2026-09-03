FROM node:22-alpine
WORKDIR /app

# Single-file SOCKS5 + HTTP Dashboard + IPCook upstream manager.
# Lightweight: no npm dependencies.

RUN cat > server.mjs <<'EOF'
import net from "node:net";
import fs from "node:fs";
import crypto from "node:crypto";

const PORT=Number(process.env.PORT||8080);
const DATA_DIR="/data", STATE_FILE=DATA_DIR+"/state.json";
const ADMIN_TOKEN=process.env.ADMIN_TOKEN||"";
const MAX_PROXIES=40;
const MAX_CONN=1000;

const S={proxies:[],activeId:null,rotation:{enabled:false,intervalSec:900,index:0},rateBps:0,conn:0,started:Date.now(),checking:false};
const clients=new Set();

function load(){try{fs.mkdirSync(DATA_DIR,{recursive:true});if(fs.existsSync(STATE_FILE)){const x=JSON.parse(fs.readFileSync(STATE_FILE));S.proxies=Array.isArray(x.proxies)?x.proxies.slice(0,MAX_PROXIES):[];S.activeId=x.activeId||null;S.rotation={...S.rotation,...(x.rotation||{})};S.rateBps=Number(x.rateBps)||0}}catch(e){console.error("load",e.message)}}
function save(){try{fs.mkdirSync(DATA_DIR,{recursive:true});const t=STATE_FILE+".tmp";fs.writeFileSync(t,JSON.stringify({proxies:S.proxies,activeId:S.activeId,rotation:S.rotation,rateBps:S.rateBps}));fs.renameSync(t,STATE_FILE)}catch(e){console.error("save",e.message)}}
load();

function parse(v){const a=String(v||"").trim().lastIndexOf("@");if(a<1)throw Error("Format: host:port@username:password");const hp=v.slice(0,a),au=v.slice(a+1),c=hp.lastIndexOf(":"),d=au.indexOf(":");if(c<1||d<1)throw Error("Invalid proxy format");const port=Number(hp.slice(c+1));if(!Number.isInteger(port)||port<1||port>65535)throw Error("Invalid port");return{id:crypto.randomUUID(),host:hp.slice(0,c),port,username:au.slice(0,d),password:au.slice(d+1),enabled:true,status:"unknown",lastIp:"",lastError:"",lastCheck:0,created:Date.now()}}
function pub(p){return p&&({...p,password:undefined,username:p.username?mask(p.username):""})}
function mask(x){return x.length<5?"***":x.slice(0,3)+"***"+x.slice(-2)}
function active(){return S.proxies.find(p=>p.id===S.activeId&&p.enabled)||S.proxies.find(p=>p.enabled)||null}
function closeClients(){for(const x of [...clients])try{x.destroy()}catch{}}

async function testProxy(p){
  p.status="checking";
  return new Promise(resolve=>{
    const s=net.connect({host:p.host,port:p.port});
    let done=false,b=Buffer.alloc(0),stage=0;
    const finish=(ok,ip="",err="")=>{if(done)return;done=true;clearTimeout(timer);try{s.destroy()}catch{};p.status=ok?"ready":"failed";p.lastIp=ip;p.lastError=err;p.lastCheck=Date.now();save();resolve({ok,ip,error:err})};
    const timer=setTimeout(()=>finish(false,"","timeout"),9000);
    s.on("error",e=>finish(false,"",e.message));
    s.on("connect",()=>{const auth=Buffer.from(`${p.username}:${p.password}`).toString("base64");s.write(`GET http://api.ipify.org HTTP/1.1\r\nHost: api.ipify.org\r\nProxy-Authorization: Basic ${auth}\r\nConnection: close\r\n\r\n`)});
    s.on("data",c=>{b=Buffer.concat([b,c]);if(b.length>1024*1024)return finish(false,"","response too large");const txt=b.toString();if(txt.includes("\r\n\r\n")&&/HTTP\/1\.[01]\s+200/.test(txt)){const body=txt.split("\r\n\r\n")[1].trim();const ip=body.match(/[0-9a-fA-F:.]+/)?.[0]||body;finish(true,ip)}})
  })
}

function schedule(){if(globalThis.rt)clearInterval(globalThis.rt);globalThis.rt=null;if(!S.rotation.enabled)return;globalThis.rt=setInterval(()=>{try{const a=S.proxies.filter(p=>p.enabled&&p.status!=="failed");if(!a.length)return;S.rotation.index=(S.rotation.index+1)%a.length;S.activeId=a[S.rotation.index].id;save();closeClients()}catch(e){console.error("rotate",e.message)}},Math.max(60,S.rotation.intervalSec)*1000)}
schedule();

function throttlePipe(src,dst,rate){
 if(!rate){src.pipe(dst);return}
 let credit=rate,last=Date.now(),q=Promise.resolve();
 src.on("data",c=>{q=q.then(async()=>{const now=Date.now();credit=Math.min(rate,credit+(now-last)/1000*rate);last=now;const wait=Math.max(0,(c.length-credit)/rate*1000);credit=Math.max(0,credit-c.length);if(wait)await new Promise(r=>setTimeout(r,Math.min(wait,5000)));if(!dst.destroyed)dst.write(c)}).catch(()=>{})});
 src.on("end",()=>q.finally(()=>{if(!dst.destroyed)dst.end()}));src.on("error",()=>dst.destroy());
}

function handleSocks(sock,first){
 if(S.conn>=MAX_CONN){sock.destroy();return}
 S.conn++;clients.add(sock);let counted=true;
 const clean=()=>{if(counted){counted=false;S.conn=Math.max(0,S.conn-1);clients.delete(sock)}};
 sock.on("close",clean);sock.on("error",()=>{});
 let buf=first,stage=0,targetHost="",targetPort=0;
 const feed=c=>{
   buf=Buffer.concat([buf,c]);
   if(stage===0){
     if(buf.length<2)return;if(buf[0]!==5){sock.destroy();return}
     const n=buf[1];if(buf.length<2+n)return;buf=buf.subarray(2+n);
     sock.write(Buffer.from([5,0]));stage=1;
   }
   if(stage===1){
     if(buf.length<4)return;
     if(buf[0]!==5||buf[1]!==1){sock.write(Buffer.from([5,7,0,1,0,0,0,0,0,0]));sock.destroy();return}
     const atyp=buf[3];let need;
     if(atyp===1)need=10; else if(atyp===3){if(buf.length<5)return;need=7+buf[4]} else if(atyp===4)need=22; else {sock.destroy();return}
     if(buf.length<need)return;
     if(atyp===1)targetHost=[...buf.subarray(4,8)].join(".");
     if(atyp===3)targetHost=buf.subarray(5,5+buf[4]).toString();
     if(atyp===4){let x=[];for(let i=4;i<20;i+=2)x.push(buf.readUInt16BE(i).toString(16));targetHost=x.join(":")}
     targetPort=buf.readUInt16BE(need-2);buf=buf.subarray(need);stage=2;
     connectUpstream();
   }
 };
 const connectUpstream=()=>{
   const p=active();if(!p){sock.destroy();return}
   const up=net.connect(p.port,p.host);up.setNoDelay(true);sock.setNoDelay(true);clients.add(up);
   const cleanUp=()=>clients.delete(up);up.on("close",cleanUp);
   const fail=(m)=>{try{sock.write(Buffer.from([5,1,0,1,0,0,0,0,0,0]))}catch{};try{sock.destroy()}catch{};try{up.destroy()}catch{};p.status="failed";p.lastError=m;save()};
   const timer=setTimeout(()=>fail("upstream timeout"),12000);
   up.on("connect",()=>{
     clearTimeout(timer);
     const auth=Buffer.from(`${p.username}:${p.password}`).toString("base64");
     up.write(`CONNECT ${targetHost}:${targetPort} HTTP/1.1\r\nHost: ${targetHost}:${targetPort}\r\nProxy-Authorization: Basic ${auth}\r\nProxy-Connection: Keep-Alive\r\n\r\n`);
   });
   let hb=Buffer.alloc(0);
   up.on("data",function handshake(c){
     hb=Buffer.concat([hb,c]);const i=hb.indexOf("\r\n\r\n");if(i<0)return;
     up.off("data",handshake);const h=hb.subarray(0,i).toString(),rest=hb.subarray(i+4);
     if(!/^HTTP\/1\.[01]\s+200/m.test(h)){p.status="failed";p.lastError="upstream CONNECT rejected";save();fail("CONNECT rejected");return}
     p.status="ready";p.lastError="";save();
     sock.write(Buffer.from([5,0,0,1,0,0,0,0,0,0]));
     if(rest.length)sock.write(rest);
     if(buf.length)up.write(buf);
     sock.pipe(up);throttlePipe(up,sock,S.rateBps);
   });
   up.on("error",e=>fail(e.message));sock.on("error",()=>up.destroy());
 };
 feed(Buffer.alloc(0));
 sock.on("data",c=>{if(stage<2)feed(c)});
}

const CSS=`:root{--bg:#050711;--p:rgba(17,23,40,.76);--l:rgba(255,255,255,.1);--t:#f7f9ff;--m:#9ba7bf;--a:#7d5cff;--b:#20d8ff;--g:#35e49a;--r:#ff5478}*{box-sizing:border-box}body{margin:0;min-height:100vh;color:var(--t);font-family:Inter,system-ui,sans-serif;background:radial-gradient(circle at 10% 5%,rgba(125,92,255,.25),transparent 28%),radial-gradient(circle at 90% 10%,rgba(32,216,255,.16),transparent 25%),linear-gradient(#050711,#0b0f1b)}.w{max-width:1180px;margin:auto;padding:18px}.top{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:14px}.brand{display:flex;gap:11px;align-items:center}.logo{width:46px;height:46px;display:grid;place-items:center;border-radius:15px;background:linear-gradient(145deg,var(--a),var(--b));font-size:23px;box-shadow:0 16px 38px rgba(100,90,255,.35)}h1{font-size:19px;margin:0}.sub,.hint{font-size:11px;color:var(--m)}.grid{display:grid;grid-template-columns:repeat(12,1fr);gap:13px}.card{grid-column:span 12;background:linear-gradient(145deg,rgba(255,255,255,.075),rgba(255,255,255,.025));border:1px solid var(--l);border-radius:23px;padding:16px;box-shadow:0 24px 70px rgba(0,0,0,.35);backdrop-filter:blur(18px)}.stat{grid-column:span 3}.k{font-size:11px;color:var(--m)}.v{font-size:25px;font-weight:900;margin-top:7px}.row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.between{justify-content:space-between}.title{font-weight:800;font-size:16px}.btn,input{font:inherit}.btn{border:1px solid var(--l);color:var(--t);background:rgba(255,255,255,.055);padding:9px 12px;border-radius:12px;cursor:pointer}.btn:hover{background:rgba(255,255,255,.1)}.pri{border:0;background:linear-gradient(135deg,var(--a),#28bfff)}.bad{background:rgba(255,84,120,.12)}.ok{background:rgba(53,228,154,.1)}input{width:100%;background:rgba(0,0,0,.25);color:var(--t);border:1px solid var(--l);padding:11px;border-radius:12px;outline:0}.add{display:grid;grid-template-columns:1fr auto;gap:8px;margin-top:10px}.list{display:grid;gap:9px;margin-top:12px}.p{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:9px;padding:13px;border:1px solid var(--l);background:rgba(255,255,255,.03);border-radius:16px}.mono{font:11px ui-monospace,monospace;color:#c0c9dc;margin-top:5px}.pill{display:inline-flex;gap:6px;align-items:center;border:1px solid var(--l);padding:4px 8px;border-radius:999px;font-size:10px}.dot{width:8px;height:8px;border-radius:50%;background:#7b8498}.ready .dot{background:var(--g);box-shadow:0 0 12px var(--g)}.failed .dot{background:var(--r);box-shadow:0 0 12px var(--r)}.checking .dot{background:#ffd55c}.active{color:var(--g)}.login{max-width:430px;margin:12vh auto}.login .card{padding:24px}.settings{display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;margin-top:10px}@media(max-width:700px){.stat{grid-column:span 6}.add{grid-template-columns:1fr}.p{grid-template-columns:1fr}.settings{grid-template-columns:1fr}.w{padding:11px}}@media(max-width:450px){.stat{grid-column:span 12}}`;
const JS=`let tok=localStorage.getItem('ipcook_token')||'';const $=id=>document.getElementById(id);const esc=s=>String(s??'').replace(/[&<>"']/g,x=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[x]));async function api(u,o={}){o.headers={...(o.headers||{}),Authorization:'Bearer '+tok,'Content-Type':'application/json'};let r=await fetch(u,o),d=await r.json().catch(()=>({}));if(r.status===401){localStorage.removeItem('ipcook_token');tok='';throw Object.assign(new Error('Unauthorized'),{unauthorized:true})}if(!r.ok)throw Error(d.error||'Error');return d}function toast(t,b=0){let x=$('toast');x.textContent=t;x.style.opacity=1;x.style.borderColor=b?'#ff5478':'#35e49a';setTimeout(()=>x.style.opacity=0,2300)}function fmt(n){if(!n)return'Unlimited';return n/1024>=1024?(n/1048576).toFixed(1)+' MB/s':Math.round(n/1024)+' KB/s'}let refreshBusy=false;async function refresh(){if(refreshBusy)return;refreshBusy=true;try{let d=await api('/api/state');$('app').style.display='block';$('login').style.display='none';$('act').textContent=d.active?.host||'—';$('count').textContent=d.proxies.length;$('conn').textContent=d.conn;$('rate').textContent=fmt(d.rateBps);$('interval').value=d.rotation.intervalSec;$('kb').value=d.rateBps/1024;$('auto').checked=d.rotation.enabled;$('list').innerHTML=d.proxies.length?d.proxies.map(p=>'<div class="p"><div><div class="row"><b>'+esc(p.host)+':'+p.port+'</b><span class="pill '+p.status+'"><i class="dot"></i>'+p.status.toUpperCase()+'</span>'+(d.active?.id===p.id?'<span class="pill active">✓ ACTIVE</span>':'')+'</div><div class="mono">IP: '+esc(p.lastIp||'not checked')+(p.lastError?' · '+esc(p.lastError):'')+'</div></div><div class="row"><button class="btn ok" onclick="checkP(\\''+p.id+'\\')">✓ Check</button><button class="btn pri" onclick="useP(\\''+p.id+'\\')">Use</button><button class="btn" onclick="toggle(\\''+p.id+'\\')">'+(p.enabled?'Disable':'Enable')+'</button><button class="btn bad" onclick="del(\\''+p.id+'\\')">Delete</button></div></div>').join(''):'<div class="hint">Add an upstream proxy. Use ✓ Check before connecting.</div>'}catch(e){$('app').style.display='none';$('login').style.display='block'}finally{refreshBusy=false}}async function add(){try{await api('/api/proxies',{method:'POST',body:JSON.stringify({proxy:$('proxy').value})});$('proxy').value='';await refresh();toast('Added')}catch(e){toast(e.message,1)}}async function checkP(id){toast('Checking…');try{let d=await api('/api/check/'+id,{method:'POST'});await refresh();toast(d.ok?'✓ Ready · '+d.ip:d.error, !d.ok)}catch(e){toast(e.message,1)}}async function useP(id){try{await api('/api/switch',{method:'POST',body:JSON.stringify({id})});await refresh();toast('Switched · reconnect app')}catch(e){toast(e.message,1)}}async function toggle(id){try{await api('/api/proxies/'+id,{method:'PATCH'});refresh()}catch(e){toast(e.message,1)}}async function del(id){if(!confirm('Delete?'))return;await api('/api/proxies/'+id,{method:'DELETE'});refresh()}async function saveSet(){try{await api('/api/settings',{method:'POST',body:JSON.stringify({intervalSec:+$('interval').value,rateKBps:+$('kb').value,enabled:$('auto').checked})});refresh();toast('Saved')}catch(e){toast(e.message,1)}}async function login(){const input=$('token');const candidate=input.value.trim();if(!candidate){toast('ADMIN_TOKEN দিন',1);return}tok=candidate;try{await api('/api/state');localStorage.setItem('ipcook_token',tok);input.blur();$('app').style.display='block';$('login').style.display='none';refresh()}catch(e){tok='';localStorage.removeItem('ipcook_token');toast('ADMIN_TOKEN ভুল',1);input.focus()}}refresh();setInterval(()=>{if(tok&&!document.hidden)refresh()},30000);`;
const page=`<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><style>${CSS}</style><div id="login" class="w login"><div class="card"><div class="row"><div class="logo">⚡</div><div><h1>IPCook SOCKS5 Manager</h1><div class="sub">Advanced lightweight relay dashboard</div></div></div><div class="k" style="margin-top:20px">ADMIN_TOKEN</div><input id="token" type="password" placeholder="Railway variable token" style="margin-top:7px"><button class="btn pri" style="width:100%;margin-top:9px" onclick="login()">Unlock</button></div></div><div id="app" style="display:none"><div class="w"><div class="top"><div class="brand"><div class="logo">⚡</div><div><h1>IPCook SOCKS5 Manager</h1><div class="sub">SuperProxy-style health checks · rotation · bandwidth</div></div></div><button class="btn" onclick="refresh()">Refresh</button></div><div class="grid"><div class="card stat"><div class="k">ACTIVE</div><div class="v" id="act">—</div></div><div class="card stat"><div class="k">POOL</div><div class="v" id="count">0</div></div><div class="card stat"><div class="k">TUNNELS</div><div class="v" id="conn">0</div></div><div class="card stat"><div class="k">CAP / TUNNEL</div><div class="v" id="rate">Unlimited</div></div><div class="card"><div class="title">Add upstream</div><div class="hint">Format: host:port@username:password</div><div class="add"><input id="proxy" placeholder="geo-sg.ipcook.com:32345@USERNAME:PASSWORD"><button class="btn pri" onclick="add()">Add proxy</button></div></div><div class="card"><div class="title">Rotation & speed</div><div class="settings"><label><div class="k">Interval (seconds, min 60)</div><input id="interval" type="number" min="60"></label><label><div class="k">Download cap / tunnel KB/s (0 unlimited)</div><input id="kb" type="number" min="0"></label><label><div class="k">Auto rotation</div><div class="row" style="margin-top:12px"><input id="auto" type="checkbox" style="width:auto"><span>Enable automatic switching</span></div></label></div><button class="btn ok" style="margin-top:10px" onclick="saveSet()">Save settings</button><div class="hint" style="margin-top:8px">A speed cap can limit traffic; it cannot force the upstream to become faster.</div></div><div class="card"><div class="row between"><div><div class="title">Proxy pool</div><div class="hint">Green ✓ = tested working. Check before using.</div></div><span class="pill">SOCKS5 incoming → IPCook CONNECT upstream</span></div><div class="list" id="list"></div></div></div></div></div><div id="toast" style="position:fixed;bottom:20px;left:50%;transform:translateX(-50%);padding:10px 13px;border:1px solid #35e49a;background:#111827;border-radius:12px;opacity:0;transition:.2s"></div><script>${JS}</script>`;

function httpReply(sock,code,type,body){const st={200:"OK",400:"Bad Request",401:"Unauthorized",404:"Not Found",405:"Method Not Allowed",413:"Payload Too Large"}[code]||"Error";sock.end(`HTTP/1.1 ${code} ${st}\r\nContent-Type: ${type}\r\nContent-Length: ${Buffer.byteLength(body)}\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n${body}`)}
function parseReq(sock,first){
 let b=first;const on=c=>{b=Buffer.concat([b,c]);if(b.length>150*1024){sock.destroy();return}const i=b.indexOf("\r\n\r\n");if(i<0)return;sock.off("data",on);const h=b.subarray(0,i).toString(),lines=h.split("\r\n"),m=lines[0].split(" "),headers={};for(const l of lines.slice(1)){const x=l.indexOf(":");if(x>0)headers[l.slice(0,x).toLowerCase()]=l.slice(x+1).trim()}const len=Math.min(Number(headers["content-length"]||0),128*1024);let body=b.subarray(i+4);const done=()=>route(m[0],m[1],headers,body.subarray(0,len).toString());if(body.length>=len)done();else sock.on("data",function more(c){body=Buffer.concat([body,c]);if(body.length>=len){sock.off("data",more);done()}})};
 sock.on("data",on);on(Buffer.alloc(0));
 async function route(method,path,headers,body){
  try{
   if(path==="/health")return httpReply(sock,200,"application/json",JSON.stringify({ok:true,uptime:Math.floor((Date.now()-S.started)/1000)}));
   if(!path.startsWith("/api/"))return httpReply(sock,200,"text/html; charset=utf-8",page);
   const got=(headers.authorization||"").replace(/^Bearer\s+/i,"");
   if(!ADMIN_TOKEN||got!==ADMIN_TOKEN)return httpReply(sock,401,"application/json",JSON.stringify({error:"Unauthorized"}));
   const j=body?JSON.parse(body):{};
   if(path==="/api/state"&&method==="GET")return httpReply(sock,200,"application/json",JSON.stringify({proxies:S.proxies.map(pub),active:pub(active()),rotation:S.rotation,rateBps:S.rateBps,conn:S.conn}));
   if(path==="/api/proxies"&&method==="POST"){if(S.proxies.length>=MAX_PROXIES)throw Error("Pool limit reached");const p=parse(j.proxy);S.proxies.push(p);if(!S.activeId)S.activeId=p.id;save();return httpReply(sock,200,"application/json",JSON.stringify({ok:true}))}
   if(path.startsWith("/api/proxies/")&&method==="DELETE"){const id=path.split("/").pop();S.proxies=S.proxies.filter(p=>p.id!==id);if(S.activeId===id)S.activeId=active()?.id||null;save();return httpReply(sock,200,"application/json",'{"ok":true}')}
   if(path.startsWith("/api/proxies/")&&method==="PATCH"){const p=S.proxies.find(x=>x.id===path.split("/").pop());if(!p)throw Error("Not found");p.enabled=!p.enabled;if(!p.enabled&&S.activeId===p.id)S.activeId=active()?.id||null;save();return httpReply(sock,200,"application/json",'{"ok":true}')}
   if(path.startsWith("/api/check/")&&method==="POST"){const p=S.proxies.find(x=>x.id===path.split("/").pop());if(!p)throw Error("Not found");return httpReply(sock,200,"application/json",JSON.stringify(await testProxy(p)))}
   if(path==="/api/switch"&&method==="POST"){const p=S.proxies.find(x=>x.id===j.id&&x.enabled);if(!p)throw Error("Proxy not found");S.activeId=p.id;save();closeClients();return httpReply(sock,200,"application/json",'{"ok":true}')}
   if(path==="/api/settings"&&method==="POST"){S.rotation.intervalSec=Math.max(60,Number(j.intervalSec||900));S.rotation.enabled=!!j.enabled;S.rateBps=Math.max(0,Number(j.rateKBps||0))*1024;save();schedule();return httpReply(sock,200,"application/json",'{"ok":true}')}
   return httpReply(sock,404,"application/json",'{"error":"Not found"}');
  }catch(e){httpReply(sock,400,"application/json",JSON.stringify({error:e.message}))}
 }
}

const server=net.createServer(sock=>{
 sock.once("data",first=>{
   if(!first?.length)return sock.destroy();
   if(first[0]===5)handleSocks(sock,first);
   else if(/[A-Z]/.test(String.fromCharCode(first[0])))parseReq(sock,first);
   else sock.destroy();
 });
 sock.on("error",()=>{});
});
server.on("error",e=>console.error("server",e));
process.on("uncaughtException",e=>console.error("uncaught",e));
process.on("unhandledRejection",e=>console.error("rejection",e));
process.on("SIGTERM",()=>{if(globalThis.rt)clearInterval(globalThis.rt);closeClients();server.close(()=>process.exit(0));setTimeout(()=>process.exit(0),8000).unref()});
server.listen(PORT,"0.0.0.0",()=>console.log("Manager listening",PORT));
EOF

CMD ["node", "server.mjs"]
