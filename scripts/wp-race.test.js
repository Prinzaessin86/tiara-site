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
function ghApi(){
  const snapshot = labels.slice();
  return new Promise(res=>setTimeout(()=>res({
    ok:true, json:async()=>snapshot.map(n=>({name:n, description:'name of '+n}))
  }), 40));
}
${shipped}
module.exports = async function(){
  const first = loadWorkPackages();          // a background read starts
  await new Promise(r=>setTimeout(r,10));    // ...and is still in flight
  labels.push('WP-0002');                    // a package is created meanwhile
  await loadWorkPackages(true);              // the forced read a creator awaits
  const ids = (_wpIndex||[]).map(e=>e.id);
  await first;
  return ids;
};
`;
const tmp = path.join(__dirname, '.wprace.gen.js');
fs.writeFileSync(tmp, harness);
(async () => {
  try{
    const ids = await require(tmp)();
    const pass = ids.includes('WP-0002');
    console.log('index after the forced read:', ids.join(', ') || '(empty)');
    console.log(pass
      ? 'PASS: the forced read waited, so a package created mid-flight is there'
      : 'FAIL: the forced read returned early and the new package is missing');
    process.exitCode = pass ? 0 : 1;
  } finally { fs.unlinkSync(tmp); }
})();
