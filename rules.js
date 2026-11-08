export const PIECES = {
  I: { color: 'green', cells: [[0,0],[1,0],[2,0],[3,0]] },
  O: { color: 'green', cells: [[0,0],[1,0],[0,1],[1,1]] },
  S: { color: 'green', cells: [[1,0],[2,0],[0,1],[1,1]] },
  T: { color: 'yellow', cells: [[0,0],[1,0],[2,0],[1,1]] },
  J: { color: 'yellow', cells: [[0,0],[0,1],[1,1],[2,1]] },
  L: { color: 'yellow', cells: [[2,0],[0,1],[1,1],[2,1]] },
  Z: { color: 'yellow', cells: [[0,0],[1,0],[1,1],[2,1]] },
};
export const SYMMETRIES = [
  { name:'Vertical', icon:'↔', map:(x,y,n)=>[n-1-x,y] },
  { name:'Horizontal', icon:'↕', map:(x,y,n)=>[x,n-1-y] },
  { name:'Main diagonal', icon:'⤡', map:(x,y)=>[y,x] },
  { name:'Other diagonal', icon:'⤢', map:(x,y,n)=>[n-1-y,n-1-x] },
  { name:'90° rotation', icon:'↻', map:(x,y,n)=>[n-1-y,x] },
  { name:'180° rotation', icon:'↶', map:(x,y,n)=>[n-1-x,n-1-y] },
  { name:'270° rotation', icon:'↺', map:(x,y,n)=>[y,n-1-x] },
];
export function createBoard(n=9) {
  const b=Array.from({length:n},()=>Array(n).fill(null));
  b[Math.floor(n/2)][Math.floor(n/2)]='green'; return b;
}
export function rotate(cells) {
  const turned=cells.map(([x,y])=>[-y,x]);
  const minX=Math.min(...turned.map(p=>p[0])), minY=Math.min(...turned.map(p=>p[1]));
  return turned.map(([x,y])=>[x-minX,y-minY]);
}
export function symmetryStates(board) {
  const n=board.length;
  return SYMMETRIES.map(({map})=>{
    let possible=true, complete=true;
    for(let y=0;y<n;y++) for(let x=0;x<n;x++) {
      // Inspect the entire orbit: essential for quarter turns with empty intermediate cells.
      let xx=x, yy=y, colors=new Set();
      do { if(board[yy][xx]) colors.add(board[yy][xx]); [xx,yy]=map(xx,yy,n); } while(xx!==x || yy!==y);
      if(colors.size>1) possible=false;
      const [mx,my]=map(x,y,n);
      if(board[y][x]!==board[my][mx]) complete=false;
    }
    return {possible,complete};
  });
}
export function placement(board,cells,color,x,y) {
  const n=board.length, targets=cells.map(([dx,dy])=>[x+dx,y+dy]);
  if(targets.some(([a,b])=>a<0||b<0||a>=n||b>=n)) return {ok:false,reason:'Keep the whole piece inside the garden.'};
  if(targets.some(([a,b])=>board[b][a])) return {ok:false,reason:'Choose empty squares for your piece.'};
  if(!targets.some(([a,b])=>[-1,0,1].some(dy=>[-1,0,1].some(dx=>board[b+dy]?.[a+dx])))) return {ok:false,reason:'Touch an existing tile, along an edge or at a corner.'};
  const next=board.map(row=>row.slice()); targets.forEach(([a,b])=>next[b][a]=color);
  if(!symmetryStates(next).some(s=>s.possible)) return {ok:false,reason:'This closes every path to symmetry. Try another position.'};
  return {ok:true,board:next};
}
export function legalMoves(board,piece) {
  let cells=piece.cells; const moves=[];
  for(let r=0;r<4;r++,cells=rotate(cells)) for(let y=0;y<board.length;y++) for(let x=0;x<board.length;x++) {
    if(placement(board,cells,piece.color,x,y).ok) moves.push({x,y,rotation:r,cells});
  }
  return moves;
}
export function makeBag(random=Math.random) {
  const bag=Object.keys(PIECES);
  for(let i=bag.length-1;i>0;i--) { const j=Math.floor(random()*(i+1)); [bag[i],bag[j]]=[bag[j],bag[i]]; }
  return bag;
}
export class Game {
  constructor(size=9) { this.board=createBoard(size); this.queue=makeBag(); this.index=0; this.history=[]; this.moves=0; }
  get piece() { return PIECES[this.queue[this.index]]; }
  get over() { return legalMoves(this.board,this.piece).length===0; }
  place(cells,x,y) {
    const result=placement(this.board,cells,this.piece.color,x,y);
    if(!result.ok) return result;
    this.history.push({board:this.board,index:this.index,moves:this.moves});
    if(this.history.length>3) this.history.shift();
    this.board=result.board; this.moves++; this.index++;
    if(this.index>=this.queue.length) this.queue.push(...makeBag());
    return result;
  }
  undo() { const previous=this.history.pop(); if(!previous) return false; Object.assign(this,previous); return true; }
}
