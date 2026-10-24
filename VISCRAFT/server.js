const http=require('http');
const fs=require('fs');
const path=require('path');
const WebSocket=require('ws');

const PORT=Number(process.env.PORT)||3000;
const ROOT=path.resolve(__dirname);
const ALLOWED_BLOCKS=new Set(['grass','dirt','stone','wood','leaves','sand','water','coal','iron','plank','brick']);
const MIME={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json'};

const server=http.createServer((req,res)=>{
  let pathname;
  try { pathname=decodeURIComponent((req.url||'/').split('?')[0]); }
  catch { res.writeHead(400); return res.end('Bad request'); }
  if(pathname==='/') pathname='/index.html';
  const file=path.resolve(ROOT,'.'+pathname);
  const relative=path.relative(ROOT,file);
  if(relative.startsWith('..')||path.isAbsolute(relative)){res.writeHead(403);return res.end('Forbidden');}
  fs.readFile(file,(err,data)=>{
    if(err){res.writeHead(err.code==='ENOENT'?404:500);return res.end(err.code==='ENOENT'?'Not found':'Server error');}
    res.writeHead(200,{'Content-Type':MIME[path.extname(file)]||'application/octet-stream','X-Content-Type-Options':'nosniff','Referrer-Policy':'strict-origin-when-cross-origin','Cache-Control':'no-cache'});
    res.end(data);
  });
});

const wss=new WebSocket.Server({server,maxPayload:16*1024});
function broadcast(room,from,data){
  const message=JSON.stringify(data);
  for(const c of wss.clients) if(c!==from&&c.readyState===WebSocket.OPEN&&c.room===room)c.send(message);
}
wss.on('connection',ws=>{
  ws.id=Math.random().toString(36).slice(2,10);
  ws.room='lobby';
  ws.player=null;
  ws.messageWindow=Date.now();
  ws.messageCount=0;
  const peers=()=>[...wss.clients].filter(c=>c!==ws&&c.room===ws.room).map(c=>({id:c.id,player:c.player||{}}));
  ws.send(JSON.stringify({type:'welcome',id:ws.id,room:ws.room,players:peers()}));
  ws.on('message',raw=>{
    const now=Date.now();
    if(now-ws.messageWindow>1000){ws.messageWindow=now;ws.messageCount=0;}
    if(++ws.messageCount>40)return;
    let d;
    try{d=JSON.parse(raw.toString());}catch{return;}
    if(!d||typeof d.type!=='string')return;
    if(d.type==='join'){
      const room=String(d.room||'lobby').replace(/[^a-z0-9_-]/gi,'').slice(0,24)||'lobby';
      const previous=ws.room;
      if(previous!==room)broadcast(previous,ws,{type:'player_leave',id:ws.id});
      ws.room=room;
      ws.send(JSON.stringify({type:'joined',room,players:peers()}));
      broadcast(room,ws,{type:'player_join',id:ws.id});
      return;
    }
    if(d.type==='state'){
      const p=d.player;
      if(!p||![p.x,p.y,p.z].every(Number.isFinite)||Math.abs(p.x)>256||Math.abs(p.y)>128||Math.abs(p.z)>256)return;
      ws.player={x:p.x,y:p.y,z:p.z,yaw:Number.isFinite(p.yaw)?p.yaw:0};
      broadcast(ws.room,ws,{type:'state',id:ws.id,player:ws.player});
      return;
    }
    if(d.type==='block'){
      if(![d.x,d.y,d.z].every(Number.isInteger)||Math.abs(d.x)>128||Math.abs(d.y)>64||Math.abs(d.z)>128)return;
      const action=d.action==='remove'?'remove':'place';
      const block=ALLOWED_BLOCKS.has(d.block)?d.block:'stone';
      broadcast(ws.room,ws,{type:'block',action,x:d.x,y:d.y,z:d.z,block});
      return;
    }
    if(d.type==='chat'){
      const message=String(d.message||'').replace(/[\u0000-\u001f\u007f]/g,' ').trim().slice(0,180);
      if(message)broadcast(ws.room,ws,{type:'chat',id:ws.id,message});
    }
  });
  ws.on('close',()=>broadcast(ws.room,ws,{type:'player_leave',id:ws.id}));
  ws.on('error',()=>{});
});
server.listen(PORT,()=>console.log('VISCRAFT server listening on http://localhost:'+PORT+' (WebSocket relay enabled)'));
