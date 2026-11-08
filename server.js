import http from 'node:http';
import {readFile} from 'node:fs/promises';
const files={'/':'index.html','/app.js':'app.js','/rules.js':'rules.js','/style.css':'style.css'};
const types={html:'text/html',js:'text/javascript',css:'text/css'};
http.createServer(async(req,res)=>{
  const file=files[new URL(req.url,'http://localhost').pathname];
  if(!file){res.writeHead(404);res.end('Not found');return;}
  try {const body=await readFile(new URL(file,import.meta.url));res.writeHead(200,{'Content-Type':types[file.split('.').pop()]+'; charset=utf-8'});res.end(body);}
  catch {res.writeHead(500);res.end('Could not load application');}
}).listen(Number(process.env.PORT)||3000,'0.0.0.0',()=>console.log('Tiles listening on port '+(process.env.PORT||3000)));
