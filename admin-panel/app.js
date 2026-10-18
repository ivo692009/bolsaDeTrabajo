(() => {
  'use strict';
  const qs = (s, root = document) => root.querySelector(s);
  const asArray = value => value == null ? [] : Array.isArray(value) ? value : [value];
  const queue = qs('#queue');
  const detail = qs('#detail');
  const connection = qs('#connection');
  const token = decodeURIComponent(location.hash.slice(1));
  if (token) {
    sessionStorage.setItem('adminPanelToken', token);
    history.replaceState(null, '', location.pathname + location.search);
  }
  const auth = sessionStorage.getItem('adminPanelToken') || '';
  const state = { snapshot: null, filter: 'reliability', selectedId: null, reviewerId: '' };
  const labels = {
    commission_payment: 'Transferencia', non_completion: 'Trabajo no completado', work_dispute: 'Disputa de trabajo',
    repeated_cancellations: 'Cancelaciones reiteradas', fraud_report: 'Posible fraude',
    onboarding_linkage: 'Alta / perfil relacionado', prohibited_service: 'Servicio prohibido',
    phone_change: 'Cambio de número', professional_deletion: 'Borrado de datos',
    reliability: 'Trabajo no completado'
  };
  const filterTitles = { payments: 'Transferencias', reliability: 'Trabajos y cancelaciones', fraud: 'Fraude y altas', profiles: 'Revisiones de perfiles', services: 'Servicios', resolved: 'Revisiones resueltas' };
  const reasonLabels = { professional_rejected: 'Profesional rechazó', client_cancelled: 'Cliente canceló', professional_cancelled: 'Profesional canceló', no_response: 'Sin respuesta', agreement_not_reached: 'No se acordó el trabajo', work_not_completed: 'Trabajo no completado', expired: 'Oferta vencida', rejected: 'Rechazada', cancelled: 'Cancelada', closed_unconfirmed: 'Cierre sin confirmación', not_connected: 'No hubo conexión', abandoned: 'Abandonada', failed: 'Fallida', not_materialized: 'No concretada', other: 'Otro' };
  const chartTypes = [{ id: 'referred', label: 'Derivaciones', color: '#6c9d7b' }, { id: 'connected', label: 'Conexiones', color: '#39825a' }, { id: 'formalized', label: 'Acordadas', color: '#d19a42' }, { id: 'completed', label: 'Completadas', color: '#377ba1' }];
  const roleForType = type => ['commission_payment', 'professional_deletion'].includes(type) ? 'commission_admin' : ['prohibited_service', 'prohibited_service_policy'].includes(type) ? 'catalog_manager' : 'professional_reliability_admin';
  const escapeText = value => String(value ?? '');
  const showToast = (message, isError = false) => {
    const toast = qs('#toast'); toast.textContent = message; toast.classList.toggle('error', isError); toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 3200);
  };
  async function api(path, options = {}) {
    const response = await fetch(path, { ...options, headers: { 'Content-Type': 'application/json', 'X-Admin-Token': auth, ...(options.headers || {}) } });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(body.error || `Error ${response.status}`);
    return body;
  }
  function group(caseItem) {
    if (caseItem.type === 'commission_payment') return 'payments';
    if (['non_completion', 'repeated_cancellations'].includes(caseItem.type)) return 'reliability';
    if (['fraud_report', 'onboarding_linkage'].includes(caseItem.type)) return 'fraud';
    if (['professional_deletion', 'phone_change'].includes(caseItem.type)) return 'profiles';
    if (['prohibited_service', 'prohibited_service_policy'].includes(caseItem.type)) return 'services';
    return 'reliability';
  }
  function formatDate(value) {
    if (!value) return 'Fecha no informada';
    const date = new Date(value); return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat('es-AR', { dateStyle: 'medium', timeStyle: 'short' }).format(date);
  }
  function textElement(tag, className, text) {
    const node = document.createElement(tag); if (className) node.className = className; node.textContent = escapeText(text); return node;
  }
  function selectedReviewer(role) {
    const admins = asArray(state.snapshot?.admins);
    return admins.find(a => a.id === state.reviewerId && asArray(a.roles).includes(role)) || admins.find(a => asArray(a.roles).includes(role));
  }
  function renderCounts(cases) {
    const pending = asArray(cases).filter(c => c.status === 'pending');
    const counts = { payments: 0, reliability: 0, fraud: 0, profiles: 0, services: 0 };
    pending.forEach(c => counts[group(c)]++);
    qs('#metricPending').textContent = String(pending.length);
    qs('#metricPayments').textContent = String(counts.payments);
    qs('#metricTrust').textContent = String(counts.reliability + counts.fraud);
    qs('#metricProfile').textContent = String(counts.profiles);
    qs('#countPayments').textContent = String(counts.payments);
    qs('#countReliability').textContent = String(counts.reliability);
    qs('#countFraud').textContent = String(counts.fraud);
    qs('#countProfiles').textContent = String(counts.profiles);
    qs('#countServices').textContent = String(counts.services);
  }
  function renderQueue() {
    const all = asArray(state.snapshot?.cases);
    const visible = state.filter === 'resolved' ? asArray(state.snapshot?.resolved) : all.filter(c => group(c) === state.filter);
    const sidebar=qs('.sidebar');sidebar.hidden=state.filter!=='profiles';qs('.workspace').classList.toggle('without-sidebar',state.filter!=='profiles');
    qs('#queueTitle').textContent = filterTitles[state.filter] || 'Revisiones';
    qs('#queueDescription').textContent = state.filter === 'resolved' ? 'Decisiones registradas recientemente.' : 'Ordenadas desde las más antiguas.';
    qs('#queueCount').textContent = String(visible.length);
    queue.replaceChildren();
    if (!visible.length) {
      const empty = textElement('div', 'empty-state', '');
      empty.append(textElement('div', 'empty-icon', '✓'), textElement('strong', '', state.filter === 'resolved' ? 'Todavía no hay decisiones' : 'No hay revisiones pendientes'), textElement('span', '', 'Las revisiones que se registren aparecerán aquí.'));
      queue.append(empty); detail.className = 'detail-panel empty-detail'; detail.innerHTML = '<div class="empty-icon">✓</div><h2>Selecciona una revisión</h2><p class="muted">Aquí verás el detalle, la evidencia disponible y las decisiones permitidas para tu rol.</p>'; return;
    }
    if (!visible.some(c => c.id === state.selectedId)) state.selectedId = visible[0].id;
    const columns={
      payments:[['Tipo',item=>labels[item.type]||item.type],['Profesional',item=>item.professionalId],['Solicitud',item=>item.requestCode||item.requestId],['Importe',item=>item.amount?`ARS ${item.amount}`:'—'],['Fecha',item=>formatDate(item.createdAt)],['Estado',item=>item.status==='pending'?'Pendiente':'Resuelta']],
      reliability:[['Caso',item=>item.title||labels[item.type]||item.type],['Profesional',item=>item.professionalId],['Solicitud',item=>item.requestCode||item.requestId],['Motivo / contexto',item=>item.summary],['Fecha',item=>formatDate(item.createdAt)],['Estado',item=>item.status==='pending'?'Pendiente':'Resuelta']],
      fraud:[['Caso',item=>item.title||labels[item.type]||item.type],['Profesional',item=>item.professionalId],['Solicitud',item=>item.requestCode||item.requestId],['Indicio registrado',item=>item.summary],['Fecha',item=>formatDate(item.createdAt)],['Estado',item=>item.status==='pending'?'Pendiente':'Resuelta']],
      profiles:[['Solicitud de perfil',item=>item.title||labels[item.type]||item.type],['Profesional',item=>item.professionalId],['Solicitud relacionada',item=>item.requestCode||item.requestId],['Fecha',item=>formatDate(item.createdAt)],['Estado',item=>item.status==='pending'?'Pendiente':'Resuelta']],
      services:[['Servicio / caso',item=>item.title||labels[item.type]||item.type],['Profesional',item=>item.professionalId],['Actividad informada',item=>item.summary],['Fecha',item=>formatDate(item.createdAt)],['Estado',item=>item.status==='pending'?'Pendiente':'Resuelta']],
      resolved:[['Caso',item=>item.title||labels[item.type]||item.type],['Categoría',item=>labels[item.type]||item.type],['Profesional',item=>item.professionalId],['Decisión',item=>item.decision],['Revisor',item=>item.reviewerId],['Resuelta el',item=>formatDate(item.reviewedAt)]]
    }[state.filter]||[];
    const wrap=textElement('div','review-table-wrap','');const table=textElement('table','review-table','');const thead=document.createElement('thead'),headRow=document.createElement('tr');
    columns.forEach(([label])=>headRow.append(textElement('th','',label)));headRow.append(textElement('th','table-action-heading','Acción'));thead.append(headRow);table.append(thead);
    const tbody=document.createElement('tbody');
    visible.forEach(item=>{
      const row=document.createElement('tr');row.tabIndex=0;row.setAttribute('aria-selected',String(state.selectedId===item.id));row.classList.toggle('selected',state.selectedId===item.id);
      columns.forEach(([,getValue])=>row.append(textElement('td','',getValue(item)||'—')));
      const actionCell=document.createElement('td');actionCell.className='table-action-cell';const openButton=textElement('button','button button-quiet table-open','Ver caso');openButton.type='button';openButton.addEventListener('click',event=>{event.stopPropagation();selectCase(item.id);});actionCell.append(openButton);row.append(actionCell);
      row.addEventListener('click',()=>selectCase(item.id));row.addEventListener('keydown',event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();selectCase(item.id);}});tbody.append(row);
    });
    table.append(tbody);wrap.append(table);queue.append(wrap);
    renderDetail(visible.find(c => c.id === state.selectedId));
  }
  function setReviewFilter(filter) {
    state.filter=filter;state.selectedId=null;
    document.querySelectorAll('.review-tab').forEach(button=>{const selected=button.dataset.filter===filter;button.classList.toggle('selected',selected);button.setAttribute('aria-selected',String(selected));});
    renderQueue();
  }
  function selectCase(id) { state.selectedId = id; renderQueue(); }
  function decisionOptions(item) {
    if (item.type === 'commission_payment') return [['accepted', 'Confirmar transferencia', 'button-primary'], ['rejected', 'Rechazar comprobante', 'button-danger'], ['inconclusive', 'No concluyente', 'button-quiet']];
    if (['non_completion', 'reliability'].includes(item.type)) return [['attributable_to_professional', 'Atribuible al profesional', 'button-danger'], ['not_attributable_to_professional', 'No atribuible', 'button-primary'], ['inconclusive', 'No concluyente', 'button-quiet']];
    if (item.type === 'work_dispute') return [['reviewed_no_change', 'Registrar revisión · mantener disputa', 'button-primary']];
    if (item.type === 'professional_deletion') return [['approved_anonymized', 'Aprobar borrado', 'button-danger'], ['rejected', 'Rechazar solicitud', 'button-quiet']];
    if (item.type === 'phone_change') return [['approved', 'Aprobar cambio', 'button-primary'], ['rejected', 'Rechazar cambio', 'button-quiet']];
    if (['fraud_report', 'onboarding_linkage', 'repeated_cancellations'].includes(item.type)) return [['substantiated', 'Patrón corroborado', 'button-danger'], ['not_substantiated', 'No corroborado', 'button-primary'], ['inconclusive', 'No concluyente', 'button-quiet']];
    return [['approved', 'Aprobar', 'button-primary'], ['rejected', 'Rechazar', 'button-danger'], ['inconclusive', 'No concluyente', 'button-quiet']];
  }
  function renderDetail(item) {
    if (!item) return;
    detail.className = 'detail-panel'; detail.replaceChildren();
    const header = textElement('div', 'detail-head', '');
    const headCopy = textElement('div', '', ''); headCopy.append(textElement('h2', '', item.title || labels[item.type] || 'Revisión'), textElement('p', 'detail-sub', `${labels[item.type] || item.type} · ${item.status === 'pending' ? 'Pendiente' : 'Resuelta'} · ${formatDate(item.createdAt)}`));
    header.append(headCopy, textElement('span', `tag${item.status === 'pending' ? '' : ' resolved'}`, item.status === 'pending' ? 'Pendiente' : 'Resuelta')); detail.append(header);
    const grid = textElement('div', 'detail-section detail-grid', '');
    [['ID del caso', item.id], ['Profesional', item.professionalId], ['Solicitud', item.requestCode || item.requestId], ['Importe', item.amount ? `ARS ${item.amount}` : '—']].forEach(([label, value]) => { const field=textElement('div','detail-field',''); field.append(textElement('span','',label),textElement('strong','',value || '—')); grid.append(field); });
    detail.append(grid);
    const summary = textElement('section', 'detail-section', ''); summary.append(textElement('h3', '', 'Contexto')); summary.append(textElement('p', '', item.summary || 'No se agregó contexto.')); detail.append(summary);
    if (item.evidencePath) {
      const evidence=textElement('section','detail-section',''); evidence.append(textElement('h3','','Evidencia'));
      const box=textElement('div','evidence-box','Cargando evidencia local…'); evidence.append(box); detail.append(evidence);
      api(`/api/evidence?path=${encodeURIComponent(item.evidencePath)}`, { headers: {} }).then(data => {
        if (data.type?.startsWith('image/')) { box.textContent=''; const img=document.createElement('img'); img.alt='Comprobante local'; img.src=data.url; box.append(img); }
        else { box.textContent=''; const link=document.createElement('a');link.href=data.url;link.target='_blank';link.rel='noopener noreferrer';link.textContent=`Abrir archivo (${data.type})`;box.append(link); }
      }).catch(() => { box.textContent=`No se pudo abrir el comprobante. Ruta registrada: ${item.evidencePath}`; });
    }
    if (item.status !== 'pending') {
      const result=textElement('section','detail-section',''); result.append(textElement('h3','','Decisión'),textElement('p','',`${item.decision || '—'} · ${item.decisionReason || 'Sin motivo'}`),textElement('p','detail-sub',`Revisó ${item.reviewerId || '—'} · ${formatDate(item.reviewedAt)}`)); detail.append(result); return;
    }
    const reviewerRole = roleForType(item.type);
    const reviewer = selectedReviewer(reviewerRole);
    const box=textElement('section','decision-box',''); box.append(textElement('label','','Revisor autorizado'));
    const select=document.createElement('select'); select.id='decisionReviewer';
    asArray(state.snapshot?.admins).filter(a => asArray(a.roles).includes(reviewerRole)).forEach(admin => { const option=document.createElement('option'); option.value=admin.id; option.textContent=`${admin.id} · ${reviewerRole}`; option.selected=admin.id === reviewer?.id; select.append(option); });
    if (!select.options.length) { const option=document.createElement('option'); option.textContent=`No hay admin con rol ${reviewerRole} en allowlist`; select.append(option); select.disabled=true; }
    box.append(select,textElement('label','','Motivo de la decisión'));
    const reason=document.createElement('textarea'); reason.id='decisionReason'; reason.rows=3; reason.maxLength=1200; reason.placeholder='Explica brevemente los hechos considerados y el motivo'; box.append(reason);
    const actions=textElement('div','decision-actions','');
    decisionOptions(item).forEach(([value,label,css]) => { const button=textElement('button',`button ${css}`,label); button.type='button'; button.disabled=!reviewer; button.addEventListener('click',()=>decide(item,value)); actions.append(button); });
    box.append(actions,textElement('p','audit-note','La decisión y su motivo quedarán en el registro local de auditoría. La confirmación de un comprobante es una revisión visual, no una verificación bancaria automática.')); detail.append(box);
  }
  async function decide(item, decision) {
    const reviewerId=qs('#decisionReviewer')?.value;
    const reason=qs('#decisionReason')?.value.trim();
    if (!reviewerId) return showToast('No hay un revisor autorizado para esta acción.', true);
    if (!reason) return showToast('Escribe el motivo de la decisión.', true);
    if (item.type === 'professional_deletion' && decision === 'approved_anonymized' && !confirm('Esta acción anonimizará el perfil y no se puede deshacer. ¿Confirmas?')) return;
    try { await api('/api/decision',{method:'POST',body:JSON.stringify({caseId:item.id,decision,reason,reviewerId})}); showToast('Decisión registrada.'); state.selectedId=null; await refresh(); }
    catch (error) { showToast(error.message,true); }
  }
  function populateReviewers() {
    const select=qs('#reviewer'); select.replaceChildren();
    asArray(state.snapshot?.admins).forEach(admin => { const option=document.createElement('option'); option.value=admin.id; option.textContent=`${admin.id} · ${asArray(admin.roles).join(', ')}`; select.append(option); });
    if (!select.options.length) { const option=document.createElement('option'); option.value=''; option.textContent='Configura la allowlist local'; select.append(option); }
    qs('#newCase').disabled=!select.options.length || !auth;
  }
  async function refresh() {
    if (!auth) { connection.className='connection offline'; connection.textContent='Sesión no encontrada'; showToast('Inicia el panel con start-admin-panel.ps1.',true); return; }
    try {
      state.snapshot=await api('/api/reviews'); connection.className='connection online'; connection.textContent='Solo local · conectado';
      renderCounts(state.snapshot.cases||[]); populateReviewers();
      const profileSelect=qs('#profileSelect'); const selected=profileSelect.value; profileSelect.replaceChildren(new Option('Selecciona un perfil',''));
      asArray(state.snapshot.profiles).forEach(profile=>{const option=new Option(`${profile.name || profile.id} · ${profile.status}`,profile.id); profileSelect.append(option);}); profileSelect.value=selected;
      renderQueue();
    } catch(error) { connection.className='connection offline'; connection.textContent='Sin conexión'; showToast(error.message,true); }
  }
  function localDateValue(date) { return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`; }
  function setPresetDates() {
    const preset=qs('#timeWindow').value;
    const custom=preset==='custom';qs('#customDateRange').hidden=!custom;
    if(custom)return;
    const today=new Date(); const from=new Date(today);from.setDate(today.getDate()-Number(preset)+1);
    qs('#fromDate').value=localDateValue(from);qs('#toDate').value=localDateValue(today);
  }
  function svgElement(tag, attrs={}) { const node=document.createElementNS('http://www.w3.org/2000/svg',tag);Object.entries(attrs).forEach(([key,value])=>node.setAttribute(key,String(value)));return node; }
  function showEmptyChart(hostId,message='No hay información para mostrar en este período.') {
    const host=qs(`#${hostId}`);if(!host)return;host.replaceChildren();host.append(textElement('div','chart-empty',message));
  }
  function renderActivityChart(points, hostId='activityChart', fromText=qs('#fromDate').value, toText=qs('#toDate').value) {
    const host=qs(`#${hostId}`);host.replaceChildren();
    points=asArray(points);
    if(!fromText||!toText||new Date(`${fromText}T00:00:00`)>new Date(`${toText}T00:00:00`)){host.append(textElement('div','chart-empty','Selecciona una ventana válida.'));return;}
    const start=new Date(`${fromText}T00:00:00`),end=new Date(`${toText}T00:00:00`),spanDays=Math.floor((end-start)/86400000)+1;
    const mode=spanDays<=31?'day':spanDays<=120?'week':spanDays>730?'year':'month';
    const dates=[];const cursor=new Date(start);
    if(mode==='day'){while(cursor<=end){const key=localDateValue(cursor);dates.push({key,label:key.slice(5)});cursor.setDate(cursor.getDate()+1);}}
    else if(mode==='week'){while(cursor<=end){const bucketEnd=new Date(cursor);bucketEnd.setDate(bucketEnd.getDate()+6);if(bucketEnd>end)bucketEnd.setTime(end.getTime());dates.push({key:localDateValue(cursor),label:`${cursor.getDate()}/${cursor.getMonth()+1}`});cursor.setDate(cursor.getDate()+7);}}
    else if(mode==='month'){cursor.setDate(1);while(cursor<=end){const key=`${cursor.getFullYear()}-${String(cursor.getMonth()+1).padStart(2,'0')}`;dates.push({key,label:key});cursor.setMonth(cursor.getMonth()+1);}}
    else {cursor.setMonth(0,1);while(cursor<=end){const key=String(cursor.getFullYear());dates.push({key,label:key});cursor.setFullYear(cursor.getFullYear()+1);}}
    const values=new Map(dates.map(period=>[period.key,{referred:0,connected:0,formalized:0,completed:0}]));
    points.forEach(point=>{const date=new Date(point.at);if(Number.isNaN(date.getTime()))return;let key;if(mode==='day')key=localDateValue(date);else if(mode==='week'){const offset=Math.floor((Date.UTC(date.getFullYear(),date.getMonth(),date.getDate())-Date.UTC(start.getFullYear(),start.getMonth(),start.getDate()))/86400000);const bucketStart=new Date(start);bucketStart.setDate(bucketStart.getDate()+Math.floor(offset/7)*7);key=localDateValue(bucketStart);}else if(mode==='month')key=`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}`;else key=String(date.getFullYear());const bucket=values.get(key);if(bucket&&Object.hasOwn(bucket,point.type))bucket[point.type]++;});
    const periodWidth=mode==='day'?24:mode==='week'?42:mode==='year'?34:60;
    const width=Math.max(560,dates.length*periodWidth+55),height=245,left=38,right=8,top=10,bottom=35,plotW=width-left-right,plotH=height-top-bottom;
    const svg=svgElement('svg',{viewBox:`0 0 ${width} ${height}`,role:'img','aria-label':'Evolución diaria de solicitudes'});
    const maxValue=Math.max(0,...dates.flatMap(period=>Object.values(values.get(period.key))));
    if(!maxValue){showEmptyChart(hostId);return;}
    const step=maxValue<=4?1:Math.ceil(maxValue/4);const axisMax=step*4;
    for(let i=0;i<=4;i++){const y=top+plotH-i*plotH/4;svg.append(svgElement('line',{x1:left,y1:y,x2:width-right,y2:y,stroke:'#e8ede9','stroke-width':1}));const label=svgElement('text',{x:left-8,y:y+3,'text-anchor':'end',fill:'#87928b','font-size':9});label.textContent=String(i*step);svg.append(label);}
    const groupW=plotW/dates.length,barW=Math.max(2,Math.min(12,groupW*.68/chartTypes.length));
    dates.forEach((period,index)=>{const bucket=values.get(period.key);const center=left+(index+.5)*groupW;chartTypes.forEach((series,seriesIndex)=>{const val=bucket[series.id];if(!val)return;const barH=val/axisMax*plotH;const rect=svgElement('rect',{x:center-chartTypes.length*barW/2+seriesIndex*barW,y:top+plotH-barH,width:Math.max(1,barW-1),height:barH,rx:2,fill:series.color});const title=svgElement('title');title.textContent=`${series.label} · ${period.label}: ${val}`;rect.append(title);svg.append(rect);});const every=Math.max(1,Math.ceil(dates.length/12));if(index%every===0||index===dates.length-1){const label=svgElement('text',{x:center,y:height-12,'text-anchor':'middle',fill:'#87928b','font-size':9});label.textContent=period.label;svg.append(label);}});
    host.append(svg);const legend=textElement('div','chart-legend','');chartTypes.forEach(series=>{const item=textElement('span','','');const dot=textElement('i',`legend-dot legend-${series.id}`,'');item.append(dot,document.createTextNode(series.label));legend.append(item);});host.append(legend);
  }
  function renderReasonChart(reasons, hostId='reasonChart') {
    const host=qs(`#${hostId}`);host.replaceChildren();
    reasons=asArray(reasons);
    if(!reasons.length){host.append(textElement('div','chart-empty','No hay información para mostrar para este período.'));return;}
    const max=Math.max(1,...reasons.map(x=>x.count));
    reasons.forEach(item=>{const row=textElement('div','reason-row','');row.append(textElement('span','reason-name',reasonLabels[item.id]||item.id.replace(/_/g,' ')));const track=textElement('div','reason-track','');const bar=document.createElement('progress');bar.className='reason-bar';bar.max=max;bar.value=item.count;bar.setAttribute('aria-label',`${reasonLabels[item.id]||item.id}: ${item.count}`);track.append(bar);row.append(track,textElement('span','reason-count',item.count));host.append(row);});
  }
  function renderOverviewReviewChart(cases) {
    const host=qs('#overviewReviewChart');host.replaceChildren();
    const categories=[['payments','Transferencias'],['reliability','Trabajos y confiabilidad'],['fraud','Fraude y altas'],['profiles','Perfiles'],['services','Servicios']];
    const counts=Object.fromEntries(categories.map(([id])=>[id,0]));
    asArray(cases).filter(item=>item.status==='pending').forEach(item=>{const category=group(item);if(Object.hasOwn(counts,category))counts[category]++;});
    const max=Math.max(1,...Object.values(counts));
    if(!Object.values(counts).some(Boolean)){host.append(textElement('div','chart-empty','No hay revisiones pendientes.'));return;}
    categories.forEach(([id,label])=>{const row=textElement('div','reason-row','');row.append(textElement('span','reason-name',label));const track=textElement('div','reason-track','');const bar=document.createElement('progress');bar.className='reason-bar review-reason-bar';bar.max=max;bar.value=counts[id];bar.setAttribute('aria-label',`${label}: ${counts[id]}`);track.append(bar);row.append(track,textElement('span','reason-count',counts[id]));host.append(row);});
  }
  async function loadAnalytics() {
    if(!auth){showEmptyChart('activityChart','No hay información para mostrar: la sesión local no está activa.');showEmptyChart('reasonChart','No hay información para mostrar: la sesión local no está activa.');qs('#analyticsNote').textContent='Inicia el panel local para consultar sus métricas.';return;}
    const from=qs('#fromDate').value,to=qs('#toDate').value;
    if(!from||!to||from>to){showEmptyChart('activityChart','No hay información para mostrar: el período seleccionado no es válido.');showEmptyChart('reasonChart','No hay información para mostrar para este período.');qs('#analyticsNote').textContent='Elige un período válido para consultar los indicadores.';return;}
    if((new Date(`${to}T00:00:00`)-new Date(`${from}T00:00:00`))/86400000>365){showEmptyChart('activityChart','No hay información para mostrar: el rango supera el máximo de 366 días.');showEmptyChart('reasonChart','No hay información para mostrar para este período.');qs('#analyticsNote').textContent='El rango personalizado admite hasta 366 días.';return;}
    const fromIso=new Date(`${from}T00:00:00`).toISOString(),toIso=new Date(`${to}T23:59:59.999`).toISOString();
    const params=new URLSearchParams({from:fromIso,to:toIso});
    try{
      const data=await api(`/api/analytics?${params}`),points=asArray(data.points),reasons=asArray(data.reasons);const totals={referred:0,connected:0,formalized:0,completed:0,not_materialized:0};points.forEach(point=>{totals[point.type]=(totals[point.type]||0)+1;});
      qs('#metricReferrals').textContent=String(totals.referred);qs('#metricConnected').textContent=String(totals.connected);qs('#metricFormalized').textContent=String(totals.formalized);qs('#metricCompleted').textContent=String(totals.completed);qs('#metricNotMaterialized').textContent=String(totals.not_materialized);
      renderActivityChart(points);renderReasonChart(reasons);
      qs('#analyticsNote').textContent='La derivación cuenta cada oferta registrada; conexión, acuerdo y finalización usan sus marcas de tiempo. Los datos históricos sin fecha explícita se excluyen de ese hito. '+(points.length?'':'No hay eventos fechados en esta ventana.');
    }catch(error){showEmptyChart('activityChart');showEmptyChart('reasonChart');qs('#analyticsNote').textContent='No hay información disponible para mostrar en este período.';}
  }
  async function loadOverview() {
    if(!auth){showEmptyChart('overviewActivityChart','No hay información para mostrar en esta sesión.');showEmptyChart('overviewReasonChart','No hay información para mostrar en esta sesión.');showEmptyChart('overviewReviewChart','No hay información para mostrar en esta sesión.');qs('#overviewNote').textContent='Inicia el panel local para consultar el resumen.';return;}
    const from='2000-01-01T00:00:00.000Z',to=new Date().toISOString();
    try{
      const params=new URLSearchParams({from,to,reason:''});const data=await api(`/api/analytics?${params}`),points=asArray(data.points),reasons=asArray(data.reasons),cases=asArray(state.snapshot?.cases);
      const totals={referred:0,connected:0,formalized:0,completed:0,not_materialized:0};
      points.forEach(point=>{if(Object.hasOwn(totals,point.type))totals[point.type]++;});
      qs('#overviewReferrals').textContent=String(totals.referred);qs('#overviewConnected').textContent=String(totals.connected);qs('#overviewFormalized').textContent=String(totals.formalized);qs('#overviewCompleted').textContent=String(totals.completed);qs('#overviewNotMaterialized').textContent=String(totals.not_materialized);
      qs('#overviewPendingReviews').textContent=String(cases.filter(item=>item.status==='pending').length);
      renderActivityChart(points,'overviewActivityChart','2000-01-01',localDateValue(new Date()));renderReasonChart(reasons,'overviewReasonChart');renderOverviewReviewChart(cases);
      qs('#overviewNote').textContent=`Eventos con fecha disponibles desde 2000-01-01. Los hitos sin fecha registrada no se incluyen.${points.length?'':' No hay eventos fechados disponibles.'}`;
    }catch(error){showEmptyChart('overviewActivityChart');showEmptyChart('overviewReasonChart');showEmptyChart('overviewReviewChart');qs('#overviewNote').textContent='No hay información disponible para mostrar en el resumen.';}
  }
  async function loadServiceStatus() {
    if(!auth)return;
    try{
      const data=await api('/api/service-status');const running=data.running===true,configured=data.configured===true,enabled=data.enabled===true;
      qs('#serviceStatusTitle').textContent=running?'Bot en ejecución':enabled?'Servicio habilitado, bot detenido':'Configuración incompleta';
      qs('#serviceStatusDescription').textContent=running?'El listener local del webhook respondió a la comprobación.':enabled?'La configuración está lista, pero el webhook local no respondió.':'Faltan variables requeridas para habilitar el webhook.';
      qs('#serviceStatusBadge').textContent=running?'Activo':enabled?'Habilitado':'No habilitado';qs('#serviceStatusBadge').className=`service-badge${running||enabled?' online':''}`;
      qs('#serviceStatusIcon').className=`service-status-icon${running?' online':' offline'}`;
      qs('#servicePhoneNumber').textContent=data.phoneNumber||'No informado';qs('#servicePort').textContent=String(data.port||'—');qs('#serviceConfigured').textContent=configured?'Completa':'Incompleta';
      qs('#servicePhoneSource').textContent=data.phoneNumberSource==='business_number'?'Número empresarial indicado en WA_DISPLAY_PHONE_NUMBER.':data.phoneNumberSource==='meta_test_number'?'Número de prueba indicado en WA_TEST_PHONE_NUMBER.':'Configura WA_DISPLAY_PHONE_NUMBER para identificar el número empresarial.';
      qs('#serviceConfigNote').textContent=configured?'Variables requeridas presentes. Las credenciales no se muestran.':`Faltan: ${asArray(data.missingConfiguration).join(', ')||'configuración local'}`;
      qs('#serviceCheckedAt').textContent=`Última consulta: ${formatDate(data.checkedAt)}`;
    }catch(error){qs('#serviceStatusTitle').textContent='No se pudo consultar';qs('#serviceStatusDescription').textContent=error.message;qs('#serviceStatusBadge').textContent='Sin conexión';qs('#serviceStatusIcon').className='service-status-icon offline';}
  }
  async function refreshEverything(){await refresh();await Promise.all([loadOverview(),loadAnalytics(),loadServiceStatus()]);}
  document.querySelectorAll('.page-tab').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('.page-tab').forEach(x=>x.classList.toggle('selected',x===button));document.querySelectorAll('.shell>section.page-content').forEach(section=>section.hidden=section.id!==button.dataset.page);if(button.dataset.page==='homePage')loadOverview();if(button.dataset.page==='analyticsPage')loadAnalytics();if(button.dataset.page==='servicePage')loadServiceStatus();}));
  qs('#timeWindow').addEventListener('change',setPresetDates);qs('#applyAnalytics').addEventListener('click',loadAnalytics);qs('#refreshService').addEventListener('click',loadServiceStatus);
  document.querySelectorAll('.review-tab[data-filter]').forEach(button=>button.addEventListener('click',()=>setReviewFilter(button.dataset.filter)));
  qs('#refresh').addEventListener('click',refreshEverything);
  qs('#newCase').addEventListener('click',()=>{populateReviewers();qs('#caseDialog').showModal();qs('#caseType').dispatchEvent(new Event('change'));});
  qs('#caseType').addEventListener('change',()=>{
    const role=roleForType(qs('#caseType').value); const selector=qs('#reviewer');
    const match=asArray(state.snapshot?.admins).find(a=>asArray(a.roles).includes(role)); if(match) selector.value=match.id;
  });
  qs('#caseForm').addEventListener('submit',async event=>{
    event.preventDefault(); const type=qs('#caseType').value; const role=roleForType(type); const reviewer=asArray(state.snapshot?.admins).find(a=>a.id===qs('#reviewer').value && asArray(a.roles).includes(role));
    if(!reviewer) return showToast(`Selecciona un revisor con rol ${role}.`,true);
    try { await api('/api/cases',{method:'POST',body:JSON.stringify({type,title:qs('#caseTitle').value.trim(),professionalId:qs('#caseProfessional').value.trim(),requestId:qs('#caseRequest').value.trim(),summary:qs('#caseSummary').value.trim(),amount:qs('#caseAmount').value.trim(),evidencePath:qs('#evidencePath').value.trim(),reviewerId:reviewer.id})}); qs('#caseDialog').close();event.target.reset();showToast('Revisión agregada a la bandeja.');setReviewFilter(group({type}));await refresh(); }
    catch(error){showToast(error.message,true);}
  });
  async function profileAction(action) {
    const profileId=qs('#profileSelect').value, reason=qs('#suspensionReason').value.trim();
    if(!profileId) return showToast('Selecciona un perfil.',true);
    if(!reason) return showToast('Registra el motivo.',true);
    const admin=asArray(state.snapshot?.admins).find(a=>asArray(a.roles).includes('professional_reliability_admin'));
    if(!admin) return showToast('No hay administrador de confiabilidad en la allowlist.',true);
    if(action==='suspend'&&!confirm('¿Suspender este perfil durante 60 días?'))return;
    const requestId=qs('#suspensionRequest').value.trim();
    if(action==='suspend'&&!requestId)return showToast('Indica la solicitud que forma parte del umbral de suspensión.',true);
    try { await api('/api/suspension',{method:'POST',body:JSON.stringify({action,professionalId:profileId,requestId,reviewerId:admin.id,reason,days:60})});showToast(action==='suspend'?'Suspensión aplicada según el umbral.':'Perfil reactivado.');await refresh(); }
    catch(error){showToast(error.message,true);}
  }
  qs('#suspend').addEventListener('click',()=>profileAction('suspend'));
  qs('#reactivate').addEventListener('click',()=>profileAction('reactivate'));
  setPresetDates();refreshEverything();
})();
