// Drives the SHIPPED loadWorkPackages against the race it was getting wrong: a forced read issued
// while another read is in flight must reflect a label written in between. The function body is
// lifted out of index.html at run time rather than copied, so this cannot pass against a stale copy.
//
//   node scripts/wp-race.test.js         the shipped code, exits 0
//   node scripts/wp-race.test.js --old   the flag version it replaced, which exits 1
//
// NOT WIRED INTO `make verify`, deliberately and for now. This repo's gate checks things that are
// already load-bearing elsewhere, and adding a lane is a decision about the gate rather than about
// this bug. It is committed rather than left in a scratch directory because a regression test that
// lives nowhere is the same as no test, which is the failure this estate keeps filing tickets about.
const fs = require('fs');
const path = require('path');
const src = fs.readFileSync('index.html', 'utf8');

const a = src.indexOf('let _wpIndex = null;');
const b = src.indexOf('// Every package, whether or not anything is in it', a);
if (a < 0 || b < 0) throw new Error('could not find loadWorkPackages in index.html');
let shipped = src.slice(a, b);

// The version this replaced, reconstructed to show the test can fail. Same body, flag guard.
const OLD = `
let _wpIndex = null; let _wpIndexErr = ''; let _wpLoading = false;
async function loadWorkPackages(force){
  if(!GH.token) return;
  if(_wpLoading) return;
  if(_wpIndex && !force) return;
  _wpLoading=true;
  try{
    const repos=wpRepos(); const seen={}; const unread=[];
    await Promise.all(repos.map(async or=>{
      const r=await ghApi('/repos/'+or+'/labels?per_page=100');
      (await r.json()).forEach(l=>{ if(!WP_RE.test(l.name||'')) return;
        seen[l.name]=seen[l.name]||{ id:l.name, title:'', repos:[] }; });
    }));
    _wpIndex=Object.keys(seen).map(k=>seen[k]).sort((x,y)=>wpNum(x.id)-wpNum(y.id));
    _wpIndexErr=unread.length?'x':'';
  } finally { _wpLoading=false; }
}
`;
if (process.argv.includes('--old')) shipped = OLD;

const harness = `
const WP_RE = /^WP-\\d+$/;
const wpNum = nm => { const m=/^WP-(\\d+)$/.exec(nm||''); return m?parseInt(m[1],10):0; };
const GH = { token: 'x' };
let labels = ['WP-0001'];
function wpRepos(){ return ['o/r']; }
// Pages the way GitHub does: ?page=N over a flat list, 100 at a time.
function ghApi(path){
  const snapshot = labels.slice();
  const page = parseInt((/[?&]page=(\\d+)/.exec(path)||[])[1] || '1', 10);
  const slice = snapshot.slice((page-1)*100, page*100);
  return new Promise(res=>setTimeout(()=>res({
    ok:true, json:async()=>slice.map(n=>({name:n, description:'name of '+n}))
  }), 40));
}
${shipped}
module.exports = {
  // A forced read issued while another is in flight must reflect a label written in between.
  race: async function(){
    const first = loadWorkPackages();          // a background read starts
    await new Promise(r=>setTimeout(r,10));    // ...and is still in flight
    labels.push('WP-0002');                    // a package is created meanwhile
    await loadWorkPackages(true);              // the forced read a creator awaits
    const ids = (_wpIndex||[]).map(e=>e.id);
    await first;
    return ids;
  },
  // A repo whose WP- labels sort onto page two must still be read. TentaclePit really is like this:
  // 152 labels, most of them migrated Linear ids, WP- sorting after TEN-54.
  paging: async function(){
    labels = []; _wpIndex = null;
    for(let i=1;i<=120;i++) labels.push('TEN-'+String(i).padStart(3,'0'));
    labels.push('WP-0007');                    // label 121, so page two
    await loadWorkPackages(true);
    return (_wpIndex||[]).map(e=>e.id);
  }
};
`;
const tmp = path.join(__dirname, '.wprace.gen.js');
fs.writeFileSync(tmp, harness);
(async () => {
  try{
    const t = require(tmp);
    let bad = 0;

    const raced = await t.race();
    const rOk = raced.includes('WP-0002');
    console.log('race   · index after the forced read:', raced.join(', ') || '(empty)');
    console.log(rOk
      ? '       PASS: the forced read waited, so a package created mid-flight is there'
      : '       FAIL: the forced read returned early and the new package is missing');
    if(!rOk) bad++;

    const paged = await t.paging();
    const pOk = paged.includes('WP-0007');
    console.log('paging · 121 labels, WP- on page two:', paged.join(', ') || '(none found)');
    console.log(pOk
      ? '       PASS: every page was read'
      : '       FAIL: the read stopped at the first hundred, so the package is invisible');
    if(!pOk) bad++;

    process.exitCode = bad ? 1 : 0;
  } finally { fs.unlinkSync(tmp); }
})();
