import test from 'node:test';
import assert from 'node:assert/strict';
import {Game,PIECES,createBoard,rotate,symmetryStates,placement,legalMoves,makeBag} from './rules.js';
const blank=()=>Array.from({length:9},()=>Array(9).fill(null));
test('the seven tetrominoes each have four distinct cells and retain shape after four turns',()=>{
  assert.equal(Object.keys(PIECES).length,7);
  const key=c=>c.map(p=>p.join(',')).sort().join(';');
  for(const piece of Object.values(PIECES)){
    assert.equal(new Set(piece.cells.map(p=>p.join(','))).size,4);
    let c=piece.cells;for(let i=0;i<4;i++)c=rotate(c);
    assert.equal(key(c),key(piece.cells));
  }
  assert.equal(new Set(makeBag()).size,7);
});
test('center seed supports all seven symmetries on both sizes',()=>{
  for(const n of [9,11])assert.ok(symmetryStates(createBoard(n)).every(s=>s.possible&&s.complete));
});
test('an asymmetric half-pattern remains possible; conflicting colors destroy a reflection',()=>{
  const b=blank(); b[2][1]='green';
  assert.equal(symmetryStates(b)[0].possible,true);
  assert.equal(symmetryStates(b)[0].complete,false);
  b[2][7]='yellow';assert.equal(symmetryStates(b)[0].possible,false);
  b[2][7]='green';assert.equal(symmetryStates(b)[0].complete,true);
});
test('quarter turns detect color conflicts separated by empty cells in the orbit',()=>{
  const b=blank(); b[1][2]='green'; b[7][6]='yellow';
  assert.equal(symmetryStates(b)[4].possible,false);
  assert.equal(symmetryStates(b)[6].possible,false);
});
test('placement requires bounds, empty space and contact, including corners',()=>{
  const b=createBoard(); const p=PIECES.O;
  assert.equal(placement(b,p.cells,p.color,8,8).ok,false);
  assert.equal(placement(b,p.cells,p.color,4,4).ok,false);
  assert.equal(placement(b,p.cells,p.color,0,0).ok,false);
  assert.equal(placement(b,p.cells,p.color,2,2).ok,true);
  assert.equal(b[2][2],null);
});
test('a move that destroys every possible symmetry is rejected',()=>{
  const b=blank();b.forEach(row=>row.fill('green'));b[1][2]=null;
  assert.ok(symmetryStates(b).some(s=>s.possible));
  assert.equal(placement(b,[[0,0]],'yellow',2,1).ok,false);
});
test('undo restores board and incoming piece, retaining only three recent placements',()=>{
  const game=new Game();const snapshots=[];
  for(let i=0;i<4;i++){
    snapshots.push({board:structuredClone(game.board),piece:game.queue[game.index]});
    const move=legalMoves(game.board,game.piece)[0];assert.ok(move);
    assert.equal(game.place(move.cells,move.x,move.y).ok,true);
  }
  assert.equal(game.history.length,3);
  for(let i=3;i>=1;i--){
    assert.equal(game.undo(),true);assert.deepEqual(game.board,snapshots[i].board);assert.equal(game.queue[game.index],snapshots[i].piece);
  }
  assert.equal(game.undo(),false);assert.equal(game.moves,1);
});
test('a full board has no legal placements and ends the game',()=>{
  const game=new Game();game.board.forEach(r=>r.fill('green'));
  assert.equal(game.over,true);assert.equal(legalMoves(game.board,game.piece).length,0);
});
