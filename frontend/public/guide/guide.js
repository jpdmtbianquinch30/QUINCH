// Script du guide utilisateur (/guide/). Extrait de la page : la CSP de production
// (script-src 'self') interdit les scripts intégrés à la page.
(function(){
'use strict';
var root=document.documentElement,TK='quinch_guide_theme';
function $(s,c){return (c||document).querySelector(s)}
function $$(s,c){return [].slice.call((c||document).querySelectorAll(s))}
var reduce=window.matchMedia&&matchMedia('(prefers-reduced-motion:reduce)').matches;

/* theme */
try{var st=localStorage.getItem(TK);if(st==='dark'||st==='light')root.setAttribute('data-theme',st)}catch(e){}
$('#theme').addEventListener('click',function(){
 var cur=root.getAttribute('data-theme')||(matchMedia('(prefers-color-scheme:light)').matches?'light':'dark');
 var nx=cur==='light'?'dark':'light';root.setAttribute('data-theme',nx);
 try{localStorage.setItem(TK,nx)}catch(e){}
});

var secs=$$('main section[id]');
var grps=$$('main .grp');

/* anchors on headings */
var used={};
$$('[id]').forEach(function(e){used[e.id]=1});
function slug(t){return t.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'').slice(0,50)||'section'}
$$('main h2,main h3').forEach(function(h){
 if(h.closest('.pc')||h.closest('.sheet'))return;
 var tgt=h.id;
 if(!tgt){
  var sec=h.closest('section');
  if(h.tagName==='H2'&&sec)tgt=sec.id;
  else{var b=(sec?sec.id+'-':'')+slug(h.textContent),n=b,i=2;while(used[n]){n=b+'-'+i++}tgt=n;used[n]=1;h.id=n}
 }
 if(!tgt)return;
 var btn=document.createElement('button');
 btn.type='button';btn.className='anchor';btn.setAttribute('aria-label','Copier le lien vers cette section');btn.title='Copier le lien';btn.textContent='🔗';
 btn.addEventListener('click',function(ev){
  ev.preventDefault();
  var url=location.href.split('#')[0]+'#'+tgt;
  function ok(){btn.classList.add('done');btn.textContent='✓';setTimeout(function(){btn.classList.remove('done');btn.textContent='🔗'},1600)}
  function fb(){var ta=document.createElement('textarea');ta.value=url;ta.style.position='fixed';ta.style.opacity='0';document.body.appendChild(ta);ta.select();try{document.execCommand('copy');ok()}catch(e){window.prompt('Copiez ce lien :',url)}document.body.removeChild(ta)}
  if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(url).then(ok,fb)}else fb();
  try{history.replaceState(null,'','#'+tgt)}catch(e){}
 });
 h.appendChild(btn);
});

/* deep link */
function reveal(id,smooth){
 if(!id)return;
 var el=null;try{el=document.getElementById(decodeURIComponent(id))}catch(e){}
 if(!el)return;
 if(el.classList.contains('hide')||(el.closest&&el.closest('.hide'))){clearSearch()}
 var p=el;
 while(p&&p!==document.body){if(p.tagName==='DETAILS')p.open=true;p=p.parentElement}
 if(el.tagName==='DETAILS')el.open=true;
 var box=el.closest('section')||el;
 el.scrollIntoView({behavior:(smooth&&!reduce)?'smooth':'auto',block:'start'});
 box.classList.remove('target-flash');void box.offsetWidth;box.classList.add('target-flash');
 setTimeout(function(){box.classList.remove('target-flash')},2600);
 if(typeof el.focus==='function'){el.setAttribute('tabindex','-1');try{el.focus({preventScroll:true})}catch(e){}}
}
window.addEventListener('hashchange',function(){reveal(location.hash.slice(1),true)});
$$('a[href^="#"]').forEach(function(a){
 a.addEventListener('click',function(){
  var id=a.getAttribute('href').slice(1);
  if(id&&id===location.hash.slice(1)){setTimeout(function(){reveal(id,true)},0)}
  if(a.closest('.sheet'))closeSheet();
 });
});

/* search */
var qi=$('#q'),qc=$('#qclear'),nores=$('#nores');
function unmark(){
 $$('mark[data-h]').forEach(function(m){var p=m.parentNode;p.replaceChild(document.createTextNode(m.textContent),m);p.normalize()});
}
function markIn(node,q){
 var w=document.createTreeWalker(node,NodeFilter.SHOW_TEXT,{acceptNode:function(n){
  var p=n.parentNode;if(!p||/^(SCRIPT|STYLE|BUTTON|MARK)$/.test(p.nodeName))return NodeFilter.FILTER_REJECT;
  return n.nodeValue.toLowerCase().indexOf(q)>-1?NodeFilter.FILTER_ACCEPT:NodeFilter.FILTER_REJECT}});
 var list=[],n;while((n=w.nextNode()))list.push(n);
 list.slice(0,60).forEach(function(t){
  var s=t.nodeValue,l=s.toLowerCase(),i=l.indexOf(q);
  if(i<0)return;
  var f=document.createDocumentFragment(),last=0;
  while(i>-1){
   f.appendChild(document.createTextNode(s.slice(last,i)));
   var m=document.createElement('mark');m.setAttribute('data-h','1');m.textContent=s.slice(i,i+q.length);f.appendChild(m);
   last=i+q.length;i=l.indexOf(q,last);
  }
  f.appendChild(document.createTextNode(s.slice(last)));
  t.parentNode.replaceChild(f,t);
 });
}
function norm(s){return s.toLowerCase()}
function filter(){
 var q=norm(qi.value.trim());
 unmark();
 qc.classList.toggle('hide',!qi.value);
 var shown=0;
 secs.forEach(function(s){
  var ok=!q||norm(s.textContent).indexOf(q)>-1;
  s.classList.toggle('hide',!ok);
  if(ok){shown++;if(q.length>1){markIn(s,q);$$('details',s).forEach(function(d){d.open=!!d.querySelector('mark[data-h]')})}}
 });
 if(!q)$$('main details').forEach(function(d){d.open=false});
 grps.forEach(function(g){
  var n=g.nextElementSibling,any=false;
  while(n&&!n.classList.contains('grp')){if(n.tagName==='SECTION'&&!n.classList.contains('hide'))any=true;n=n.nextElementSibling}
  g.classList.toggle('hide',!any);
 });
 $('#quick').classList.toggle('hide',!!q);
 nores.classList.toggle('hide',shown>0);
 $$('#side a[href],#chips a,#slist a').forEach(function(a){
  var id=a.getAttribute('href').slice(1),s=document.getElementById(id);
  a.classList.toggle('hide',!!(s&&s.classList.contains('hide')));
 });
}
function clearSearch(){qi.value='';filter()}
var tmr;qi.addEventListener('input',function(){clearTimeout(tmr);tmr=setTimeout(filter,120)});
qc.addEventListener('click',function(){clearSearch();qi.focus()});

/* scroll spy */
var links=$$('#side a[href^="#"]'),chips=$$('#chips a'),sl=$$('#slist a'),curEl=$('#cur');
var titles={};secs.forEach(function(s){var h=$('h2',s);titles[s.id]=h?h.firstChild.textContent.trim():s.id});
function setOn(id){
 [links,chips,sl].forEach(function(arr){arr.forEach(function(a){
  var on=a.getAttribute('href')==='#'+id;a.classList.toggle('on',on);
  if(on)a.setAttribute('aria-current','true');else a.removeAttribute('aria-current');
 })});
 curEl.textContent=titles[id]||'';
 var c=chips.filter(function(a){return a.classList.contains('on')})[0];
 var cb=$('#chips');
 if(c&&cb&&cb.offsetParent!==null){var l=c.offsetLeft-cb.clientWidth/2+c.clientWidth/2;cb.scrollTo?cb.scrollTo({left:l,behavior:reduce?'auto':'smooth'}):cb.scrollLeft=l}
 var sd=$('#side'),a2=links.filter(function(a){return a.classList.contains('on')})[0];
 if(a2&&sd&&sd.offsetParent!==null){var r=a2.getBoundingClientRect(),R=sd.getBoundingClientRect();if(r.top<R.top+40||r.bottom>R.bottom-20)sd.scrollTop+=r.top-R.top-R.height/3}
}
if('IntersectionObserver' in window){
 var vis={};
 var io=new IntersectionObserver(function(es){
  es.forEach(function(e){vis[e.target.id]=e.isIntersecting?e.intersectionRatio+0.0001:0});
  var best=null,bv=0;secs.forEach(function(s){if(vis[s.id]>bv){bv=vis[s.id];best=s.id}});
  if(best)setOn(best);
 },{rootMargin:'-120px 0px -55% 0px',threshold:[0,.05,.2,.5,1]});
 secs.forEach(function(s){io.observe(s)});
}
var prog=$('#prog'),tt=$('#totop'),tick=false;
function onScroll(){
 if(tick)return;tick=true;
 requestAnimationFrame(function(){
  var h=document.documentElement,max=h.scrollHeight-h.clientHeight;
  prog.style.width=(max>0?Math.min(100,h.scrollTop/max*100):0)+'%';
  tt.classList.toggle('show',h.scrollTop>700);tick=false;
 });
}
window.addEventListener('scroll',onScroll,{passive:true});onScroll();
tt.addEventListener('click',function(){window.scrollTo({top:0,behavior:reduce?'auto':'smooth'})});

/* bottom sheet */
var sheet=$('#sheet'),sbg=$('#sbg'),fab=$('#fab'),lastF=null;
function openSheet(){lastF=document.activeElement;sheet.classList.add('open');sbg.classList.add('open');sheet.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';var a=$('#slist a.on')||$('#slist a');if(a){a.focus();a.scrollIntoView({block:'center'})}}
function closeSheet(){sheet.classList.remove('open');sbg.classList.remove('open');sheet.setAttribute('aria-hidden','true');document.body.style.overflow='';if(lastF&&lastF.focus)try{lastF.focus({preventScroll:true})}catch(e){}}
fab.addEventListener('click',openSheet);sbg.addEventListener('click',closeSheet);$('#sclose').addEventListener('click',closeSheet);
document.addEventListener('keydown',function(e){
 if(e.key==='Escape'&&sheet.classList.contains('open'))closeSheet();
 if(e.key==='Tab'&&sheet.classList.contains('open')){
  var f=$$('a,button',sheet).filter(function(x){return x.offsetParent!==null});if(!f.length)return;
  var first=f[0],last=f[f.length-1];
  if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus()}
  else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}
 }
 if(e.key==='/'&&!/INPUT|TEXTAREA/.test((document.activeElement||{}).nodeName||'')){e.preventDefault();qi.focus()}
});

/* print : open all details */
var wasOpen=[];
window.addEventListener('beforeprint',function(){wasOpen=$$('details').map(function(d){return d.open});$$('details').forEach(function(d){d.open=true})});
window.addEventListener('afterprint',function(){$$('details').forEach(function(d,i){d.open=!!wasOpen[i]})});

/* ───── badges live ───── */
var ZONES={feed:'Accueil',explorer:'Explorer',video_feed:'Feed vidéo',product_detail:'Détail produit',seller_profile:'Profil vendeur',messages:'Messages',search:'Recherche',notifications:'Notifications',rankings:'Classement',profile:'Mon profil'};
function ruleText(rule,th){
 var n=(th===null||th===undefined||th==='')?null:Number(th);
 switch(rule){
  case 'premium':return 'Abonnement Premium actif';
  case 'kyc_verified':return 'Identité vérifiée (KYC)';
  case 'sales_completed':return (n!==null?n:'Plusieurs')+' vente'+(n>1?'s':'')+' finalisée'+(n>1?'s':'');
  case 'account_age_days':return (n!==null?n:'Plusieurs')+' jour'+(n>1?'s':'')+' d’ancienneté';
  case 'trust_score':return 'Score de confiance ≥ '+(n!==null?n:'seuil')+' %';
 }
 return '';
}
function okColor(c){return typeof c==='string'&&/^#[0-9a-f]{3,8}$/i.test(c)?c:'#6366f1'}
function el(tag,cls,txt){var e=document.createElement(tag);if(cls)e.className=cls;if(txt!==undefined&&txt!==null)e.textContent=txt;return e}
function normList(data){
 var b=data&&data.badges!==undefined?data.badges:data;
 if(data&&data.data&&data.badges===undefined)b=data.data.badges||data.data;
 var out=[];
 if(Array.isArray(b))out=b.slice();
 else if(b&&typeof b==='object')Object.keys(b).forEach(function(k){var v=b[k];if(v&&typeof v==='object'){if(!v.key)v.key=k;out.push(v)}});
 return out.filter(function(x){return x&&typeof x==='object'&&x.name});
}
function card(b){
 var c=el('article','bcard'),h=el('div','bhead'),i=el('span','bi');
 i.style.setProperty('--c',okColor(b.color));i.setAttribute('aria-hidden','true');
 i.appendChild(el('span','ico material-icons',String(b.icon||'verified')));
 i.appendChild(el('span','ltr',String(b.name).trim().charAt(0).toUpperCase()));
 h.appendChild(i);
 var t=el('div');t.appendChild(el('div','bname',b.name));
 var auto=b.mode==='auto';
 t.appendChild(el('span','pill '+(auto?'auto':'man'),auto?'Automatique':'Attribué par l’équipe'));
 h.appendChild(t);c.appendChild(h);
 if(b.description)c.appendChild(el('p',null,b.description));
 var how=b.how_to_get||'';
 if(auto&&b.auto_rule){var rt=ruleText(b.auto_rule,b.auto_threshold);if(rt)how=how?how+' ('+rt+')':rt}
 if(how){var d=el('div','bhow');d.appendChild(el('strong',null,'Comment l’obtenir : '));d.appendChild(document.createTextNode(how));c.appendChild(d)}
 var z=Array.isArray(b.zones)?b.zones:[];
 if(z.length){var zw=el('div'),zl=el('div','muted','Où il s’affiche :');zl.style.marginBottom='4px';zw.appendChild(zl);
  var zz=el('div','bzones');z.forEach(function(k){zz.appendChild(el('span','pill',ZONES[k]||String(k)))});zw.appendChild(zz);c.appendChild(zw)}
 return c;
}
function fetchJson(url,ms){
 return new Promise(function(res,rej){
  var done=false,ctl=('AbortController' in window)?new AbortController():null;
  var t=setTimeout(function(){if(!done){done=true;if(ctl)ctl.abort();rej(new Error('timeout'))}},ms);
  fetch(url,{headers:{'Accept':'application/json'},signal:ctl?ctl.signal:undefined}).then(function(r){
   if(!r.ok)throw new Error('http '+r.status);
   var ct=r.headers.get('content-type')||'';if(ct.indexOf('json')<0)throw new Error('not json');
   return r.json();
  }).then(function(j){if(!done){done=true;clearTimeout(t);res(j)}},function(e){if(!done){done=true;clearTimeout(t);rej(e)}});
 });
}
function loadBadges(){
 var box=$('#badges-live'),fbk=$('#badges-fallback');
 if(!box)return;
 var sk=el('div','bgrid');for(var i=0;i<3;i++)sk.appendChild(el('div','skel'));
 box.appendChild(sk);
 var apis=['/api/v1','https://api.quinch.sn/api/v1'],idx=0;
 function fail(){box.textContent='';box.classList.add('hide');fbk.classList.remove('hide')}
 function next(){
  if(idx>=apis.length)return fail();
  var u=apis[idx++]+'/badges/definitions';
  fetchJson(u,6000).then(function(j){
   var l=normList(j);
   if(!l.length)return next();
   box.textContent='';var g=el('div','bgrid');l.forEach(function(b){g.appendChild(card(b))});box.appendChild(g);
  },next);
 }
 next();
}
function checkIcons(){
 function bad(){root.classList.add('noicons')}
 try{
  if(document.fonts&&document.fonts.load){
   var to=setTimeout(function(){if(!document.fonts.check('24px "Material Icons"'))bad()},4000);
   document.fonts.load('24px "Material Icons"','verified').then(function(f){clearTimeout(to);if(!f||!f.length||!document.fonts.check('24px "Material Icons"'))bad()},function(){clearTimeout(to);bad()});
  }else bad();
 }catch(e){bad()}
 var lk=document.querySelector('link[href*="fonts.googleapis.com"]');
 if(lk)lk.addEventListener('error',bad);
}
checkIcons();loadBadges();

/* initial deep link */
if(location.hash.length>1){
 var go=function(){
  var id=location.hash.slice(1),el=document.getElementById(id),moved=false;
  if(!el)return;
  /* Le contenu charge encore (badges en direct, polices) et décale la page : on garde la cible
     alignée tant que l'utilisateur n'a pas lui-même fait défiler, pendant 4 s maximum. */
  var stop=function(){moved=true};
  ['wheel','touchstart','keydown','mousedown'].forEach(function(ev){window.addEventListener(ev,stop,{once:true,passive:true})});
  var html=document.documentElement,prev=html.style.scrollBehavior;
  html.style.scrollBehavior='auto';
  reveal(id,false);
  var align=function(){if(!moved){var t=document.getElementById(id);if(t)t.scrollIntoView({behavior:'auto',block:'start'})}};
  var ro=window.ResizeObserver?new ResizeObserver(align):null;
  if(ro)ro.observe(document.body);
  setTimeout(function(){if(ro)ro.disconnect();html.style.scrollBehavior=prev},4000);
 };
 if(document.readyState==='complete')setTimeout(go,60);else window.addEventListener('load',function(){setTimeout(go,60)});
}
})();

// Ancien attribut onerror du logo (interdit par la CSP) : masque le logo s'il ne charge pas.
(function () {
  var img = document.querySelector('.brand img');
  if (!img) return;
  var hide = function () { img.style.display = 'none'; };
  img.addEventListener('error', hide);
  if (img.complete && img.naturalWidth === 0) hide();
})();
