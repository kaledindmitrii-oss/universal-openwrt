'use strict';
'require view';
'require rpc';
'require ui';
const status=rpc.declare({object:'universal_openwrt',method:'status',params:[]});
const matrix=rpc.declare({object:'universal_openwrt',method:'matrix',params:[]});
const optimize=rpc.declare({object:'universal_openwrt',method:'optimize',params:['speed']});
const verify=rpc.declare({object:'universal_openwrt',method:'verify',params:[]});
const discover=rpc.declare({object:'universal_openwrt',method:'discover',params:['speed']});
const benchmark=rpc.declare({object:'universal_openwrt',method:'benchmark',params:['speed']});
const test=rpc.declare({object:'universal_openwrt',method:'test',params:[]});
const awgStatus=rpc.declare({object:'universal_openwrt',method:'awg_status',params:[]});
const logs=rpc.declare({object:'universal_openwrt',method:'logs',params:[]});
const install=rpc.declare({object:'universal_openwrt',method:'install',params:['module','speed','vpnmode','confirm']});
const rollback=rpc.declare({object:'universal_openwrt',method:'rollback',params:['confirm']});
const vpnProfiles=rpc.declare({object:'universal_openwrt',method:'vpn_profiles',params:[]});
const vpnProfileCreate=rpc.declare({object:'universal_openwrt',method:'vpn_profile_create',params:['name','mode','iface','description']});
const vpnProfileDelete=rpc.declare({object:'universal_openwrt',method:'vpn_profile_delete',params:['name','confirm']});
const vpnProfileActivate=rpc.declare({object:'universal_openwrt',method:'vpn_profile_activate',params:['name','confirm']});
const vpnProfileTest=rpc.declare({object:'universal_openwrt',method:'vpn_profile_test',params:['name']});
const vpnProfileBenchmark=rpc.declare({object:'universal_openwrt',method:'vpn_profile_benchmark',params:['name']});
const vpnProfileAuto=rpc.declare({object:'universal_openwrt',method:'vpn_profile_auto',params:['confirm']});
const adaptiveAuto=rpc.declare({object:'universal_openwrt',method:'adaptive_auto',params:['confirm']});
const adaptiveStatus=rpc.declare({object:'universal_openwrt',method:'adaptive_status',params:[]});
const predictiveAuto=rpc.declare({object:'universal_openwrt',method:'predictive_auto',params:['confirm']});
const predictiveStatus=rpc.declare({object:'universal_openwrt',method:'predictive_status',params:[]});
const rpcResourcePolicy=rpc.declare({object:'universal_openwrt',method:'resource_policy',params:[]});
const resourceUpdate=rpc.declare({object:'universal_openwrt',method:'resource_update',params:[]});
const tgProxyStatus=rpc.declare({object:'universal_openwrt',method:'tg_proxy_status',params:[]});
const tgProxyEnable=rpc.declare({object:'universal_openwrt',method:'tg_proxy_enable',params:['confirm']});
const tgProxyDisable=rpc.declare({object:'universal_openwrt',method:'tg_proxy_disable',params:['confirm']});
const resourcePolicy=rpcResourcePolicy;
const resourceRefresh=resourceUpdate;
const tgStatus=tgProxyStatus;
const tgEnable=tgProxyEnable;
const tgDisable=tgProxyDisable;
const tgWsStatus=rpc.declare({object:'universal_openwrt',method:'tg_ws_status',params:[]});
const tgWsEnable=rpc.declare({object:'universal_openwrt',method:'tg_ws_enable',params:['confirm']});
const tgWsDisable=rpc.declare({object:'universal_openwrt',method:'tg_ws_disable',params:['confirm']});
const tgSocks5Status=rpc.declare({object:'universal_openwrt',method:'tg_socks5_status',params:[]});
const tgSocks5Install=rpc.declare({object:'universal_openwrt',method:'tg_socks5_install',params:[]});
const tgSocks5Enable=rpc.declare({object:'universal_openwrt',method:'tg_socks5_enable',params:['confirm']});
const tgSocks5Disable=rpc.declare({object:'universal_openwrt',method:'tg_socks5_disable',params:['confirm']});
const tgFailoverStatus=rpc.declare({object:'universal_openwrt',method:'tg_failover_status',params:[]});
const tgFailoverRun=rpc.declare({object:'universal_openwrt',method:'tg_failover_run',params:['confirm']});
const strategyPlan=rpc.declare({object:'universal_openwrt',method:'strategy_plan',params:[]});
const strategyStatus=rpc.declare({object:'universal_openwrt',method:'strategy_status',params:[]});
const tunnelStatus=rpc.declare({object:'universal_openwrt',method:'tunnel_status',params:[]});
const tunnelProfiles=rpc.declare({object:'universal_openwrt',method:'tunnel_profiles',params:[]});
const tunnelCreate=rpc.declare({object:'universal_openwrt',method:'tunnel_profile_create',params:['name','address','port','uuid','servername']});
const tunnelDelete=rpc.declare({object:'universal_openwrt',method:'tunnel_profile_delete',params:['name','confirm']});
const tunnelEnable=rpc.declare({object:'universal_openwrt',method:'tunnel_enable',params:['name']});
const tunnelDisable=rpc.declare({object:'universal_openwrt',method:'tunnel_disable',params:[]});
const tunnelAuto=rpc.declare({object:'universal_openwrt',method:'tunnel_auto',params:['confirm']});
function out(title,text){return E('div',{'class':'cbi-section'},[E('h3',{},title),E('pre',{'style':'white-space:pre-wrap;max-height:420px;overflow:auto'},text||'—')]);}
function modal(title,text){ui.showModal(title,[E('pre',{'style':'white-space:pre-wrap;max-height:70vh;overflow:auto'},text||'—'),E('button',{'class':'btn cbi-button','click':ui.hideModal},'Закрыть')]);}
return view.extend({load:()=>Promise.all([status(),matrix(),logs(),awgStatus()]),render:function(d){
 let root=E('div',{'class':'cbi-map'}), st=E('pre',{'style':'white-space:pre-wrap;max-height:360px;overflow:auto'},d[0]?.output||d[0]?.error||''), mx=E('pre',{'style':'white-space:pre-wrap;max-height:420px;overflow:auto'},d[1]?.output||d[1]?.error||''), lg=E('pre',{'style':'white-space:pre-wrap;max-height:420px;overflow:auto'},d[2]?.output||''), aw=E('pre',{'style':'white-space:pre-wrap;max-height:260px;overflow:auto'},d[3]?.output||d[3]?.error||'');
 let speed=E('select',{},['quick','standard','deep'].map(x=>E('option',{value:x},x)));
 let sel=E('select',{},['auto','core','doh-unpoison','malw-hosts','dpi-desync','awg-warp','podkop','proxy','all'].map(x=>E('option',{value:x},x)));
 let vpn=E('select',{},[['split','Split — только выбранные/служебные маршруты'],['full','Full — весь LAN через AWG'],['off','Off — без маршрутизации AWG']].map(x=>E('option',{value:x[0]},x[1])));
 function refresh(){return Promise.all([status(),matrix(),logs(),awgStatus()]).then(r=>{st.textContent=r[0]?.output||r[0]?.error||'';mx.textContent=r[1]?.output||r[1]?.error||'';lg.textContent=r[2]?.output||'';aw.textContent=r[3]?.output||r[3]?.error||'';});}
 function btn(label,fn,cls){return E('button',{'class':'cbi-button '+(cls||''),'click':function(){this.disabled=true;Promise.resolve(fn()).finally(()=>this.disabled=false);}},label);}
 function doInstall(){let m=sel.value;if(!confirm('Запустить установку '+m+'?'))return;return install(m,speed.value,vpn.value,true).then(r=>{ui.addNotification(null,E('p',{},r?.ok?'Установка завершена':'Установка завершилась с ошибкой'),r?.ok?'info':'error');return refresh();});}
 function doRollback(){if(!confirm('Откатить последнее сохранённое состояние?'))return;return rollback(true).then(r=>{ui.addNotification(null,E('p',{},r?.ok?'Откат завершён':'Ошибка отката'),r?.ok?'info':'error');return refresh();});}
 function doDiscover(){return discover(speed.value).then(r=>modal('Автоматический список заблокированных/замедленных ресурсов',r?.output||r?.error||''));}
 function doOptimize(){return optimize(speed.value).then(r=>modal('Результат подбора стратегии',r?.output||r?.error||''));}
 root.appendChild(out('Состояние устройства',st));
 function renderProfiles(){
   let box=E('pre',{'style':'white-space:pre-wrap;max-height:260px;overflow:auto'},'Загрузка профилей…');
   let name=E('input',{'class':'cbi-input','placeholder':'profile-name','style':'min-width:150px'});
   let iface=E('input',{'class':'cbi-input','value':'awg10','placeholder':'awg interface','style':'min-width:100px'});
   let mode=E('select',{},['split','full','off'].map(x=>E('option',{value:x},x)));
   function refreshProfiles(){return vpnProfiles().then(r=>{box.textContent=r?.output||r?.error||'';});}
   function create(){if(!/^[A-Za-z0-9._-]{1,48}$/.test(name.value))return ui.addNotification(null,E('p',{},'Имя профиля: латиница, цифры, . _ -'),'error');return vpnProfileCreate(name.value,mode.value,iface.value||'awg10','AWG/WARP profile').then(r=>{modal('Профиль',r?.output||r?.error||'');return refreshProfiles();});}
   function selected(){let n=prompt('Имя профиля');return n&&/^[A-Za-z0-9._-]{1,48}$/.test(n)?n:null;}
   function activate(){let n=selected();if(!n)return;return vpnProfileActivate(n,true).then(r=>{modal('Активация профиля',r?.output||r?.error||'');return refreshProfiles();});}
   function testProfile(){let n=selected();if(!n)return;return vpnProfileTest(n).then(r=>modal('Тест профиля',r?.output||r?.error||''));}
   function bench(){return vpnProfileBenchmark('').then(r=>modal('Сравнение VPN-профилей',r?.output||r?.error||''));}
   function autoPick(){if(!confirm('Сравнить сохранённые VPN-профили и автоматически включить лучший?'))return;return vpnProfileAuto(true).then(r=>{modal('Автовыбор VPN',r?.output||r?.error||'');return refreshProfiles();});}
   function adaptive(){if(!confirm('Запустить полный адаптивный подбор: Core → DPI → AWG Split/Full → Podkop → Proxy? Это может временно переключать маршрутизацию.'))return;return adaptiveAuto(true).then(r=>modal('Адаптивный контроллер',r?.output||r?.error||''));}
   function adaptiveState(){return adaptiveStatus().then(r=>modal('Состояние адаптивного контроллера',r?.output||r?.error||''));}
   function predictive(){if(!confirm('Запустить предиктивный анализ проблемных ресурсов и автоматическое восстановление?'))return;return predictiveAuto(true).then(r=>modal('Предиктивный контроллер',r?.output||r?.error||''));}
   function predictiveState(){return predictiveStatus().then(r=>modal('История предиктивного контроллера',r?.output||r?.error||''));}
   root.appendChild(E('div',{'class':'cbi-section'},[E('h3',{},'VPN-профили AWG/WARP'),E('div',{'style':'display:flex;gap:8px;flex-wrap:wrap;align-items:center'},[name,mode,iface,btn('Создать профиль',create),btn('Активировать',activate),btn('Тест профиля',testProfile),btn('Сравнить все',bench),btn('Автовыбор лучшего',autoPick,'cbi-button-positive'),btn('Адаптивный подбор стратегий',adaptive,'cbi-button-positive'),btn('Состояние стратегий',adaptiveState),btn('Предиктивный анализ',predictive,'cbi-button-positive'),btn('История предиктива',predictiveState),btn('Матрица ресурсов',resourcePolicy),btn('Обновить список ресурсов',resourceRefresh),btn('Внешний SOCKS5',tgStatus),btn('Включить внешний proxy',tgEnable,'cbi-button-positive'),btn('TG SOCKS5 Go',tgSocks5Status),btn('Установить TG SOCKS5',()=>tgSocks5Install().then(r=>modal('TG SOCKS5 Go',r?.output||r?.error||'')),'cbi-button-positive'),btn('Включить TG SOCKS5',()=>tgSocks5Enable({confirm:true}).then(r=>modal('TG SOCKS5 Go',r?.output||r?.error||'')),'cbi-button-positive'),btn('Отключить TG SOCKS5',()=>tgSocks5Disable({confirm:true}).then(r=>modal('TG SOCKS5 Go',r?.output||r?.error||'')),'cbi-button-negative'),btn('Отключить Telegram proxy',tgDisable,'cbi-button-negative'),btn('TG WS status',tgWsStatus),btn('Включить TG WS',()=>tgWsEnable({confirm:true}),'cbi-button-positive'),btn('Отключить TG WS',()=>tgWsDisable({confirm:true}),'cbi-button-negative'),btn('TG failover status',()=>tgFailoverStatus().then(r=>modal('Telegram failover',r?.output||r?.error||''))),btn('Автовыбор Telegram',()=>{if(!confirm('Автоматически выбрать рабочий Telegram backend?'))return;return tgFailoverRun({confirm:true}).then(r=>modal('Telegram failover',r?.output||r?.error||''));},'cbi-button-positive')]),box]));
   refreshProfiles();
 }
 renderProfiles();

 root.appendChild(out('AWG / WARP',aw));
 root.appendChild(E('div',{'class':'cbi-section'},[E('h3',{},'Управление'),E('div',{'style':'display:flex;gap:8px;flex-wrap:wrap;align-items:center'},[E('label',{},['Скорость тестирования: ',speed]),E('label',{},['VPN: ',vpn]),sel,btn('Установить / применить',doInstall,'cbi-button-positive'),btn('Проверить AWG',()=>awgStatus().then(r=>modal('AWG / WARP',r?.output||r?.error||''))),btn('Проверить соединение',()=>test().then(refresh)),btn('Автопоиск проблемных ресурсов',doDiscover),btn('Подобрать стратегию',doOptimize),btn('Бенчмарк методов',()=>benchmark(speed.value).then(r=>modal('Рейтинг стратегий',r?.output||r?.error||''))),btn('Глубокая проверка',()=>verify().then(r=>modal('Проверка',r?.output||r?.error||''))),btn('Обновить',refresh),btn('Откат',doRollback,'cbi-button-negative')]) ]));
 root.appendChild(E('div',{'class':'cbi-section'},[E('h3',{},'Tunnel Engine — VLESS / sing-box / TProxy / FakeIP'),E('p',{'class':'cbi-section-descr'},'Открытая реализация архитектуры ZeroBlock: профиль VLESS, sing-box и безопасное управление владельцами правил. Закрытый ZeroBlock бинарник не устанавливается.'),E('div',{'style':'display:flex;gap:8px;flex-wrap:wrap;align-items:center'},[btn('Статус туннеля',()=>tunnelStatus().then(r=>modal('Tunnel Engine',r?.output||r?.error||''))),btn('Профили',()=>tunnelProfiles().then(r=>modal('VLESS профили',r?.output||r?.error||''))),btn('План стратегий',()=>strategyPlan().then(r=>modal('Strategy Engine',r?.output||r?.error||''))),btn('Состояние владельцев',()=>strategyStatus().then(r=>modal('Strategy ownership',r?.output||r?.error||''))),btn('Подготовить первый VLESS-профиль',()=>{if(!confirm('Подготовить первый настроенный VLESS-профиль?'))return;return tunnelAuto(true).then(r=>modal('Tunnel Engine',r?.output||r?.error||''));},'cbi-button-positive'),btn('Отключить туннель',()=>tunnelDisable().then(r=>modal('Tunnel Engine',r?.output||r?.error||'')),'cbi-button-negative')])]));
 root.appendChild(E('p',{'class':'cbi-section-descr'},'AWG auto автоматически подбирает пакет kmod/tools под версию OpenWrt и kernel ABI, регистрирует WARP-конфигурацию через backend-генераторы и настраивает интерфейс. Full переводит LAN-трафик в туннель; Split не меняет default route. При ошибке проверки конфигурация откатывается. Не передавайте в панель публичные VPN-ключи из непроверенных источников.'));
 return root;
}});


// v19 profile-manager helpers are exposed through rpcd; the existing dashboard can call these
// methods from a custom tab without granting arbitrary shell access.
