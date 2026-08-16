import{c as u}from"./main-8jfMmtwN.js";const p=[["Core",["u-install","u-uninstall","u-update","u-upgrade","u-search"]],["Insight",["u-outdated","u-peek","u-info","u-list","u-stats","u-history"]],["Snapshots",["u-export","u-import","u-diff","u-sync"]],["System",["u-doctor","u-clean","u-help"]]],h=t=>{for(const[s,n]of p)if(n.includes(t))return s;return"Other"},i=t=>t.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"),d=document.getElementById("commands-root"),l=document.getElementById("cmd-search"),f=document.getElementById("cmd-count"),m=t=>{const s=t.trim().toLowerCase(),n=u.commands.filter(e=>!s||e.name.toLowerCase().includes(s)||e.description.toLowerCase().includes(s)||e.help.toLowerCase().includes(s));if(f.textContent=`${n.length}/${u.commands.length}`,n.length===0){d.innerHTML=`<div class="empty-note">Nothing matches “${i(t)}”.</div>`;return}const o=new Map;for(const e of n){const c=h(e.name);o.has(c)||o.set(c,[]),o.get(c).push(e)}let a="";for(const[e,c]of p)if(o.has(e)){a+=`<div class="cmd-group-title">${e}</div>`;for(const r of o.get(e))a+=`
      <div class="cmd-card reveal visible">
        <div class="head">
          <span class="name">${r.name}</span>
          <span class="tag">${e}</span>
        </div>
        <p class="desc">${i(r.description)}</p>
        <div class="code-block"><pre>${i(r.help)}</pre></div>
      </div>`}d.innerHTML=a};d&&(m(""),l.addEventListener("input",()=>m(l.value)));
