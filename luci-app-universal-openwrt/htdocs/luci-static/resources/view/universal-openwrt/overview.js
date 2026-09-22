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
const adaptiveAuto=rpc.declare({object:'universal_openwrt',method:'adaptive_auto',params:['confirm']});
const adaptiveStatus=rpc.declare({object:'universal_openwrt',method:'adaptive_status',params:[]});
const predictiveAuto=rpc.declare({object:'universal_openwrt',method:'predictive_auto',params:['confirm']});
const predictiveStatus=rpc.declare({object:'universal_openwrt',method:'predictive_status',params:[]});
const resourcePolicy=rpc.declare({object:'universal_openwrt',method:'resource_policy',params:[]});
const resourceUpdate=rpc.declare({object:'universal_openwrt',method:'resource_update',params:[]});
const resourceBenchmark=rpc.declare({object:'universal_openwrt',method:'resource_benchmark',params:[]});
const resourceBenchmarkStatus=rpc.declare({object:'universal_openwrt',method:'resource_benchmark_status',params:[]});
const tgProxyStatus=rpc.declare({object:'universal_openwrt',method:'tg_proxy_status',params:[]});
const tgProxyEnable=rpc.declare({object:'universal_openwrt',method:'tg_proxy_enable',params:['confirm']});
const tgProxyDisable=rpc.declare({object:'universal_openwrt',method:'tg_proxy_disable',params:['confirm']});
const tgSocks5Status=rpc.declare({object:'universal_openwrt',method:'tg_socks5_status',params:[]});
const tgSocks5Install=rpc.declare({object:'universal_openwrt',method:'tg_socks5_install',params:[]});
const tgSocks5Enable=rpc.declare({object:'universal_openwrt',method:'tg_socks5_enable',params:['confirm']});
const tgSocks5Disable=rpc.declare({object:'universal_openwrt',method:'tg_socks5_disable',params:['confirm']});
const tgWsStatus=rpc.declare({object:'universal_openwrt',method:'tg_ws_status',params:[]});
const tgWsEnable=rpc.declare({object:'universal_openwrt',method:'tg_ws_enable',params:['confirm']});
const tgWsDisable=rpc.declare({object:'universal_openwrt',method:'tg_ws_disable',params:['confirm']});
const tgFailoverStatus=rpc.declare({object:'universal_openwrt',method:'tg_failover_status',params:[]});
const tgFailoverRun=rpc.declare({object:'universal_openwrt',method:'tg_failover_run',params:['confirm']});
const strategyPlan=rpc.declare({object:'universal_openwrt',method:'strategy_plan',params:[]});
const strategyStatus=rpc.declare({object:'universal_openwrt',method:'strategy_status',params:[]});
const tunnelStatus=rpc.declare({object:'universal_openwrt',method:'tunnel_status',params:[]});
const tunnelProfiles=rpc.declare({object:'universal_openwrt',method:'tunnel_profiles',params:[]});
const tunnelAuto=rpc.declare({object:'universal_openwrt',method:'tunnel_auto',params:['confirm']});
const tunnelDisable=rpc.declare({object:'universal_openwrt',method:'tunnel_disable',params:[]});

function text(r){ return r?.output || r?.error || 'Нет данных'; }
function modal(title,r){ ui.showModal(title,[E('pre',{'style':'white-space:pre-wrap;max-height:70vh;overflow:auto'},text(r)),E('button',{'class':'btn cbi-button','click':ui.hideModal},'Закрыть')]); }
function btn(label,fn,cls){ return E('button',{'class':'cbi-button '+(cls||''),'click':function(){this.disabled=true;Promise.resolve(fn()).finally(()=>this.disabled=false);}},label); }
function details(title,body){ const d=E('details',{'style':'margin-top:12px'}); d.appendChild(E('summary',{'style':'cursor:pointer;font-weight:600'},title)); d.appendChild(body); return d; }

return view.extend({
 load:()=>Promise.all([status(),matrix(),logs(),awgStatus(),tgProxyStatus(),tgSocks5Status(),tgWsStatus(),tgFailoverStatus()]),
 render:function(d){
  const root=E('div',{'class':'cbi-map'});
  const st=E('pre',{'style':'white-space:pre-wrap;max-height:300px;overflow:auto'},text(d[0]));
  const aw=E('pre',{'style':'white-space:pre-wrap;max-height:220px;overflow:auto'},text(d[3]));
  const tg=E('pre',{'style':'white-space:pre-wrap;max-height:260px;overflow:auto'},[text(d[4]),text(d[5]),text(d[6]),text(d[7])].join('\n\n'));
  const mx=E('pre',{'style':'white-space:pre-wrap;max-height:360px;overflow:auto'},text(d[1]));
  const lg=E('pre',{'style':'white-space:pre-wrap;max-height:360px;overflow:auto'},text(d[2]));
  const speed=E('select',{'class':'cbi-input'},['quick','standard','deep'].map(x=>E('option',{value:x},x==='quick'?'Быстро':x==='deep'?'Глубоко':'Стандартно')));
  const vpn=E('select',{'class':'cbi-input'},[['split','Split'],['full','Full'],['off','Off']].map(x=>E('option',{value:x[0]},x[1])));

  function refresh(){return Promise.all([status(),matrix(),logs(),awgStatus(),tgProxyStatus(),tgSocks5Status(),tgWsStatus(),tgFailoverStatus()]).then(r=>{st.textContent=text(r[0]);mx.textContent=text(r[1]);lg.textContent=text(r[2]);aw.textContent=text(r[3]);tg.textContent=[text(r[4]),text(r[5]),text(r[6]),text(r[7])].join('\n\n');});}
  function auto(){if(!confirm('Запустить безопасную автонастройку? Система сама проверит ресурсы, подберёт совместимую стратегию и откатит неудачный вариант.'))return;return install('auto',speed.value,vpn.value,true).then(r=>{modal('Автонастройка',r);return refresh();});}
  function check(){return Promise.all([verify(),test(),awgStatus()]).then(r=>modal('Проверка системы',[text(r[0]),text(r[1]),text(r[2])].join('\n\n')));}
  function resources(){return resourceUpdate().then(r=>{modal('Обновление ресурсов',r);return refresh();});}
  function back(){if(!confirm('Откатить последнее изменение?'))return;return rollback(true).then(r=>{modal('Откат',r);return refresh();});}

  root.appendChild(E('div',{'class':'cbi-section'},[
   E('h2',{},'Universal OpenWrt'),
   E('p',{'class':'cbi-section-descr'},'Управление построено по принципу «одна кнопка — один сценарий». Автонастройка сама проверяет совместимость, соединение и выбирает наименее тяжёлую рабочую стратегию.'),
   E('div',{'style':'display:flex;gap:8px;flex-wrap:wrap;align-items:center'},[
    btn('Автонастройка',auto,'cbi-button-positive'),
    btn('Проверить',check),
    btn('Обновить ресурсы',resources),
    btn('Обновить экран',refresh),
    btn('Откатить',back,'cbi-button-negative'),
    E('label',{'style':'display:flex;gap:6px;align-items:center'},['Тест: ',speed])
   ])
  ]));
  root.appendChild(E('div',{'class':'cbi-section'},[E('h3',{},'Состояние'),st]));
  root.appendChild(E('div',{'class':'cbi-section'},[E('h3',{},'AWG / WARP'),aw]));
  root.appendChild(E('div',{'class':'cbi-section'},[E('h3',{},'Telegram'),tg]));

  const advanced=E('div',{});
  const strategyBox=E('div',{'style':'display:flex;gap:8px;flex-wrap:wrap;align-items:center'},[
   btn('Подобрать стратегию',()=>optimize(speed.value).then(r=>modal('Подбор стратегии',r)),'cbi-button-positive'),
   btn('Полный адаптивный тест',()=>{if(!confirm('Проверить кандидатов Core → DNS → DPI → AWG → Podkop → Proxy? Это временно меняет сетевые правила и автоматически откатывает неудачные варианты.'))return;return adaptiveAuto({confirm:true}).then(r=>modal('Адаптивный подбор',r));},'cbi-button-positive'),
   btn('Статус',()=>adaptiveStatus().then(r=>modal('Адаптивный контроллер',r))),
   btn('Предиктивный анализ',()=>predictiveAuto({confirm:true}).then(r=>modal('Предиктивный анализ',r))),
   btn('Матрица ресурсов',()=>resourcePolicy().then(r=>modal('Матрица стратегий',r))),
   btn('Бенчмарк ресурсов',()=>resourceBenchmark().then(r=>modal('Бенчмарк по ресурсам',r)))
  ]);
  advanced.appendChild(details('Стратегии и автоматический подбор',strategyBox));

  const tgBox=E('div',{'style':'display:flex;gap:8px;flex-wrap:wrap;align-items:center'},[
   btn('Статус Telegram',()=>Promise.all([tgProxyStatus(),tgSocks5Status(),tgWsStatus(),tgFailoverStatus()]).then(r=>modal('Telegram',r.map(text).join('\n\n')))),
   btn('Автовыбор Telegram',()=>{if(!confirm('Автоматически выбрать рабочий Telegram backend?'))return;return tgFailoverRun({confirm:true}).then(r=>modal('Telegram failover',r)).then(refresh);},'cbi-button-positive'),
   btn('Установить TG SOCKS5',()=>tgSocks5Install().then(r=>modal('TG SOCKS5',r))),
   btn('Включить TG SOCKS5',()=>tgSocks5Enable({confirm:true}).then(r=>modal('TG SOCKS5',r)).then(refresh),'cbi-button-positive'),
   btn('Отключить TG SOCKS5',()=>tgSocks5Disable({confirm:true}).then(r=>modal('TG SOCKS5',r)).then(refresh),'cbi-button-negative'),
   btn('Включить внешний SOCKS5',()=>tgProxyEnable({confirm:true}).then(r=>modal('Telegram proxy',r)).then(refresh),'cbi-button-positive'),
   btn('Отключить внешний SOCKS5',()=>tgProxyDisable({confirm:true}).then(r=>modal('Telegram proxy',r)).then(refresh),'cbi-button-negative'),
   btn('TG WS вкл.',()=>tgWsEnable({confirm:true}).then(r=>modal('TG WS',r)).then(refresh)),
   btn('TG WS выкл.',()=>tgWsDisable({confirm:true}).then(r=>modal('TG WS',r)).then(refresh),'cbi-button-negative')
  ]);
  advanced.appendChild(details('Telegram — расширенные настройки',tgBox));

  const tunnelBox=E('div',{'style':'display:flex;gap:8px;flex-wrap:wrap;align-items:center'},[
   E('label',{},['Режим AWG: ',vpn]),
   btn('AWG status',()=>awgStatus().then(r=>modal('AWG / WARP',r))),
   btn('VLESS status',()=>tunnelStatus().then(r=>modal('Tunnel Engine',r))),
   btn('Профили VLESS',()=>tunnelProfiles().then(r=>modal('VLESS профили',r))),
   btn('Подготовить VLESS',()=>{if(!confirm('Подготовить VLESS-профиль?'))return;return tunnelAuto({confirm:true}).then(r=>modal('Tunnel Engine',r));},'cbi-button-positive'),
   btn('Отключить VLESS',()=>tunnelDisable().then(r=>modal('Tunnel Engine',r)),'cbi-button-negative')
  ]);
  advanced.appendChild(details('VPN / VLESS — расширенные настройки',tunnelBox));

  const diagnostics=E('div',{'style':'display:flex;gap:8px;flex-wrap:wrap;align-items:center'},[
   btn('План стратегий',()=>strategyPlan().then(r=>modal('План',r))),
   btn('Состояние владельцев',()=>strategyStatus().then(r=>modal('Strategy ownership',r))),
   btn('Последний бенчмарк',()=>resourceBenchmarkStatus().then(r=>modal('Бенчмарк',r))),
   btn('Предиктивный статус',()=>predictiveStatus().then(r=>modal('Predictive controller',r))),
   btn('Логи',()=>logs().then(r=>modal('Логи',r))),
   btn('Матрица',()=>matrix().then(r=>modal('Матрица совместимости',r))),
   btn('Бенчмарк методов',()=>benchmark(speed.value).then(r=>modal('Бенчмарк методов',r)))
  ]);
  advanced.appendChild(details('Диагностика (для опытного пользователя)',diagnostics));
  root.appendChild(advanced);
  root.appendChild(E('p',{'class':'cbi-section-descr'},'Важно: «матрица ресурсов» является результатом диагностики и подбора. Она не создаёт несколько независимых глобальных туннелей одновременно. Перед применением нового глобального backend предыдущие изменения проходят проверку и откат при регрессии — это предотвращает конфликт AWG/DPI/Proxy/Tunnel Engine.'));
  return root;
 }
});
