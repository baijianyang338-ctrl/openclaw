const $=s=>document.querySelector(s),$$=s=>[...document.querySelectorAll(s)];
const metricDefs=[['faceRatio','脸部长宽比'],['jawRatio','下颌 / 颧骨'],['upperThird','上庭长度占比'],['lowerThird','下庭长度占比'],['eyeGap','眼间距占脸宽'],['eyeAspect','双眼长宽比'],['noseWidth','鼻翼宽度占比'],['noseLength','鼻长占比'],['lipRatio','唇厚 / 嘴宽']];
let templates=[],creators=[],faceLandmarker=null,imageFile=null,stream=null,current=[];
const metrics=$('#metrics');metrics.innerHTML=metricDefs.map(([k,n])=>`<div class="metric"><span>${n}</span><b data-metric="${k}">—</b></div>`).join('');
function toast(t){const e=$('#toast');e.textContent=t;e.classList.add('show');clearTimeout(e._t);e._t=setTimeout(()=>e.classList.remove('show'),2200)}
function setNet(type,text){$('#netDot').className=type;$('#netText').textContent=text}
const creatorFocusCycles=[
  [['日常妆容','新手教程','平价好物'],'适合学习日常可复制妆容和新手步骤'],
  [['底妆测评','持妆技巧','产品避坑'],'适合比较底妆表现、持妆方法和产品选择'],
  [['眼妆教程','脸型修饰','上镜妆'],'适合学习眼型调整、修容和镜头妆结构'],
  [['风格仿妆','色彩搭配','妆容灵感'],'适合寻找风格化妆容与配色灵感'],
  [['护肤彩妆','成分解析','消费建议'],'适合补充产品功效、成分与消费判断'],
  [['明星妆拆解','修容高光','氛围妆'],'适合学习明星妆拆解和面部视觉重心调整']
];
const creatorFocusOverrides={
  '马宝儿':[['实用妆教','日常妆容','高互动教程'],'适合跟练快速、实用的日常妆容'],
  '陈圆圆超可爱':[['日常妆容','平价好物','亲和妆感'],'适合学习亲和、易复制的日常美妆'],
  '小团圆剧场':[['创意仿妆','主题妆容','剧情表达'],'适合寻找创意仿妆与主题妆容灵感'],
  '灵霖七':[['古风妆容','国货美妆','东方审美'],'适合学习古风与东方妆容表达'],
  '九歌':[['欧美妆','轮廓妆','眼妆'],'适合学习高轮廓感和欧美眼妆'],
  '氧化菊':[['彩妆测评','护肤科普','产品对比'],'适合了解彩妆产品表现和使用差异'],
  '拜托辣油':[['油皮底妆','控油持妆','产品测评'],'适合油皮用户学习控油与持妆'],
  '李佳琦Austin':[['口红试色','产品测评','选品建议'],'适合查看热门彩妆、色号和产品卖点'],
  '骆王宇':[['护肤成分','产品测评','消费避坑'],'适合学习护肤产品逻辑和消费避坑'],
  '豆豆Babe':[['眼妆','仿妆','高完成度全妆'],'适合学习高完成度眼妆和全妆流程'],
  '仙姆SamChak':[['眼妆技巧','明星妆容','专业妆教'],'适合学习精细眼妆和专业化妆方法'],
  '毛戈平':[['东方骨相','光影修容','专业教育'],'适合学习东方骨相与光影塑造'],
  '唐毅TangYi':[['中国妆','粉彩妆','明星妆教'],'适合学习东方审美和专业明星妆容'],
  '易梦玲':[['氛围妆','镜头表现','妆容灵感'],'适合观察上镜氛围、色彩和整体造型'],
  'Angel Z':[['熟龄护肤','抗衰护理','生活方式'],'适合熟龄肌护肤和状态管理参考'],
  '橙子阿姨':[['熟龄护肤','气色管理','生活方式'],'适合查看熟龄肌护理和气色管理内容'],
  '许医生的变美日记':[['皮肤科普','科学护肤','变美建议'],'适合补充皮肤与科学护肤知识']
};
function makeDirectoryCreator(name,platform,i){const [focus,bestFor]=creatorFocusOverrides[name]||creatorFocusCycles[i%creatorFocusCycles.length];const search=platform==='抖音'?`https://www.douyin.com/search/${encodeURIComponent(name)}`:`https://www.xiaohongshu.com/search_result?keyword=${encodeURIComponent(name)}`;return{id:`${platform==='抖音'?'dy':'xhs'}-${i+1}-${encodeURIComponent(name)}`,name,platforms:[platform],handle:`${platform}搜索：${name}`,region:'中国',focus,bestFor,url:search,source:`${platform}公开搜索入口；账号名称与内容以平台实时结果为准`}}
async function loadData(){try{const rs=await Promise.all(['./data/templates.json','./data/creators.json','./data/creators-cn.json'].map(u=>fetch(u)));if(rs.some(r=>!r.ok))throw 0;const [t,base,cn]=await Promise.all(rs.map(r=>r.json()));templates=t;creators=[...base,...cn.douyin.map((n,i)=>makeDirectoryCreator(n,'抖音',i)),...cn.xiaohongshu.map((n,i)=>makeDirectoryCreator(n,'小红书',i))];renderTemplateFilters();renderTemplates();renderPlatformFilters();renderCreators()}catch{toast('网站数据加载失败，请刷新页面')}}
async function initModel(){
  if(faceLandmarker)return true;
  if(!navigator.onLine){setNet('bad','当前离线');return false}
  const routes=[
    {
      name:'国内镜像',
      module:'https://cdn.jsdmirror.com/npm/@mediapipe/tasks-vision@0.10.14/+esm',
      wasm:'https://cdn.jsdmirror.com/npm/@mediapipe/tasks-vision@0.10.14/wasm',
      model:'https://cdn.jsdmirror.com/gh/Zam-Imam/Gaze-Tracking-MediaPipe@main/face_landmarker.task'
    },
    {
      name:'国际备用线路',
      module:'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/+esm',
      wasm:'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm',
      model:'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task'
    }
  ];
  for(const route of routes){
    try{
      setNet('',`正在连接${route.name}`);
      const v=await import(route.module);
      const f=await v.FilesetResolver.forVisionTasks(route.wasm);
      faceLandmarker=await v.FaceLandmarker.createFromOptions(f,{baseOptions:{modelAssetPath:route.model,delegate:'GPU'},runningMode:'IMAGE',numFaces:1,minFaceDetectionConfidence:.55,minFacePresenceConfidence:.55});
      setNet('ok',`${route.name}已连接`);
      return true;
    }catch(e){
      console.warn(`${route.name}加载失败`,e);
      faceLandmarker=null;
    }
  }
  setNet('bad','模型线路均连接失败');
  return false;
}
loadData();initModel();window.addEventListener('online',initModel);window.addEventListener('offline',()=>setNet('bad','当前离线'));
$$('[data-page]').forEach(b=>b.onclick=()=>{$$('[data-page]').forEach(x=>x.classList.remove('active'));b.classList.add('active');['analysis','templates','creators'].forEach(p=>$(`#${p}Page`).classList.toggle('hidden',p!==b.dataset.page));scrollTo({top:0,behavior:'smooth'})});
function setImage(file){if(!file?.type.startsWith('image/'))return toast('请选择图片文件');if(file.size>15*1024*1024)return toast('图片请小于 15MB');imageFile=file;const u=URL.createObjectURL(file);$('#preview').onload=()=>{URL.revokeObjectURL(u);resizeCanvas();clearCanvas()};$('#preview').src=u;$('#fileName').textContent=file.name||'camera.jpg';$('#fileSize').textContent=(file.size/1048576).toFixed(2)+' MB';$('#dropzone').classList.add('hidden');$('#analysisBox').classList.remove('hidden');$('#recommendations').classList.add('hidden');resetMetrics()}
$('#fileInput').onchange=e=>setImage(e.target.files[0]);const dz=$('#dropzone');['dragenter','dragover'].forEach(n=>dz.addEventListener(n,e=>{e.preventDefault();dz.classList.add('drag')}));['dragleave','drop'].forEach(n=>dz.addEventListener(n,e=>{e.preventDefault();dz.classList.remove('drag')}));dz.addEventListener('drop',e=>setImage(e.dataTransfer.files[0]));$('#resetBtn').onclick=()=>{imageFile=null;$('#fileInput').value='';$('#analysisBox').classList.add('hidden');$('#recommendations').classList.add('hidden');$('#dropzone').classList.remove('hidden');clearCanvas()};
function resetMetrics(){metricDefs.forEach(([k])=>$(`[data-metric="${k}"]`).textContent='—');$('#status').className='status';$('#status').textContent='等待分析。首次打开需要联网加载人脸模型。';$('#progress').style.width='0';$('#quality').textContent='结果仅用于妆容结构参考，不构成身份识别或医学判断。'}
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y),clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
function measure(l){const fw=dist(l[234],l[454]),fh=dist(l[10],l[152]),lew=dist(l[33],l[133]),rew=dist(l[362],l[263]),leh=dist(l[159],l[145]),reh=dist(l[386],l[374]);return{faceRatio:fh/fw,jawRatio:dist(l[172],l[397])/fw,upperThird:dist(l[10],l[168])/fh,lowerThird:dist(l[2],l[152])/fh,eyeGap:dist(l[133],l[362])/fw,eyeAspect:(lew/Math.max(leh,.001)+rew/Math.max(reh,.001))/2,noseWidth:dist(l[129],l[358])/fw,noseLength:dist(l[168],l[2])/fh,lipRatio:dist(l[13],l[14])/dist(l[61],l[291]),roll:Math.atan2(l[263].y-l[33].y,l[263].x-l[33].x)*180/Math.PI,yaw:(l[1].x-(l[234].x+l[454].x)/2)/fw*100}}
function brightness(img){const c=document.createElement('canvas'),x=c.getContext('2d',{willReadFrequently:true});c.width=c.height=70;x.drawImage(img,0,0,70,70);const d=x.getImageData(0,0,70,70).data;let s=0;for(let i=0;i<d.length;i+=4)s+=d[i]*.2126+d[i+1]*.7152+d[i+2]*.0722;return s/(d.length/4)}
function resizeCanvas(){const c=$('#overlay'),r=$('#photoStage').getBoundingClientRect();c.width=Math.max(1,Math.round(r.width*devicePixelRatio));c.height=Math.max(1,Math.round(r.height*devicePixelRatio))}window.addEventListener('resize',resizeCanvas);function clearCanvas(){const c=$('#overlay');c.getContext('2d').clearRect(0,0,c.width,c.height)}
function draw(l){resizeCanvas();const c=$('#overlay'),x=c.getContext('2d'),img=$('#preview'),stage=$('#photoStage'),sw=stage.clientWidth,sh=stage.clientHeight,sc=Math.min(sw/img.naturalWidth,sh/img.naturalHeight),dw=img.naturalWidth*sc,dh=img.naturalHeight*sc,ox=(sw-dw)/2,oy=(sh-dh)/2;x.clearRect(0,0,c.width,c.height);x.save();x.scale(devicePixelRatio,devicePixelRatio);x.fillStyle='rgba(109,221,170,.72)';[10,152,234,454,172,397,33,133,362,263,129,358,168,2,61,291,13,14,1].forEach(i=>{x.beginPath();x.arc(ox+l[i].x*dw,oy+l[i].y*dh,2.5,0,Math.PI*2);x.fill()});x.restore()}
function calculate(m){const keys=metricDefs.map(x=>x[0]),scales={faceRatio:.28,jawRatio:.2,upperThird:.12,lowerThird:.14,eyeGap:.1,eyeAspect:1.15,noseWidth:.1,noseLength:.13,lipRatio:.1};return templates.map(t=>{let d=0;keys.forEach((k,i)=>d+=Math.min(1,Math.abs(m[k]-t.target[i])/scales[k]));d/=keys.length;return{...t,match:Math.round(clamp(98-d*34,66,97))}}).sort((a,b)=>b.match-a.match)}
$('#analyzeBtn').onclick=async()=>{if(!imageFile)return;const btn=$('#analyzeBtn');btn.disabled=true;btn.textContent='正在分析…';$('#progress').style.width='30%';try{if(!await initModel())throw Error('在线模型未连接');const img=$('#preview'),r=faceLandmarker.detect(img);$('#progress').style.width='65%';if(!r.faceLandmarks?.length)throw Error('未检测到完整人脸，请更换清晰正脸照片');const l=r.faceLandmarks[0],m=measure(l);draw(l);metricDefs.forEach(([k])=>$(`[data-metric="${k}"]`).textContent=m[k].toFixed(2));const b=brightness(img),a=Math.abs(m.roll),y=Math.abs(m.yaw),issues=[];if(b<65)issues.push('光线偏暗');if(b>225)issues.push('曝光偏亮');if(a>8)issues.push('头部倾斜');if(y>11)issues.push('脸部侧转');$('#status').className='status '+(issues.length?'warn':'ok');$('#status').textContent=issues.length?'已完成，但存在：'+issues.join('、'):'照片质量良好，关键点稳定。';$('#quality').textContent=`亮度 ${Math.round(b)}/255 · 倾斜 ${a.toFixed(1)}° · 左右偏转 ${y.toFixed(1)}%`;current=calculate(m);renderResults();$('#progress').style.width='100%';$('#recommendations').classList.remove('hidden');setTimeout(()=>$('#recommendations').scrollIntoView({behavior:'smooth'}),150)}catch(e){$('#status').className='status bad';$('#status').textContent=e.message;toast(e.message)}finally{btn.disabled=false;btn.textContent='重新分析'}};
function card(t,i,score=false){const q=encodeURIComponent(t.name+' 妆容教程');return`<article class="card"><div class="cover" style="--c1:${t.c1};--c2:${t.c2}"><span class="rank">${score?'TOP '+(i+1):'STYLE '+String(i+1).padStart(2,'0')}</span>${score?`<div class="score">${t.match}<small>% 匹配</small></div>`:''}<span class="category">${t.category}</span></div><div class="card-body"><h3>${t.name}</h3><div class="tags">${t.tags.map(x=>`<span class="tag">${x}</span>`).join('')}</div><p>${t.desc}</p><div class="card-actions"><button class="detail-btn" data-detail="${t.id}">查看步骤</button><a class="search-link" target="_blank" rel="noopener" href="https://www.baidu.com/s?wd=${q}">搜教程</a></div></div></article>`}
function bindDetails(root){root.querySelectorAll('[data-detail]').forEach(b=>b.onclick=()=>{const t=templates.find(x=>x.id===b.dataset.detail);$('#detail').innerHTML=`<p class="eyebrow">${t.tags.join(' · ')}</p><h2>${t.name}</h2><p>${t.desc}</p><h3>复刻步骤</h3><ol>${t.learn.map(x=>`<li>${x}</li>`).join('')}</ol><h3>避坑提示</h3><p>${t.avoid}</p>`;$('#detailDialog').showModal()})}
function renderResults(){const root=$('#resultCards');root.innerHTML=current.slice(0,6).map((t,i)=>card(t,i,true)).join('');bindDetails(root)}
function renderTemplateFilters(){const cats=['全部',...new Set(templates.map(x=>x.category))];$('#categoryFilters').innerHTML=cats.map((x,i)=>`<button class="filter ${i?'':'active'}" data-category="${x}">${x}</button>`).join('');$$('[data-category]').forEach(b=>b.onclick=()=>{$$('[data-category]').forEach(x=>x.classList.remove('active'));b.classList.add('active');renderTemplates()})}
function renderTemplates(){const q=$('#templateSearch').value.trim().toLowerCase(),cat=$('[data-category].active')?.dataset.category||'全部',data=templates.filter(t=>(cat==='全部'||t.category===cat)&&(!q||(t.name+t.tags.join('')+t.desc).toLowerCase().includes(q)));const root=$('#templateCards');root.innerHTML=data.map((t,i)=>card(t,i)).join('');bindDetails(root)}$('#templateSearch').oninput=renderTemplates;
function renderPlatformFilters(){const ps=['全部','YouTube','Instagram','TikTok','抖音','小红书'];$('#platformFilters').innerHTML=ps.map((x,i)=>{const n=x==='全部'?creators.length:creators.filter(c=>c.platforms.includes(x)).length;return`<button class="filter ${i?'':'active'}" data-platform="${x}">${x} ${n}</button>`}).join('');$$('[data-platform]').forEach(b=>b.onclick=()=>{$$('[data-platform]').forEach(x=>x.classList.remove('active'));b.classList.add('active');renderCreators()})}
const initials=n=>n.replace(/[^A-Za-z\u4e00-\u9fa5]/g,'').slice(0,2).toUpperCase()||'MU';
function renderCreators(){const q=$('#creatorSearch').value.trim().toLowerCase(),p=$('[data-platform].active')?.dataset.platform||'全部',data=creators.filter(c=>(p==='全部'||c.platforms.includes(p))&&(!q||(c.name+c.handle+c.focus.join('')+c.bestFor).toLowerCase().includes(q)));$('#creatorCount').textContent=creators.length;$('#creatorCards').innerHTML=data.map(c=>`<article class="creator-card"><div class="creator-top"><div class="avatar">${initials(c.name)}</div><div><div class="creator-name">${c.name}</div><div class="handle">${c.handle}</div></div></div><div class="platforms">${c.platforms.map(x=>`<span class="platform">${x}</span>`).join('')}</div><p><b>内容：</b>${c.focus.join(' · ')}</p><p><b>适合学习：</b>${c.bestFor}</p><div class="source">${c.region} · ${c.source}</div><a class="creator-link" target="_blank" rel="noopener noreferrer" href="${c.url}">打开原平台资料</a></article>`).join('')}$('#creatorSearch').oninput=renderCreators;
$$('.dialog-close').forEach(b=>b.onclick=()=>b.closest('dialog').close());$('#cameraBtn').onclick=async()=>{try{stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:'user'},audio:false});$('#camera').srcObject=stream;$('#cameraDialog').showModal()}catch{toast('请允许摄像头权限，或直接上传照片')}};$('#captureBtn').onclick=()=>{const v=$('#camera'),c=$('#cameraCanvas');c.width=v.videoWidth;c.height=v.videoHeight;c.getContext('2d').drawImage(v,0,0);c.toBlob(b=>{setImage(new File([b],'camera.jpg',{type:'image/jpeg'}));stream?.getTracks().forEach(t=>t.stop());$('#cameraDialog').close()},'image/jpeg',.92)};