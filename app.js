import {Game,SYMMETRIES,symmetryStates,rotate,placement} from './rules.js';
const $=id=>document.getElementById(id);
let game=new Game(), cells=game.piece.cells, anchor=null, gameOver=false, pendingSize=9;
let touchAnchor=null;
function render(){
  gameOver=game.over;
  $('board').style.gridTemplateColumns=`repeat(${game.board.length},1fr)`;
  $('board').replaceChildren();
  game.board.forEach((row,y)=>row.forEach((color,x)=>{
    const button=document.createElement('button'); button.className='cell'+(color?' '+color:'')+(x===Math.floor(row.length/2)&&y===Math.floor(row.length/2)?' center':'');
    button.dataset.x=x; button.dataset.y=y; button.setAttribute('role','gridcell');
    button.setAttribute('aria-label',`Row ${y+1}, column ${x+1}, ${color||'empty'}`);
    button.addEventListener('pointerenter',e=>{if(e.pointerType!=='touch'){anchor={x,y};preview();}});
    button.addEventListener('focus',()=>{anchor={x,y};preview();});
    button.addEventListener('pointerdown',e=>{if(e.pointerType==='touch'){e.preventDefault();if(touchAnchor?.x===x&&touchAnchor?.y===y)put(x,y);else{touchAnchor={x,y};anchor={x,y};preview();}}});
    button.addEventListener('click',e=>{if(e.pointerType==='touch')return;put(x,y);});
    $('board').append(button);
  }));
  const states=symmetryStates(game.board);
  $('symmetries').replaceChildren();
  SYMMETRIES.forEach((s,i)=>{
    const item=document.createElement('div'); item.className='symmetry'+(states[i].possible?' possible':'');
    item.title=`${s.name}: ${states[i].complete?'complete':states[i].possible?'still possible':'color conflict'}`;
    const lines=['M12 3V21','M3 12H21','M4 4L20 20','M4 20L20 4'];
    const icon=i<4?`<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="2" opacity=".3"/><path d="${lines[i]}" stroke-dasharray="2 2"/></svg>`:`<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 8A8 8 0 1 0 20 15M15 8H20V3"/></svg>`;
    item.innerHTML=`<span class="symbol">${icon}</span><span>${s.name}</span><span class="state">${states[i].complete?'✓':states[i].possible?'●':'–'}</span>`;
    item.setAttribute('aria-label',item.title); $('symmetries').append(item);
  });
  const width=Math.max(...cells.map(p=>p[0]))+1;
  $('piece').style.gridTemplateColumns=`repeat(${width},var(--unit))`;
  $('piece').replaceChildren();
  const height=Math.max(...cells.map(p=>p[1]))+1;
  $('piece').style.gridTemplateRows=`repeat(${height},var(--unit))`;
  for(let y=0;y<height;y++)for(let x=0;x<width;x++){
    const el=document.createElement('div');el.className='mini'+(cells.some(p=>p[0]===x&&p[1]===y)?' '+game.piece.color:'');$('piece').append(el);
  }
  $('piece-name').textContent=`${game.queue[game.index]} · ${game.piece.color==='green'?'Sage':'Marigold'}`;
  $('piece').setAttribute('aria-label',`${game.queue[game.index]} piece, ${game.piece.color}`);
  $('undo').disabled=!game.history.length;
  $('undo-count').textContent=`${game.history.length} / 3`;
  $('rotate').disabled=gameOver;
  $('board-label').textContent=`YOUR GARDEN · ${game.board.length} × ${game.board.length}`;
  $('move-count').textContent=`${game.moves} ${game.moves===1?'piece':'pieces'} placed`;
  $('status').textContent=gameOver?'This pattern has reached its edge. Go back a step, or begin a new garden.':`${states.filter(s=>s.possible).length} paths to symmetry remain. Place a piece and see what grows.`;
  preview();
}
function preview(){
  document.querySelectorAll('.cell').forEach(el=>{el.classList.remove('preview','invalid');if(!game.board[+el.dataset.y][+el.dataset.x])el.classList.remove('green','yellow');});
  if(!anchor||gameOver)return;
  const result=placement(game.board,cells,game.piece.color,anchor.x,anchor.y);
  cells.forEach(([dx,dy])=>{
    const el=$('board').querySelector(`[data-x="${anchor.x+dx}"][data-y="${anchor.y+dy}"]`);
    if(el){el.classList.add(result.ok?'preview':'invalid');if(result.ok)el.classList.add(game.piece.color);}
  });
}
function put(x,y){
  if(gameOver)return;
  const result=game.place(cells,x,y);
  if(!result.ok){$('status').textContent=result.reason;return;}
  cells=game.piece.cells;anchor=null;touchAnchor=null;render();
}
$('board').addEventListener('pointerleave',()=>{if(!touchAnchor){anchor=null;preview();}});
function turn(){if(gameOver)return;cells=rotate(cells);touchAnchor=null;render();}
$('rotate').onclick=turn;
$('undo').onclick=()=>{if(game.undo()){cells=game.piece.cells;anchor=null;touchAnchor=null;render();}};
window.addEventListener('keydown',e=>{if(e.key.toLowerCase()==='r'&&!['INPUT','SELECT','TEXTAREA'].includes(document.activeElement.tagName)){e.preventDefault();turn();}});
$('help-toggle').onclick=()=>{const open=$('help').hidden;$('help').hidden=!open;$('help-toggle').setAttribute('aria-expanded',String(open));};
function askReset(size){pendingSize=size;$('reset-note').hidden=false;}
$('restart').onclick=()=>askReset(game.board.length);
$('size').onchange=()=>askReset(Number($('size').value));
$('cancel-reset').onclick=()=>{$('reset-note').hidden=true;$('size').value=game.board.length;};
$('confirm-reset').onclick=()=>{game=new Game(pendingSize);cells=game.piece.cells;anchor=null;touchAnchor=null;$('size').value=pendingSize;$('reset-note').hidden=true;render();};
render();
