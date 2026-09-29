'use strict';
'require view';
'require rpc';
'require ui';

const api = {
  status: rpc.declare({object:'universal_openwrt',method:'status',params:[]}),
  matrix: rpc.declare({object:'universal_openwrt',method:'matrix',params:[]}),
  verify: rpc.declare({object:'universal_openwrt',method:'verify',params:[]}),
  test: rpc.declare({object:'universal_openwrt',method:'test',params:[]}),
  optimize: rpc.declare({object:'universal_openwrt',method:'optimize',params:['speed']}),
  adaptive: rpc.declare({object:'universal_openwrt',method:'adaptive_auto',params:['confirm']}),
  automationStatus: rpc.declare({object:'universal_openwrt',method:'automation_status',params:[]}),
  automationEnable: rpc.declare({object:'universal_openwrt',method:'automation_enable',params:['confirm']}),
  automationDisable: rpc.declare({object:'universal_openwrt',method:'automation_disable',params:['confirm']}),
  automationConfig: rpc.declare({object:'universal_openwrt',method:'automation_config',params:['enabled','hour','minute','interval_hours','confirm']}),
  automationRun: rpc.declare({object:'universal_openwrt',method:'automation_run',params:['confirm']}),
  predictive: rpc.declare({object:'universal_openwrt',method:'predictive_auto',params:['confirm']}),
  rollback: rpc.declare({object:'universal_openwrt',method:'rollback',params:['confirm']}),
  resources: rpc.declare({object:'universal_openwrt',method:'resource_update',params:[]}),
  resourceStatus: rpc.declare({object:'universal_openwrt',method:'resource_policy',params:[]}),
  resourceMonitor: rpc.declare({object:'universal_openwrt',method:'resource_monitor',params:[]}),
  resourceRecovery: rpc.declare({object:'universal_openwrt',method:'resource_recovery',params:['confirm']}),
  resourceBenchmark: rpc.declare({object:'universal_openwrt',method:'resource_benchmark',params:[]}),
  logs: rpc.declare({object:'universal_openwrt',method:'logs',params:[]}),
  awg: rpc.declare({object:'universal_openwrt',method:'awg_status',params:[]}),
  remoteWgStatus: rpc.declare({object:'universal_openwrt',method:'remote_wg_status',params:[]}),
  remoteWgDiagnose: rpc.declare({object:'universal_openwrt',method:'remote_wg_diagnose',params:[]}),
  remoteWgSetup: rpc.declare({object:'universal_openwrt',method:'remote_wg_setup',params:['confirm']}),
  remoteWgList: rpc.declare({object:'universal_openwrt',method:'remote_wg_list',params:[]}),
  remoteWgAdd: rpc.declare({object:'universal_openwrt',method:'remote_wg_add',params:['name','mode']}),
  remoteWgSetMode: rpc.declare({object:'universal_openwrt',method:'remote_wg_set_mode',params:['name','mode']}),
  remoteWgConfig: rpc.declare({object:'universal_openwrt',method:'remote_wg_config',params:['name']}),
  remoteWgQr: rpc.declare({object:'universal_openwrt',method:'remote_wg_qr',params:['name']}),
  remoteWgRevoke: rpc.declare({object:'universal_openwrt',method:'remote_wg_revoke',params:['name','confirm']}),
  remoteWgRegenerate: rpc.declare({object:'universal_openwrt',method:'remote_wg_regenerate',params:['name','confirm']}),
  remoteWgRemove: rpc.declare({object:'universal_openwrt',method:'remote_wg_remove',params:['name','confirm']}),
  tg: rpc.declare({object:'universal_openwrt',method:'tg_failover_status',params:[]}),
    tgSock: rpc.declare({object:'universal_openwrt',method:'tg_socks5_status',params:[]}),
    tgInstall: rpc.declare({object:'universal_openwrt',method:'tg_socks5_install',params:[]}),
    tgEnable: rpc.declare({object:'universal_openwrt',method:'tg_socks5_enable',params:['confirm']}),
    tgDisable: rpc.declare({object:'universal_openwrt',method:'tg_socks5_disable',params:['confirm']}),
  tgControllerStatus: rpc.declare({object:'universal_openwrt',method:'telegram_controller_status',params:[]}),
  tgControllerProbe: rpc.declare({object:'universal_openwrt',method:'telegram_controller_probe',params:[]}),
  tgControllerEnable: rpc.declare({object:'universal_openwrt',method:'telegram_controller_enable',params:['confirm']}),
  tgControllerDisable: rpc.declare({object:'universal_openwrt',method:'telegram_controller_disable',params:['confirm']}),
  tgBackends: rpc.declare({object:'universal_openwrt',method:'telegram_backends_status',params:[]}),
  tgTelemtInstall: rpc.declare({object:'universal_openwrt',method:'telegram_telemt_install',params:[]}),
  tgTelemtEnable: rpc.declare({object:'universal_openwrt',method:'telegram_telemt_enable',params:['confirm']}),
  tgTelemtDisable: rpc.declare({object:'universal_openwrt',method:'telegram_telemt_disable',params:['confirm']}),
  tgWsEnable: rpc.declare({object:'universal_openwrt',method:'tg_ws_enable',params:['confirm']}),
  tgWsDisable: rpc.declare({object:'universal_openwrt',method:'tg_ws_disable',params:['confirm']}),
  tgProxyStatus: rpc.declare({object:'universal_openwrt',method:'tg_proxy_status',params:[]}),
  tgProxyEnable: rpc.declare({object:'universal_openwrt',method:'tg_proxy_enable',params:['confirm']}),
  tgProxyDisable: rpc.declare({object:'universal_openwrt',method:'tg_proxy_disable',params:['confirm']}),
  aiCatalog: rpc.declare({object:'universal_openwrt',method:'ai_catalog',params:[]}),
  aiDiagnose: rpc.declare({object:'universal_openwrt',method:'ai_diagnose',params:['service']}),
  aiAuto: rpc.declare({object:'universal_openwrt',method:'ai_auto',params:['service']}),
  aiApply: rpc.declare({object:'universal_openwrt',method:'ai_apply',params:['service']}),
  aiPresets: rpc.declare({object:'universal_openwrt',method:'ai_preset_status',params:[]}),
  serviceModules: rpc.declare({object:'universal_openwrt',method:'service_modules',params:[]}),
  serviceModulesHealth: rpc.declare({object:'universal_openwrt',method:'service_modules_health',params:[]}),
  strategyGroupStatus: rpc.declare({object:'universal_openwrt',method:'strategy_group_status',params:[]}),
  strategyGroupApply: rpc.declare({object:'universal_openwrt',method:'strategy_group_apply',params:['group','strategy','confirm']}),
  strategyGroupDisable: rpc.declare({object:'universal_openwrt',method:'strategy_group_disable',params:['group','confirm']}),
  strategyGroupEnable: rpc.declare({object:'universal_openwrt',method:'strategy_group_enable',params:['group','confirm']}),
  telegramDetails: rpc.declare({object:'universal_openwrt',method:'telegram_details',params:[]}),
  tgWs: rpc.declare({object:'universal_openwrt',method:'tg_ws_status',params:[]}),
  tgControllerConfig: rpc.declare({object:'universal_openwrt',method:'telegram_controller_config',params:['enabled','mode','port','interval','fail_limit','confirm']}),
  serviceModuleEnable: rpc.declare({object:'universal_openwrt',method:'service_module_enable',params:['name','confirm']}),
  serviceModuleDisable: rpc.declare({object:'universal_openwrt',method:'service_module_disable',params:['name','confirm']}),
  serviceModuleRecover: rpc.declare({object:'universal_openwrt',method:'service_module_recover',params:['name','confirm']})
};

function out(r){ return r?.output || r?.error || 'Нет данных'; }
function injectStyle(){
  if(document.getElementById('uowrt-ui-style')) return;
  const css = `
.uowrt{--gap:14px;max-width:1280px;margin:0 auto;padding:8px 0 28px;color:var(--body-color,#333)}
.uowrt *{box-sizing:border-box}.uowrt button,.uowrt select{font:inherit}.uowrt .hero{display:flex;justify-content:space-between;gap:18px;align-items:flex-start;padding:20px;border-radius:18px;background:linear-gradient(135deg,rgba(80,120,180,.13),rgba(120,90,180,.08));border:1px solid rgba(127,127,127,.2);margin-bottom:var(--gap)}
.uowrt .hero h2{margin:0 0 7px;font-size:25px}.uowrt .hero p{margin:0;opacity:.78;max-width:760px;line-height:1.45}.uowrt .hero-actions{display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end}.uowrt .master{display:flex;align-items:center;gap:9px;padding:8px 10px;border:1px solid rgba(127,127,127,.2);border-radius:11px;background:rgba(127,127,127,.05);font-size:12px}.uowrt .master input{position:absolute;opacity:0;pointer-events:none}.uowrt .master-ui{width:42px;height:24px;border-radius:999px;background:#777;position:relative;transition:.2s;flex:0 0 auto}.uowrt .master-ui:after{content:"";position:absolute;width:18px;height:18px;left:3px;top:3px;border-radius:50%;background:#fff;transition:.2s}.uowrt .master input:checked+.master-ui{background:#2e9b61}.uowrt .master input:checked+.master-ui:after{transform:translateX(18px)}.uowrt .master-text{font-weight:700}.uowrt .master-sub{display:block;opacity:.62;font-weight:400;margin-top:1px}.uowrt .advanced-shell{display:none;margin-top:var(--gap)}.uowrt .advanced-shell.open{display:block}.uowrt .advanced-grid{display:grid;grid-template-columns:repeat(12,minmax(0,1fr));gap:var(--gap)}.uowrt .advanced-grid .card{grid-column:span 4}.uowrt .advanced-grid .wide{grid-column:span 8}.uowrt .advanced-grid .full{grid-column:1/-1}.uowrt .master-note{margin:0 0 12px;padding:10px 12px;border-radius:10px;background:rgba(210,138,37,.09);font-size:12px;line-height:1.45}.uowrt .master-note strong{display:block;margin-bottom:2px}
.uowrt .grid{display:grid;grid-template-columns:repeat(12,minmax(0,1fr));gap:var(--gap)}.uowrt .card{grid-column:span 4;background:var(--background-color,#fff);border:1px solid rgba(127,127,127,.2);border-radius:16px;padding:16px;min-width:0;box-shadow:0 2px 12px rgba(0,0,0,.035)}.uowrt .wide{grid-column:span 8}.uowrt .full{grid-column:1/-1}
.uowrt .card h3{margin:0 0 6px;font-size:17px}.uowrt .hint{font-size:13px;line-height:1.45;opacity:.68;margin:0 0 13px}.uowrt .statusline{display:flex;align-items:center;gap:9px;font-weight:600;margin:10px 0}.uowrt .dot{width:10px;height:10px;border-radius:50%;background:#999;flex:0 0 auto}.uowrt .dot.ok{background:#3a9d5d}.uowrt .dot.warn{background:#d28a25}.uowrt .dot.bad{background:#c95050}
.uowrt .actions{display:flex;flex-wrap:wrap;gap:8px}.uowrt .action{border-radius:10px!important;min-height:38px;padding:8px 13px!important}.uowrt .primary{font-weight:700}.uowrt .danger{border-color:#b44;background:transparent}.uowrt .secondary{opacity:.88}.uowrt .selectrow{display:flex;gap:8px;align-items:center;margin-top:10px}.uowrt .selectrow label{font-size:13px;opacity:.7}.uowrt select{min-height:36px;border-radius:9px;padding:5px 9px}
.uowrt .module-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}.uowrt .module-health{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;margin-top:10px}.uowrt .health-tile{padding:9px;border:1px solid rgba(127,127,127,.16);border-radius:11px;background:rgba(127,127,127,.035)}.uowrt .health-top{display:flex;justify-content:space-between;gap:8px;align-items:center}.uowrt .health-value{font-weight:800;font-size:16px}.uowrt .health-meta{font-size:11px;opacity:.62;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.uowrt .health-bar{height:5px;border-radius:99px;background:rgba(127,127,127,.12);overflow:hidden;margin-top:7px}.uowrt .health-bar>span{display:block;height:100%;background:currentColor}.uowrt .module-item{display:flex;justify-content:space-between;align-items:center;gap:10px;padding:11px;border:1px solid rgba(127,127,127,.18);border-radius:12px;background:rgba(127,127,127,.035)}.uowrt .ai-list{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-top:10px}.uowrt .ai-item{border:1px solid rgba(127,127,127,.18);border-radius:11px;padding:10px;display:flex;justify-content:space-between;gap:8px;align-items:center}.uowrt .badge{font-size:11px;padding:3px 7px;border-radius:999px;background:rgba(127,127,127,.12);white-space:nowrap}.uowrt .badge.ok{background:rgba(60,160,90,.13);color:#287442}.uowrt .badge.bad{background:rgba(200,70,70,.12);color:#a53c3c}.uowrt pre.uowrt-log{white-space:pre-wrap;max-height:360px;overflow:auto;margin:0;border-radius:11px;padding:12px;background:rgba(127,127,127,.07);font-size:12px;line-height:1.4}
.uowrt .automation-head{display:flex;align-items:center;justify-content:space-between;gap:16px}.uowrt .automation-settings{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:12px 0}.uowrt .automation-settings label{display:flex;flex-direction:column;gap:6px;font-size:13px}.uowrt .automation-settings input,.uowrt .automation-settings select{min-height:38px;padding:7px 10px;border-radius:10px;border:1px solid rgba(127,127,127,.25);background:var(--background-color,#fff);color:inherit}.uowrt .switch{display:inline-flex;align-items:center;gap:9px;cursor:pointer;user-select:none}.uowrt .automation-toggle{position:absolute;opacity:0;pointer-events:none}.uowrt .switch-ui{width:46px;height:26px;border-radius:999px;background:#888;position:relative;transition:.2s}.uowrt .switch-ui:after{content:"";position:absolute;width:20px;height:20px;left:3px;top:3px;border-radius:50%;background:#fff;transition:.2s}.uowrt .automation-toggle:checked+.switch-ui{background:#2e9b61}.uowrt .automation-toggle:checked+.switch-ui:after{transform:translateX(20px)}.uowrt .switch-text{font-weight:600}.uowrt .details{margin-top:var(--gap)}.uowrt details{border:1px solid rgba(127,127,127,.2);border-radius:14px;padding:0 14px}.uowrt summary{cursor:pointer;padding:14px 2px;font-weight:700;list-style:none}.uowrt summary::-webkit-details-marker{display:none}.uowrt .detail-body{padding:0 0 14px}.uowrt .help{margin-top:12px;padding:10px 12px;border-radius:10px;background:rgba(127,127,127,.07);font-size:12px;line-height:1.45}
.uowrt .assistant{grid-column:1/-1;border:1px solid rgba(80,120,180,.28);background:linear-gradient(135deg,rgba(80,120,180,.08),rgba(120,90,180,.05));border-radius:16px;padding:16px;margin-bottom:var(--gap)}
.uowrt .assistant-head{display:flex;justify-content:space-between;gap:14px;align-items:flex-start}.uowrt .assistant-head h3{margin:0 0 5px}.uowrt .assistant-head p{margin:0;opacity:.72;font-size:13px;line-height:1.45}.uowrt .assistant-steps{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:7px;margin:14px 0}.uowrt .step{padding:8px 9px;border-radius:9px;background:rgba(127,127,127,.08);font-size:11px;opacity:.62}.uowrt .step.active{opacity:1;font-weight:700;background:rgba(80,120,180,.16)}.uowrt .step.done{opacity:.9}.uowrt .assistant-progress{height:6px;border-radius:99px;background:rgba(127,127,127,.12);overflow:hidden}.uowrt .assistant-progress>span{display:block;height:100%;width:0%;transition:width .25s ease;background:currentColor}.uowrt .assistant-body{margin-top:14px}.uowrt .assistant-stage{display:flex;gap:10px;align-items:flex-start;padding:12px;border-radius:11px;background:rgba(127,127,127,.06);margin-bottom:9px}.uowrt .assistant-stage .stage-dot{width:9px;height:9px;border-radius:50%;margin-top:5px;background:#999;flex:0 0 auto}.uowrt .assistant-stage.running .stage-dot{background:#4f7db7;box-shadow:0 0 0 5px rgba(79,125,183,.12)}.uowrt .assistant-stage.ok .stage-dot{background:#3a9d5d}.uowrt .assistant-stage.warn .stage-dot{background:#d28a25}.uowrt .assistant-stage.bad .stage-dot{background:#c95050}.uowrt .assistant-result{padding:13px;border:1px solid rgba(127,127,127,.18);border-radius:11px;margin-top:10px}.uowrt .assistant-result h4{margin:0 0 5px}.uowrt .assistant-result p{margin:0;font-size:13px;line-height:1.5}.uowrt .assistant-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}.uowrt .assistant-result details{margin-top:12px}.uowrt .assistant-result summary{padding:8px 0;font-size:12px}.uowrt .assistant-result .uowrt-log{max-height:260px;margin-top:6px}.uowrt .assistant .selectrow select{min-width:180px}
.uowrt .wireguard-block{cursor:pointer}.uowrt .wireguard-block:hover{box-shadow:0 5px 18px rgba(0,0,0,.07);transform:translateY(-1px)}.uowrt .wireguard-summary{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin:12px 0}.uowrt .wireguard-summary>div{padding:10px;border:1px solid rgba(127,127,127,.16);border-radius:11px;background:rgba(127,127,127,.035)}
.uowrt .scope-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.uowrt .scope-card{position:relative;cursor:pointer;min-height:142px;padding:15px;border:1px solid rgba(127,127,127,.2);border-radius:15px;background:var(--background-color,#fff);transition:transform .15s ease,border-color .15s ease,box-shadow .15s ease}.uowrt .scope-card:hover{transform:translateY(-1px);box-shadow:0 5px 18px rgba(0,0,0,.07)}.uowrt .scope-card.active{border-color:rgba(46,155,97,.55);box-shadow:inset 0 0 0 1px rgba(46,155,97,.12)}.uowrt .scope-card.disabled{opacity:.64}.uowrt .scope-head{display:flex;justify-content:space-between;gap:10px;align-items:flex-start}.uowrt .scope-icon{width:34px;height:34px;border-radius:10px;display:flex;align-items:center;justify-content:center;background:rgba(80,120,180,.11);font-size:18px}.uowrt .scope-title{font-weight:800;font-size:15px}.uowrt .scope-state{font-size:11px;margin-top:4px;opacity:.7}.uowrt .scope-strategy{font-size:12px;opacity:.7;margin-top:10px;min-height:18px}.uowrt .scope-toggle{display:flex;align-items:center;gap:7px;font-size:11px;white-space:nowrap}.uowrt .scope-toggle input{position:absolute;opacity:0}.uowrt .scope-toggle-ui{width:38px;height:22px;border-radius:999px;background:#777;position:relative}.uowrt .scope-toggle-ui:after{content:"";position:absolute;width:16px;height:16px;left:3px;top:3px;border-radius:50%;background:#fff;transition:.18s}.uowrt .scope-toggle input:checked+.scope-toggle-ui{background:#2e9b61}.uowrt .scope-toggle input:checked+.scope-toggle-ui:after{transform:translateX(16px)}.uowrt .scope-open{margin-top:10px;font-size:11px;opacity:.58}.uowrt .tg-detail{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:10px}.uowrt .tg-detail-card{padding:12px;border:1px solid rgba(127,127,127,.18);border-radius:12px;background:rgba(127,127,127,.035)}.uowrt .tg-detail-card strong{display:block;margin-bottom:6px}.uowrt .kv{display:grid;grid-template-columns:130px minmax(0,1fr);gap:5px 10px;font-size:12px}.uowrt .kv b{opacity:.62;font-weight:500}.uowrt .share-link{display:block;word-break:break-all;margin-top:7px}.uowrt .copyline{display:flex;gap:7px;align-items:center;margin-top:7px}.uowrt .copyline input{flex:1;min-width:0;min-height:34px;border-radius:8px;border:1px solid rgba(127,127,127,.25);background:var(--background-color,#fff);color:inherit;padding:5px 8px}.uowrt .package-row{display:flex;justify-content:space-between;align-items:center;gap:10px;padding:10px 0;border-bottom:1px solid rgba(127,127,127,.12)}.uowrt .package-row:last-child{border-bottom:0}.uowrt .tg-secret{font-family:monospace;word-break:break-all}.uowrt .modal-section{margin-top:14px}.uowrt .modal-section h4{margin:0 0 8px}.uowrt .strategy-select{width:100%;min-height:38px}.uowrt .scope-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}
@media(max-width:900px){.uowrt .scope-grid{grid-template-columns:1fr 1fr}.uowrt .tg-detail{grid-template-columns:1fr}.uowrt .card,.uowrt .wide,.uowrt .advanced-grid .card,.uowrt .advanced-grid .wide{grid-column:1/-1}.uowrt .hero{display:block}.uowrt .hero-actions{justify-content:flex-start;margin-top:14px}.uowrt .ai-list{grid-template-columns:1fr 1fr}}
@media(max-width:560px){.uowrt .scope-grid{grid-template-columns:1fr}.uowrt .module-health{grid-template-columns:1fr 1fr}.uowrt .module-grid{grid-template-columns:1fr}.uowrt .automation-settings{grid-template-columns:1fr}.uowrt .automation-head{align-items:flex-start;flex-direction:column}.uowrt{padding:2px}.uowrt .hero{padding:15px;border-radius:14px}.uowrt .hero h2{font-size:21px}.uowrt .card{padding:13px;border-radius:13px}.uowrt .ai-list{grid-template-columns:1fr}.uowrt .action{width:100%}}
`;
  const style=document.createElement('style');style.id='uowrt-ui-style';style.textContent=css;document.head.appendChild(style);
}

function btn(label, fn, cls=''){
  return E('button',{class:'cbi-button action '+cls,click:function(){
    if(this.disabled)return; this.disabled=true; Promise.resolve(fn()).finally(()=>this.disabled=false);
  }},label);
}
function modal(title, value){
  ui.showModal(title,[E('pre',{class:'uowrt-log'},out(value)),E('div',{class:'right'},[E('button',{class:'btn cbi-button',click:ui.hideModal},'Закрыть')])]);
}
function confirmRun(title, text, fn){
  ui.showModal(title,[E('p',{},text),E('div',{class:'right'},[
    E('button',{class:'btn cbi-button',click:ui.hideModal},'Отмена'),
    E('button',{class:'btn cbi-button cbi-button-positive',click:()=>{ui.hideModal();fn();}},'Продолжить')
  ])]);
}
function parseStatus(s){
  const x=String(s||'');
  if(/dns_openwrt=0/.test(x)&&/https_openwrt=0/.test(x)) return ['ok','Связь с базовыми ресурсами работает'];
  if(/VERIFY=DEGRADED|DEGRADED/.test(x)) return ['warn','Есть проблемы, требуется диагностика'];
  if(/FAIL|error|ERROR/.test(x)) return ['bad','Обнаружена ошибка'];
  return ['warn','Состояние не определено'];
}

function statusReason(raw){
  const x=String(raw||'');
  if(/AUTH_BLOCK/.test(x)) return ['warn','Проблема похожа на авторизацию или ограничение аккаунта. Изменение сетевых правил само по себе это не исправит.'];
  if(/GEO_BLOCK|IP_BLOCK/.test(x)) return ['warn','Похоже на ограничение по IP/региону. DNS и DPI-настройки здесь могут не помочь; нужен отдельный внешний маршрут/relay, если он доступен.'];
  if(/DPI_BLOCK|TLS_BLOCK/.test(x)) return ['warn','Похоже на вмешательство DPI/TLS. Можно проверить профиль десинхронизации, не меняя настройки до подтверждения результата.'];
  if(/QUIC_BLOCK/.test(x)) return ['warn','Похоже на проблему HTTP/3/QUIC. Можно сравнить поведение TCP и QUIC перед изменением правил.'];
  if(/DNS_BLOCK/.test(x)) return ['warn','Похоже на проблему DNS. Сначала стоит проверить резолвинг и только затем выбирать DNS-стратегию.'];
  if(/PASS/.test(x)||(/dns_openwrt=0/.test(x)&&/https_openwrt=0/.test(x))) return ['ok','Базовая связность работает. Если конкретный сервис не открывается, проблема, вероятно, выше уровня обычного подключения.'];
  return ['warn','Диагностика не дала однозначного вывода. Сначала проверим базовую сеть и конкретный сервис.'];
}
function createAssistant(aiSelect){
  const box=E('section',{class:'assistant'});
  const title=E('h3',{},'Мастер диагностики');
  const desc=E('p',{},'Проверяет проблему по шагам: сеть → сервис → причина → кандидат → контрольный тест. До подтверждения конфигурация не изменяется; неудачный вариант откатывается.');
  const service=E('select',{} ,Array.from(aiSelect.options).map(o=>E('option',{value:o.value},o.textContent)));
  service.value=aiSelect.value;
  const steps=['Выбор','Сеть','Сервис','Причина','Действие'];
  const stepEls=steps.map((x,i)=>E('div',{class:'step'+(i===0?' active':'')},`${i+1}. ${x}`));
  const progress=E('span');
  const progressWrap=E('div',{class:'assistant-progress'},progress);
  const body=E('div',{class:'assistant-body'});
  const actions=E('div',{class:'assistant-actions'});
  const reason=E('div',{class:'assistant-result'},[
    E('h4',{},'Готово к проверке'),
    E('p',{},'Выберите сервис и запустите мастер.')
  ]);
  let running=false;
  let lastRaw='';
  function setStep(n){
    stepEls.forEach((e,i)=>{e.className='step '+(i<n?'done ':i===n?'active ':'');});
    progress.style.width=Math.min(100,Math.round((n/4)*100))+'%';
  }
  function stage(name,text,kind='running'){
    const el=E('div',{class:'assistant-stage '+kind},[
      E('span',{class:'stage-dot'}),
      E('div',{},[E('strong',{},name),E('div',{},text)])
    ]);
    body.appendChild(el);
    return el;
  }
  function clear(){body.innerHTML='';actions.innerHTML='';reason.innerHTML='';lastRaw='';}
  function technical(raw){
    if(!raw)return;
    const d=E('details',{},[
      E('summary',{},'Технические детали'),
      E('pre',{class:'uowrt-log'},raw)
    ]);
    reason.appendChild(d);
  }
  function finish(kind,titleText,text,raw){
    reason.className='assistant-result';
    reason.innerHTML='';
    reason.appendChild(E('h4',{},titleText));
    reason.appendChild(E('p',{},text));
    technical(raw);
    actions.innerHTML='';
    if(kind==='ok'){
      actions.appendChild(E('button',{class:'cbi-button action primary',click:()=>{
        aiSelect.value=service.value; aiDiag();
      }},'Открыть подробности'));
    }
    if(kind==='warn'){
      actions.appendChild(E('button',{class:'cbi-button action primary cbi-button-positive',click:()=>confirmRun(
        'Автонастройка',
        'Запустить подтверждаемый автоматический подбор. Система должна проверить вариант и откатить неудачное изменение.',
        ()=>api.adaptive({confirm:true}).then(r=>modal('Результат автонастройки',r)).then(refresh)
      )},'Запустить автонастройку'));
    }
    actions.appendChild(E('button',{class:'cbi-button action',click:()=>{
      clear();
      reason.appendChild(E('h4',{},'Готово к проверке'));
      reason.appendChild(E('p',{},'Можно запустить мастер ещё раз с другим сервисом.'));
      setStep(0);
    }},'Проверить снова'));
  }
  async function run(){
    if(running)return;
    running=true;
    clear();
    setStep(1);
    const id=service.value;
    const label=service.options[service.selectedIndex].textContent;
    try{
      const s1=stage('Сеть','Проверяем DNS, HTTPS, маршрут и базовую доступность…');
      const v=await api.verify();
      const vr=out(v);
      lastRaw+='=== NETWORK ===\n'+vr+'\n\n';
      const networkFailed=/VERIFY=FAIL|dns_openwrt=1|https_openwrt=1/.test(vr);
      s1.className='assistant-stage '+(networkFailed?'warn':'ok');
      s1.lastElementChild.lastElementChild.textContent=networkFailed
        ? 'Есть базовые сетевые проблемы. Проверим сервис, но сетевую стратегию пока не применяем.'
        : 'Базовая проверка завершена.';
      setStep(2);

      const s2=stage('Сервис','Проверяем '+label+' и собираем признаки блокировки…');
      const a=await api.aiDiagnose({service:id});
      const ar=out(a);
      lastRaw+='=== AI DIAGNOSIS ===\n'+ar+'\n\n';
      s2.className='assistant-stage ok';
      s2.lastElementChild.lastElementChild.textContent='Диагностика сервиса завершена.';
      setStep(3);

      const [kind,msg]=statusReason(ar);
      const statusMatch=ar.match(/(?:^|\n)status=([^\n]+)/);
      const status=statusMatch?statusMatch[1].trim():'';
      const s3=stage('Причина',msg,kind==='ok'?'ok':'warn');
      s3.lastElementChild.lastElementChild.textContent=status ? msg+' Код: '+status+'.' : msg;
      setStep(4);

      const s4=stage('Действие','Определяем безопасное следующее действие. Конфигурация пока не меняется.');
      const rec=await api.aiAuto({service:id});
      const rr=out(rec);
      lastRaw+='=== SAFE RECOMMENDATION ===\n'+rr+'\n';
      s4.className='assistant-stage '+(kind==='ok'?'ok':'warn');
      s4.lastElementChild.lastElementChild.textContent=rr||'Рекомендация не получена.';
      setStep(4);

      if(kind==='ok'){
        finish('ok','Сейчас вмешательство не требуется','Сеть и выбранный сервис доступны. Сохранять новую стратегию не нужно.',lastRaw);
      }else if(networkFailed && !status){
        finish('warn','Сначала исправляем базовую сеть','Проверка показала проблему на уровне DNS/HTTPS/маршрута. Изменение DPI-стратегии до исправления базовой сети может скрыть настоящую причину.',lastRaw);
      }else{
        finish('warn','Найдена причина для дальнейшей проверки',msg+' Автоматическое изменение не выполнялось. '+rr,lastRaw);
      }
    }catch(err){
      const msg=String(err?.message||err||'Неизвестная ошибка');
      stage('Ошибка',msg,'bad');
      setStep(4);
      finish('bad','Диагностика остановлена','Настройки не изменялись. Проверьте журнал и повторите проверку.',lastRaw+'=== ERROR ===\n'+msg);
    }finally{
      running=false;
    }
  }
  service.addEventListener('change',()=>{aiSelect.value=service.value;});
  box.appendChild(E('div',{class:'assistant-head'},[
    E('div',{},[title,desc]),
    E('div',{class:'selectrow'},[E('label',{},'Сервис'),service])
  ]));
  box.appendChild(E('div',{class:'assistant-steps'},stepEls));
  box.appendChild(progressWrap);
  box.appendChild(body);
  box.appendChild(reason);
  box.appendChild(actions);
  actions.appendChild(E('button',{class:'cbi-button action primary',click:run},'Начать диагностику'));
  return box;
}

function remoteConfigModal(title, raw){
  const x=out(raw), m=x.match(/QR_SVG_BEGIN\n([\s\S]*?)\nQR_SVG_END/);
  const cfg=x.replace(/\nQR_SVG_BEGIN[\s\S]*?QR_SVG_END\n?/,'').trim();
  const body=[E('p',{class:'hint'},'Устройство создано. Основной способ подключения — QR-код. Конфигурация ниже является резервным способом импорта.')];
  if(m&&m[1]){
    const qr=E('div',{style:'display:flex;justify-content:center;align-items:center;padding:18px;background:#fff;border-radius:12px;overflow:auto;min-height:280px'},[]);
    qr.innerHTML=m[1];
    body.push(E('h4',{},'QR-код — сканируйте в WireGuard'));
    body.push(qr);
  } else {
    body.push(E('div',{class:'help'},'QR-код не сформирован: на роутере отсутствует qrencode. Установите пакет qrencode и повторите операцию.'));
  }
  body.push(E('details',{},[E('summary',{},'Показать конфигурацию'),E('pre',{class:'uowrt-log'},cfg)]));
  body.push(E('div',{class:'right'},[E('button',{class:'btn cbi-button',click:ui.hideModal},'Готово')]));
  ui.showModal(title,body);
}

function wireguardTunnelModal(raw){
  const x=out(raw), lines=x.split('\n').filter(Boolean), kv={};
  lines.forEach(line=>{const m=line.match(/^([^=\t]+)=(.*)$/);if(m)kv[m[1]]=m[2];});
  const pass=/remote WireGuard isolation: PASS/.test(x), white=kv.white_ip==='yes';
  const setupNeeded=/not configured|missing|not setup|не настроен/i.test(x);
  const primaryAction=()=>confirmRun(setupNeeded?'Настроить WireGuard':'Проверить WireGuard',setupNeeded?'Создать изолированный интерфейс WireGuard. Это не изменяет AWG/WARP и не включает VPN для устройств автоматически.':'Проверить интерфейс, firewall, устройства и изоляцию без изменения рабочих настроек.',()=>setupNeeded?api.remoteWgSetup({confirm:true}).then(r=>modal('WireGuard',r)).then(refresh):api.remoteWgDiagnose().then(r=>wireguardTunnelModal(r)));
  const body=[
    E('div',{class:'statusline'},[E('span',{class:'dot '+(pass?'ok':'warn')}),E('strong',{},pass?'WireGuard готов':'Требуется настройка или проверка')]),
    E('p',{class:'hint'},'Есть два независимых режима для устройств. Режим выбирается отдельно для каждого устройства и не подключается к AWG/WARP, Telegram или Strategy Engine.'),
    E('div',{class:'tg-detail-card modal-section'},[
      E('h4',{},'Режим 1 · Remote WireGuard'),
      E('p',{class:'hint'},'Удалённый доступ к роутеру и сети WireGuard. На клиенте через туннель идёт только 10.66.66.0/24. Обычный интернет клиента остаётся через его Wi‑Fi/мобильную сеть. NAT и forwarding в WAN не используются.'),
      E('div',{class:'help'},'Подходит для доступа к роутеру и внутренним ресурсам без перенаправления всего интернет-трафика.'),
      E('h4',{},'Режим 2 · WireGuard VPN'),
      E('p',{class:'hint'},'Полный IPv4 интернет через этот роутер. Для устройства создаётся AllowedIPs = 0.0.0.0/0, включается forwarding из WireGuard в WAN и NAT. AWG/WARP при этом не используются.'),
      E('div',{class:'help'},'Важно: текущая реализация VPN — IPv4. IPv6 не маршрутизируется через этот туннель, поэтому IPv6 на клиенте может идти напрямую, если он доступен.'),
      E('h4',{},'Публичный IPv4'),
      E('div',{class:'kv'},[E('b',{},'WAN IPv4'),E('span',{},kv.wan_ipv4||'проверяется'),E('b',{},'Внешний IPv4'),E('span',{},kv.public_ipv4||'проверяется'),E('b',{},'Белый IP'),E('span',{},white?'Да · подтверждён':'Нет / не подтверждён')]),
      E('p',{class:'help'},white?'Прямая работа входящего WireGuard подтверждена по признакам публичного IPv4. Также должен быть доступен UDP-порт 51820.':'⚠️ Для прямого входящего WireGuard корректная работа не гарантируется. Нужен публичный (белый) IPv4 либо отдельная relay/VPS-схема; CGNAT напрямую не гарантируется.'),
      E('div',{class:'actions'},[
        btn(setupNeeded?'Настроить WireGuard':'Проверить диагностику',primaryAction,'primary'),
        btn('Добавить устройство',()=>wireguardAddDeviceModal()),
        btn('Устройства',()=>api.remoteWgList().then(remoteDevicesModal))
      ])
    ]),
    E('details',{class:'modal-section'},[E('summary',{},'Подробности диагностики'),E('pre',{class:'uowrt-log'},x)])
  ];
  ui.showModal('WireGuard туннель',body);
}

function wireguardAddDeviceModal(){
  const input=E('input',{type:'text',placeholder:'Например: iPhone, MacBook, Ноутбук',class:'strategy-select',maxlength:48});
  const mode=E('select',{class:'strategy-select'},[E('option',{value:'remote'},'Remote WireGuard — только доступ к сети'),E('option',{value:'vpn'},'WireGuard VPN — весь IPv4 интернет')]);
  const desc=E('div',{class:'help'},'Remote WireGuard: интернет устройства не меняется. WireGuard VPN: IPv4 трафик устройства проходит через роутер, требуется белый IPv4/доступный UDP 51820.');
  mode.addEventListener('change',()=>{desc.textContent=mode.value==='vpn'?'WireGuard VPN: IPv4 трафик устройства проходит через роутер (0.0.0.0/0 + NAT). Нужен белый IPv4/доступный UDP 51820. IPv6 пока не входит в VPN.':'Remote WireGuard: через туннель идёт только сеть 10.66.66.0/24. Обычный интернет устройства остаётся без изменений.';});
  const body=[E('p',{class:'hint'},'Выберите режим сразу при создании. Его можно позже изменить без перевыпуска ключей.'),E('div',{class:'modal-section'},[E('h4',{},'Название устройства'),input,E('h4',{},'Режим'),mode,desc]),E('div',{class:'actions'},[btn('Создать устройство',()=>{const name=input.value.trim();if(!name)return modal('WireGuard',{output:'Укажите название устройства.'});return api.remoteWgAdd({name,mode:mode.value}).then(r=>{if(!r?.ok)return modal('WireGuard · ошибка',r);remoteConfigModal('Новое устройство — '+name,r);return refresh();});},'primary'),btn('Отмена',()=>ui.hideModal())])];
  ui.showModal('Добавить устройство · WireGuard',body);
}

function remoteDevicesModal(raw){
  const x=out(raw), lines=x.split('\n').slice(1).filter(Boolean);
  const body=[E('p',{class:'hint'},'Устройства WireGuard. Адрес, ключи и peer создаются автоматически. Статус online определяется по последнему handshake.')];
  if(!lines.length){ body.push(E('div',{class:'help'},'Устройств пока нет.')); }
  lines.forEach(line=>{
    const a=line.split('\t'), name=a[0]||'', addr=a[1]||'', ep=a[2]||'', mode=(a[3]||'').replace('mode=','')||'remote', st=a.slice(4).join('\t')||'';
    const state=(st.match(/state=([^\t]+)/)||[])[1]||'unknown';
    const stateLabel={online:'онлайн',inactive:'неактивен','never-connected':'не подключался',revoked:'отозван',offline:'offline'}[state]||state;
    const title=E('div',{},[E('strong',{},name),E('div',{class:'health-meta'},addr+' · '+ep)]);
    const meta=E('div',{class:'health-meta'},stateLabel+' · '+(mode==='vpn'?'WireGuard VPN':'Remote WireGuard'));
    const modeSelect=E('select',{class:'strategy-select'},[E('option',{value:'remote'},'Remote WireGuard'),E('option',{value:'vpn'},'WireGuard VPN')]); modeSelect.value=mode; modeSelect.addEventListener('change',()=>api.remoteWgSetMode({name,mode:modeSelect.value}).then(r=>{if(!r?.ok)return modal('WireGuard · ошибка',r);return remoteConfigModal('Режим изменён — '+name,r);}).then(refresh));
    const row=E('div',{class:'module-item'},[E('div',{},[title,meta]),E('div',{class:'actions'},[
      E('div',{class:'selectrow'},[E('label',{},'Режим'),modeSelect]),btn('QR',()=>api.remoteWgQr({name}).then(r=>remoteConfigModal('QR — '+name,r)),'primary'),
      btn('Конфигурация',()=>api.remoteWgConfig({name}).then(r=>remoteConfigModal('WireGuard — '+name,r))),
      btn('Перевыпустить',()=>confirmRun('Перевыпустить устройство','Старый ключ будет отозван, а для этого же имени создан новый peer и новый QR-код.',()=>api.remoteWgRegenerate({name,confirm:true}).then(r=>remoteConfigModal('Новое устройство — '+name,r)))),
      btn('Отозвать',()=>confirmRun('Отозвать устройство','Устройство потеряет доступ, но запись останется в списке.',()=>api.remoteWgRevoke({name,confirm:true}).then(r=>modal('WireGuard — '+name,r)).then(refresh)),'danger'),
      btn('Удалить',()=>confirmRun('Удалить устройство','Peer и локальная запись устройства будут удалены. Это не затронет другие peers.',()=>api.remoteWgRemove({name,confirm:true}).then(r=>modal('WireGuard — '+name,r)).then(refresh)),'danger')
    ])]);
    body.push(row);
  });
  body.push(E('div',{class:'right'},[E('button',{class:'btn cbi-button',click:ui.hideModal},'Закрыть')]));
  ui.showModal('Устройства WireGuard',body);
}

return view.extend({
  load:()=>Promise.all([api.status(),api.matrix(),api.awg(),api.tg(),api.aiCatalog(),api.aiPresets(),api.logs(),api.automationStatus(),api.serviceModules(),api.serviceModulesHealth(),api.strategyGroupStatus(),api.tgBackends(),api.remoteWgDiagnose()]),
  render:function(data){
    injectStyle();
    const root=E('div',{class:'uowrt'});
    let state=data[0], aiCatalog=data[4], automation=data[7], wgDiag=out(data[12]);
    const speed=E('select',{},['quick','standard','deep'].map(x=>E('option',{value:x},x==='quick'?'Быстро':x==='deep'?'Глубоко':'Стандартно')));
    const aiSelect=E('select',{},[E('option',{value:'openai'},'ChatGPT / OpenAI'),E('option',{value:'anthropic'},'Claude / Anthropic'),E('option',{value:'google-gemini'},'Gemini / Google'),E('option',{value:'kimi'},'Kimi'),E('option',{value:'deepseek'},'DeepSeek'),E('option',{value:'perplexity'},'Perplexity'),E('option',{value:'mistral'},'Mistral'),E('option',{value:'grok'},'Grok / xAI'),E('option',{value:'copilot'},'Copilot'),E('option',{value:'huggingface'},'Hugging Face'),E('option',{value:'poe'},'Poe'),E('option',{value:'cohere'},'Cohere'),E('option',{value:'openrouter'},'OpenRouter'),E('option',{value:'youtube'},'YouTube'),E('option',{value:'instagram'},'Instagram'),E('option',{value:'x'},'X / Twitter')]);

    const stateTitle=E('div',{},'Проверяем…'), stateHint=E('p',{class:'hint'},'Здесь будет краткое состояние маршрутизации и соединения.'), dot=E('span',{class:'dot'});
    const aiList=E('div',{class:'ai-list'});
    const log=E('pre',{class:'uowrt-log'},out(data[6]));
    const automationTitle=E('div',{},'Загружаем…');
    const automationHint=E('p',{class:'hint'},'Автоматический подбор выключен по умолчанию. Настройте время и периодичность только если хотите, чтобы роутер сам перепроверял стратегию.');
    const automationActions=E('div',{class:'actions'});
    const automationTime=E('input',{type:'time',value:'04:00',class:'automation-time'});
    const automationInterval=E('select',{class:'automation-interval'},[['1','Каждый час'],['2','Каждые 2 часа'],['3','Каждые 3 часа'],['4','Каждые 4 часа'],['6','Каждые 6 часов'],['8','Каждые 8 часов'],['12','Каждые 12 часов'],['24','Раз в сутки']].map(x=>E('option',{value:x[0]},x[1])));
    const automationToggle=E('input',{type:'checkbox',class:'automation-toggle'});
    const automationToggleLabel=E('label',{class:'switch'},[automationToggle,E('span',{class:'switch-ui'}),E('span',{class:'switch-text'},'Автоматический подбор')]);
    function parseAutomation(x){ const hm=(x.match(/schedule=(\d{2}):(\d{2})/)||[]); return {enabled:/enabled=1/.test(x),hour:hm[1]||'04',minute:hm[2]||'00',interval:(x.match(/interval_hours=(\d+)/)||[])[1]||'24'}; }
    function saveAutomation(enable){ const t=automationTime.value||'04:00', parts=t.split(':'); return api.automationConfig({enabled:!!enable,hour:Number(parts[0]||4),minute:Number(parts[1]||0),interval_hours:Number(automationInterval.value||24),confirm:true}).then(r=>{modal(enable?'Автоматизация включена':'Расписание сохранено',r);return refresh();}); }
    function renderAutomation(r){
      automation=r; const x=out(r), cfg=parseAutomation(x); automationToggle.checked=cfg.enabled; automationTime.value=cfg.hour+':'+cfg.minute; automationInterval.value=cfg.interval;
      automationTitle.innerHTML=''; automationTitle.className='statusline'; automationTitle.appendChild(E('span',{class:'dot '+(cfg.enabled?'ok':'warn')})); automationTitle.appendChild(document.createTextNode(cfg.enabled?'Включена':'Выключена'));
      const strat=(x.match(/last_strategy=([^\n]+)/)||[])[1]||'baseline', rc=(x.match(/last_rc=([^\n]+)/)||[])[1]||'не запускалась';
      automationHint.textContent=cfg.enabled ? `Проверка запускается в ${cfg.hour}:${cfg.minute} и повторяется: ${automationInterval.options[automationInterval.selectedIndex]?.textContent||cfg.interval+' ч'}. Время — локальное время роутера.` : 'Расписание можно настроить заранее, но автоматическая проверка сейчас выключена.';
      automationActions.innerHTML=''; automationActions.appendChild(btn('Сохранить расписание',()=>saveAutomation(cfg.enabled),'primary')); automationActions.appendChild(btn('Запустить сейчас',()=>confirmRun('Ежедневный подбор','Запустить полный сравнительный тест сейчас?',()=>api.automationRun({confirm:true}).then(r=>modal('Результат ежедневного подбора',r)).then(refresh)))); automationActions.appendChild(btn('Статус',()=>api.automationStatus().then(r=>modal('Автоматический подбор',r)))); automationActions.appendChild(E('span',{class:'badge'},'Последняя стратегия: '+strat+' · rc='+rc));
    }
    automationToggle.addEventListener('change',()=>{ const enabled=automationToggle.checked; confirmRun(enabled?'Включить автоматический подбор':'Выключить автоматический подбор', enabled?`Запускать проверку в ${automationTime.value||'04:00'} с периодичностью «${automationInterval.options[automationInterval.selectedIndex].textContent}»?`:'Расписание будет сохранено, но автоматическая проверка запускаться не будет.',()=>saveAutomation(enabled)).catch(()=>{}); });
    renderState(state); renderAI(aiCatalog); renderAutomation(automation); renderModules(data[8],data[9]); renderGroups(data[10],data[8]);renderTelegramBackends(data[11]);
    api.remoteWgStatus().then(r=>{const x=out(r),dot=document.getElementById('uowrt-remote-wg-dot'),st=document.getElementById('uowrt-remote-wg-status');if(!dot||!st)return;dot.className='dot '+(/remote WireGuard isolation: PASS/.test(x)?'ok':'warn');st.textContent=/remote WireGuard isolation: PASS/.test(x)?'Готов: изолирован от маршрутизации':'Не настроен или требует проверки';}).catch(()=>{});

    function renderGroups(raw){const host=document.getElementById('uowrt-group-status');if(!host)return;const labels={youtube:'YouTube',social:'Социальные сети',ai:'AI',gaming:'Игры',telegram:'Telegram',streaming:'Видео и музыка',messaging:'Мессенджеры',developer:'Разработка',news:'Новости'};const icons={youtube:'▶',social:'◎',ai:'✦',gaming:'🎮',telegram:'✈',streaming:'♫',messaging:'💬',developer:'⌘',news:'📰'};const defaults={youtube:'dpi-youtube-auto',social:'dpi',ai:'dpi',gaming:'dpi-game',telegram:'tg-socks5',streaming:'awg-full',messaging:'dpi-discord',developer:'awg-full',news:'awg-full'};const lines=out(raw).split('\n').filter(x=>x&&x.indexOf('group\t')!==0);const map={};lines.forEach(line=>{const p=line.split('\t');if(p.length>=5)map[p[0]]={strategy:p[1],scope:p[2],status:p[3]};});const moduleMap={};out(modulesRaw).split('\n').forEach(line=>{const p=line.split('\t');if(p.length>=2)moduleMap[p[0]]=p[1]==='1';});host.innerHTML='';Object.keys(labels).forEach(g=>{const st=map[g]||{strategy:defaults[g],scope:'global',status:moduleMap[g]===false?'disabled':'active'};const active=st.status==='active';const toggle=E('input',{type:'checkbox',checked:active});toggle.addEventListener('click',e=>e.stopPropagation());toggle.addEventListener('change',()=>{toggle.disabled=true;const fn=toggle.checked?api.strategyGroupEnable:api.strategyGroupDisable;confirmRun((toggle.checked?'Включить ':'Выключить ')+labels[g],toggle.checked?'Вернуть группу в автоматический подбор с профилем «'+(st.strategy||defaults[g])+'»?':'Исключить группу из автоматического подбора? Текущие настройки сохраняются.',()=>fn({group:g,confirm:true}).then(r=>modal(labels[g],r)).then(refresh)).catch(()=>{toggle.checked=!toggle.checked;toggle.disabled=false;});});const card=E('div',{class:'scope-card '+(active?'active':'disabled'),click:()=>openGroupSettings(g,st,labels[g])},[E('div',{class:'scope-head'},[E('div',{class:'scope-icon'},icons[g]),E('div',{style:'flex:1'},[E('div',{class:'scope-title'},labels[g]),E('div',{class:'scope-state'},active?'ВКЛЮЧЕН':'ВЫКЛЮЧЕН')]),E('label',{class:'scope-toggle',click:e=>e.stopPropagation()},[toggle,E('span',{class:'scope-toggle-ui'})])]),E('div',{class:'scope-strategy'},'Стратегия: '+(st.strategy||defaults[g])),E('div',{class:'scope-open'},'Нажмите для настроек и инструментов →')]);host.appendChild(card);});}
function openGroupSettings(group,state,label){const strategies={youtube:['dpi-youtube-auto','dpi','awg-full'],social:['dpi','awg-full','core'],ai:['dpi','awg-full','vless-tproxy'],gaming:['dpi-game','dpi','awg-full'],telegram:['tg-socks5','tg-ws','core'],streaming:['awg-full','dpi','vless-tproxy'],messaging:['dpi-discord','dpi','awg-full'],developer:['awg-full','dpi','vless-tproxy'],news:['awg-full','dpi','vless-tproxy']}[group]||['core','dpi','awg-full'];const select=E('select',{class:'strategy-select'},strategies.map(x=>E('option',{value:x},x)));select.value=strategies.includes(state.strategy)?state.strategy:strategies[0];const body=[E('p',{class:'hint'},'Этот контур управляется отдельно. Изменение стратегии проходит через общий шлюз конфликтов; другой активный глобальный контур не будет молча перезаписан.'),E('div',{class:'modal-section'},[E('h4',{},'Стратегия'),select]),E('div',{class:'scope-actions'},[btn('Применить',()=>confirmRun('Стратегия · '+label,'Применить выбранную стратегию только к этому контуру?',()=>api.strategyGroupApply({group,strategy:select.value,confirm:true}).then(r=>modal(label,r)).then(refresh)),'primary'),btn('Выключить контур',()=>confirmRun('Выключить · '+label,'Исключить этот контур из автоматического подбора?',()=>api.strategyGroupDisable({group,confirm:true}).then(r=>modal(label,r)).then(refresh)),'danger')])];if(group==='telegram')body.push(E('div',{class:'modal-section'},[E('h4',{},'Telegram'),E('p',{class:'hint'},'Telegram не смешивается с AI, AWG/WARP и другими группами. Здесь доступны отдельные движки, контроллер и выданные прокси-реквизиты.'),btn('Открыть все настройки Telegram',()=>openTelegramSettings())]));ui.showModal(label+' · настройки стратегии',body);}
function parseKv(raw){const m={};String(raw||'').split('\n').forEach(line=>{const i=line.indexOf('=');if(i>0)m[line.slice(0,i)]=line.slice(i+1);});return m;}
function toggleRow(title,enabled,onChange,sub){const input=E('input',{type:'checkbox',checked:enabled});input.addEventListener('change',()=>{input.disabled=true;Promise.resolve(onChange(input.checked)).then(()=>refresh()).finally(()=>input.disabled=false);});return E('div',{class:'package-row'},[E('div',{},[E('strong',{},title),sub?E('div',{class:'health-meta'},sub):null]),E('label',{class:'scope-toggle'},[input,E('span',{class:'scope-toggle-ui'})])]);}
function openTelegramSettings(){Promise.all([api.telegramDetails(),api.tgProxyStatus()]).then(rs=>{const detail=out(rs[0]);const external=out(rs[1]);const sections=detail.split(/\n--- ([^\n]+) ---\n/);const parts={};for(let i=1;i<sections.length;i+=2)parts[sections[i]]=sections[i+1]||'';const ctl=parseKv(parts.controller||'');const body=[E('p',{class:'hint'},'Telegram — отдельный контур. Включение одного движка не должно запускать остальные. Контроллер владеет выбором транспорта только когда он включён.')];const mode=E('select',{},['auto','off','socks5','ws','telemt'].map(x=>E('option',{value:x},x==='auto'?'Авто':x==='off'?'Выключен':x==='socks5'?'Go SOCKS5':x==='ws'?'WebSocket':'Rust Telemt')));mode.value=ctl.mode||'auto';const ctlToggle=E('input',{type:'checkbox',checked:ctl.enabled==='1'});const saveCtl=()=>api.tgControllerConfig({enabled:ctlToggle.checked,mode:mode.value,port:Number(ctl.port||1080),interval:Number(ctl.interval||15),fail_limit:Number(ctl.fail_limit||2),confirm:true}).then(r=>modal('Telegram Controller',r)).then(refresh);ctlToggle.addEventListener('change',()=>{ctlToggle.disabled=true;saveCtl().finally(()=>ctlToggle.disabled=false);});mode.addEventListener('change',saveCtl);body.push(E('div',{class:'modal-section'},[E('h4',{},'Пакеты и движки'),E('div',{class:'package-row'},[E('div',{},[E('strong',{},'Telegram Controller'),E('div',{class:'health-meta'},'Отдельный контроль Telegram без влияния на другие группы')]),E('label',{class:'scope-toggle'},[ctlToggle,E('span',{class:'scope-toggle-ui'})])]),E('div',{class:'package-row'},[E('div',{},[E('strong',{},'Режим контроллера'),E('div',{class:'health-meta'},'Auto / SOCKS5 / WS / Rust Telemt')]),mode]) ]));const addBackend=(title,raw,actions)=>{const kv=parseKv(raw);const enabled=kv.enabled==='1';const installed=kv.installed==='yes'||kv.configured==='yes';body.push(E('div',{class:'tg-detail-card modal-section'},[E('strong',{},title),E('div',{class:'health-meta'},'Состояние: '+(kv.active==='yes'||kv.running==='yes'?'активен':enabled?'включён':'выключен')+(installed?' · готов':' · не установлен')), ...actions]));if(kv.port||kv.secret||kv.tg_link){const items=[];if(kv.link_host||kv.host)items.push(E('div',{class:'kv'},[E('b',{},'Адрес'),E('span',{},kv.link_host||kv.host)]));if(kv.port)items.push(E('div',{class:'kv'},[E('b',{},'Порт'),E('span',{},kv.port)]));if(kv.secret&&kv.secret!=='missing'&&kv.secret!=='configured')items.push(E('div',{class:'kv'},[E('b',{},'Secret key'),E('span',{class:'tg-secret'},kv.secret)]));if(kv.tg_link){const inp=E('input',{value:kv.tg_link,readonly:true});items.push(E('div',{class:'copyline'},[inp,btn('Копировать',()=>navigator.clipboard?.writeText(kv.tg_link)||Promise.resolve())]));items.push(E('a',{class:'share-link',href:kv.tg_link},'Открыть / поделиться ссылкой Telegram'));}body.push(E('div',{class:'help'},items));}};addBackend('Go SOCKS5',parts['socks5-go']||'', [toggleRow('Включить Go SOCKS5',parseKv(parts['socks5-go']||'').enabled==='1',v=>v?api.tgEnable({confirm:true}):api.tgDisable({confirm:true}),'Порт '+(parseKv(parts['socks5-go']||'').port||'1080')),btn('Установить / обновить',()=>api.tgInstall().then(r=>modal('Go SOCKS5',r)).then(refresh))]);addBackend('WebSocket MTProto',parts.ws||'', [toggleRow('Включить WebSocket',parseKv(parts.ws||'').enabled==='1',v=>v?api.tgWsEnable({confirm:true}):api.tgWsDisable({confirm:true}),'Порт '+(parseKv(parts.ws||'').port||'1443'))]);addBackend('Rust Telemt',parts.telemt||'', [toggleRow('Включить Rust Telemt',parseKv(parts.telemt||'').enabled==='1',v=>v?api.tgTelemtEnable({confirm:true}):api.tgTelemtDisable({confirm:true}),'Порт '+(parseKv(parts.telemt||'').port||'2443')),btn('Установить Rust Telemt',()=>api.tgTelemtInstall().then(r=>modal('Rust Telemt',r)).then(refresh))]);body.push(E('div',{class:'tg-detail-card modal-section'},[E('strong',{},'Внешний SOCKS5 / sing-box'),E('div',{class:'health-meta'},external.replace(/\n/g,' · ')),toggleRow('Внешний SOCKS5',/enabled=1/.test(external),v=>v?api.tgProxyEnable({confirm:true}):api.tgProxyDisable({confirm:true}),'Настройки внешнего SOCKS5 хранятся отдельно и не смешиваются с локальными Telegram backend-ами.')]));ui.showModal('Telegram · пакеты и прокси',body);});}


    function refresh(){return Promise.all([api.status(),api.matrix(),api.awg(),api.tg(),api.aiCatalog(),api.aiPresets(),api.logs(),api.automationStatus(),api.serviceModules(),api.serviceModulesHealth(),api.strategyGroupStatus(),api.tgBackends()]).then(r=>{renderState(r[0]);renderAI(r[4]);log.textContent=out(r[6]);renderAutomation(r[7]);renderModules(r[8],r[9]);renderGroups(r[10],r[8]);renderTelegramBackends(r[11]);return r;});}
function renderTelegramBackends(raw){const host=document.getElementById('uowrt-tg-backends');if(!host)return;host.innerHTML='';const lines=out(raw).split('\n').filter(x=>/^backend\t/.test(x));if(!lines.length){host.textContent='Каталог Telegram-backend недоступен';return;}const labels={go:'Go · tg-ws-proxy',telemt:'Rust · Telemt',external:'sing-box · внешний SOCKS5',legacy:'Локальный WS-backend'};lines.forEach(line=>{const p=line.split('\t');const id=p[1]||'';const state=p[2]||'unknown';const supported=p[3]||'no';const active=p[4]||'no';const item=E('div',{class:'module-item'},[E('div',{},[E('strong',{},labels[id]||id),E('div',{class:'hint'},supported==='yes'?'Доступен для текущей платформы':'Недоступен/не настроен')]),E('span',{class:'badge '+(active==='yes'?'ok':state==='ready'?'':'bad')},active==='yes'?'АКТИВЕН':state)]);host.appendChild(item);});const oldActions=document.getElementById('uowrt-tg-backend-actions');if(oldActions)oldActions.remove();const actions=E('div',{id:'uowrt-tg-backend-actions',class:'actions',style:'margin-top:10px'},[btn('Установить Rust Telemt',()=>api.tgTelemtInstall().then(r=>modal('Telegram · Telemt',r)).then(refresh)),btn('Состояние backend-ов',()=>api.tgBackends().then(r=>modal('Telegram · backend-ы',r))) ]);host.parentNode.appendChild(actions);}
function renderModules(raw,healthRaw){const host=document.getElementById('uowrt-module-grid');const hh=document.getElementById('uowrt-module-health');if(!host)return;host.innerHTML='';const text=out(raw);const lines=text.split('\n').filter(x=>/^([a-z0-9_-]+)\t[01]\t/.test(x));const labels={youtube:'YouTube',social:'Социальные сети',gaming:'Игры',ai:'AI',telegram:'Telegram',streaming:'Видео и музыка',messaging:'Мессенджеры',developer:'Разработка',news:'Новости'};if(!lines.length){host.textContent=text||'Состояние модулей недоступно';return;}lines.forEach(line=>{const p=line.split('\t'),name=p[0],on=p[1]==='1';const toggle=E('input',{type:'checkbox',checked:on});toggle.addEventListener('change',()=>{const fn=toggle.checked?api.serviceModuleEnable:api.serviceModuleDisable;toggle.disabled=true;fn({name,confirm:true}).then(r=>modal(labels[name]||name,r)).then(refresh).catch(()=>{toggle.checked=!toggle.checked;toggle.disabled=false;});});const card=E('div',{class:'module-item'},[E('div',{},[E('strong',{},labels[name]||name),E('div',{class:'hint'},name==='telegram'?'Отдельный Telegram Controller':'Независимый контур подбора')]),E('label',{class:'master'},[toggle,E('span',{class:'master-ui'})])]);host.appendChild(card);});if(!hh)return;hh.innerHTML='';const hlines=out(healthRaw).split('\n').filter(x=>/^([a-z0-9_-]+)\t[01]\t/.test(x));hlines.forEach(line=>{const p=line.split('\t'),name=p[0],on=p[1]==='1',h=Math.max(0,Math.min(100,Number(p[3])||0)),pref=p[2]||'baseline',succ=p[4]||'0',fail=p[5]||'0',stab=p[8]||'0',cd=p[9]||'0';const tile=E('div',{class:'health-tile'},[E('div',{class:'health-top'},[E('strong',{},labels[name]||name),E('span',{class:'health-value'},on?h+'%':'OFF')]),E('div',{class:'health-meta'},on?'Профиль: '+pref:'Модуль отключён'),E('div',{class:'health-bar'},[E('span',{style:'width:'+h+'%'})]),E('div',{class:'health-meta'},on?'Успехи '+succ+' · ошибки '+fail+' · стабильность '+stab+'%'+(Number(cd)>Math.floor(Date.now()/1000)?' · cooldown':''):'Не участвует в подборе')]);hh.appendChild(tile);});}

    function runAuto(){confirmRun('Автонастройка','Проверить соединение, подобрать безопасную стратегию и применить только необходимое? Неудачный вариант должен быть откатан автоматически.',()=>api.adaptive({confirm:true}).then(r=>modal('Результат автонастройки',r)).then(refresh));}
    function verify(){return Promise.all([api.verify(),api.test()]).then(r=>modal('Проверка', {output:out(r[0])+'\n\n'+out(r[1])})).then(refresh);}
    function aiDiag(){const id=aiSelect.value;return api.aiDiagnose({service:id}).then(r=>modal('Диагностика '+aiSelect.options[aiSelect.selectedIndex].textContent,r)).then(refresh);}
    function aiAuto(){const id=aiSelect.value;return api.aiAuto({service:id}).then(r=>modal('Рекомендация для AI',r)).then(refresh);}

    const masterToggle=E('input',{type:'checkbox',id:'uowrt-master-toggle'});
    const masterText=E('span',{class:'master-text'},['MASTER',E('span',{class:'master-sub'},'ВКЛ — расширенные настройки и ручное управление')]);
    const masterLabel=E('label',{class:'master'},[masterToggle,E('span',{class:'master-ui'}),masterText]);
    const advancedShell=E('section',{class:'advanced-shell'});
    function setMaster(enabled){
      masterToggle.checked=!!enabled;
      advancedShell.classList.toggle('open',!!enabled);
      try{localStorage.setItem('uowrt.master',enabled?'1':'0');}catch(e){}
      if(!enabled) window.scrollTo({top:0,behavior:'smooth'});
    }
    try{setMaster(localStorage.getItem('uowrt.master')==='1');}catch(e){setMaster(false);}
    masterToggle.addEventListener('change',()=>setMaster(masterToggle.checked));

    root.appendChild(E('section',{class:'hero'},[
      E('div',{},[E('h2',{},'Universal OpenWrt'),E('p',{},'Простой режим скрывает технические настройки. Для обычной работы достаточно выбрать сервис, запустить диагностику и подтвердить найденное решение.'),E('div',{class:'help'},'MASTER выключен по умолчанию. В обычном режиме система сама диагностирует и применяет только подтверждённые изменения; MASTER открывает полный технический контроль.')]),
      E('div',{class:'hero-actions'},[masterLabel,btn('Проверить',verify,'primary'),btn('Автонастройка',runAuto,'primary cbi-button-positive'),btn('Обновить',refresh)])
    ]));

    root.appendChild(createAssistant(aiSelect));
    root.appendChild(E('div',{class:'grid'},[
      E('section',{class:'card wide'},[E('h3',{},'Состояние системы'),E('p',{class:'hint'},'Короткий ответ на главный вопрос: всё работает или нужно вмешательство?'),E('div',{class:'statusline'},[dot,stateTitle]),stateHint,E('div',{class:'actions'},[btn('Подробная проверка',verify),btn('Обновить экран',refresh)]),E('div',{class:'selectrow'},[E('label',{},'Глубина теста'),speed])]),
      E('section',{class:'card'},[E('h3',{},'AI и популярные сервисы'),E('p',{class:'hint'},'Проверяем DNS, TCP/HTTPS, IPv4/IPv6 и HTTP/3/QUIC на нескольких endpoint-доменах. Затем выбираем минимально необходимый способ: DNS → DPI/TCP → QUIC → AWG/relay → proxy. Каждый изменяющий шаг проверяется на самом сервисе.'),E('div',{class:'selectrow'},[E('label',{},'Сервис'),aiSelect]),E('div',{class:'actions',style:'margin-top:10px'},[btn('Диагностировать',aiDiag,'primary'),btn('Подобрать способ',aiAuto),btn('Применить с откатом',()=>confirmRun('Подбор для сервиса','Проверить кандидаты по очереди и откатывать неудачные изменения?',()=>api.aiApply({service:aiSelect.value}).then(r=>modal('Результат',r)).then(refresh)),'secondary')]),aiList]),
      E('section',{class:'card full'},[E('h3',{},'Контуры стратегий'),E('p',{class:'hint'},'Каждый блок показывает, участвует ли контур в автоматическом подборе. Игры и другие ненужные категории можно выключить прямо на блоке. Нажмите на блок, чтобы открыть стратегию и инструменты.'),E('div',{id:'uowrt-group-status',class:'scope-grid'}),E('div',{class:'help'},'Отключение контура исключает его из автоматического подбора и не удаляет сохранённые настройки. Глобальные стратегии проходят проверку конфликтов перед применением.')]),
      E('section',{class:'card wide wireguard-block',click:()=>api.remoteWgDiagnose().then(wireguardTunnelModal).catch(e=>modal('WireGuard',{output:String(e)}))},[E('div',{class:'scope-head'},[E('div',{class:'scope-icon'},'WG'),E('div',{style:'flex:1'},[E('h3',{style:'margin:0'},'WireGuard туннель'),E('p',{class:'hint',style:'margin:5px 0 0'},'Remote WireGuard и WireGuard VPN · отдельный контур')]),E('span',{class:'badge'},'отдельно')]),E('div',{class:'statusline'},[E('span',{class:'dot '+(/white_ip=yes/.test(wgDiag)?'ok':'warn')}),E('span',{},/white_ip=yes/.test(wgDiag)?'Белый IP подтверждён':'Белый IP не подтверждён')]),E('div',{class:'wireguard-summary'},[E('div',{},[E('strong',{},'Remote WireGuard'),E('div',{class:'health-meta'},'Только сеть туннеля · интернет устройства не меняется')]),E('div',{},[E('strong',{},'WireGuard VPN'),E('div',{class:'health-meta'},'Полный IPv4 интернет · 0.0.0.0/0 + NAT для выбранных устройств')])]),E('div',{class:'actions'},[btn('Открыть настройки',()=>api.remoteWgDiagnose().then(wireguardTunnelModal),'primary'),btn('Добавить устройство',()=>wireguardAddDeviceModal()),btn('Устройства',()=>api.remoteWgList().then(remoteDevicesModal))]),E('div',{class:'help'},(/white_ip=yes/.test(wgDiag)?'Публичный IPv4 подтверждён. Для входящего подключения дополнительно должен быть доступен UDP 51820.':'⚠️ Прямая работа входящего WireGuard не гарантируется без белого публичного IPv4/доступного UDP 51820. Нажмите блок для подробной диагностики.'))]),
      E('section',{class:'card wide'},[E('h3',{},'Telegram — отдельный контроллер'),E('p',{class:'hint'},'Telegram работает независимо от AI и общего автоподбора. Контроллер следит за выделенным SOCKS5/WebSocket путём и меняет только Telegram-маршрут. По умолчанию SOCKS5: порт 1080.'),E('div',{class:'actions'},[btn('Состояние',()=>api.tgControllerStatus().then(r=>modal('Telegram: контроллер',r)).then(refresh),'primary'),btn('Проверить сейчас',()=>api.tgControllerProbe().then(r=>modal('Telegram: проверка',r)).then(refresh)),btn('Включить автоконтроль',()=>confirmRun('Telegram: автоконтроль','Разрешить отдельному Telegram-контроллеру автоматически восстанавливать Telegram без изменения AI и других сервисов?',()=>api.tgControllerEnable({confirm:true}).then(r=>modal('Telegram',r)).then(refresh))),btn('Выключить автоконтроль',()=>confirmRun('Telegram: автоконтроль','Остановить автоматическое восстановление Telegram?',()=>api.tgControllerDisable({confirm:true}).then(r=>modal('Telegram',r)).then(refresh)))])]),
          ]));

    advancedShell.appendChild(E('div',{class:'master-note'},[E('strong',{},'Расширенные инструменты MASTER'),E('span',{},'Здесь находятся ручные и технические операции. Они не нужны для обычной работы. Перед изменением конфигурации система запрашивает подтверждение.') ]));
    advancedShell.appendChild(E('div',{class:'advanced-grid'},[E('section',{class:'card wide'},[E('h3',{},'Автоматический подбор стратегии'),E('div',{class:'automation-head'},[automationTitle,automationToggleLabel]),automationHint,E('div',{class:'automation-settings'},[E('label',{},['Время запуска',automationTime]),E('label',{},['Периодичность',automationInterval])]),automationActions,E('div',{class:'help'},'По умолчанию выключено. Система проверяет доступные кандидаты, сравнивает стабильность и сохраняет только подтверждённый вариант. При ошибке рабочая стратегия сохраняется. Время считается по часовому поясу роутера.')]),E('section',{class:'card wide'},[E('h3',{},'Модули обхода'),E('p',{class:'hint'},'Каждый модуль подбирает стратегию отдельно. Рабочие профили запоминаются, неудачные уходят на паузу, а попытка с регрессией другого модуля откатывается.'),E('div',{id:'uowrt-module-grid',class:'module-grid'}),E('div',{id:'uowrt-module-health',class:'module-health'}),E('div',{class:'help'},'По умолчанию все модули включены. Отключённый модуль полностью исключается из автоматического подбора, но его настройки не удаляются.')]),E('section',{class:'card wide'},[E('h3',{},'Монитор ресурсов'),E('p',{class:'hint'},'Показывает, какие сервисы работают сейчас. Автоподбор использует этот список как очередь: рабочие ресурсы не выбираются для дальнейшего подбора, а сломанные проверяются по очереди.'),E('div',{class:'actions'},[btn('Проверить сейчас',()=>api.resourceMonitor().then(r=>modal('Монитор ресурсов',r)).then(refresh),'primary'),btn('Восстановить только неработающие',()=>confirmRun('Точечное восстановление','Проверять и подбирать стратегии только для ресурсов, которые сейчас не работают. Рабочие ресурсы используются как защита от регрессий.',()=>api.resourceRecovery({confirm:true}).then(r=>modal('Результат восстановления',r)).then(refresh)))]),E('div',{class:'help'},'Если одна глобальная стратегия исправляет несколько ресурсов — они автоматически помечаются как восстановленные. Если она ломает уже рабочий ресурс, изменение откатывается.')]),
      E('section',{class:'card'},[E('h3',{},'AI: резервные пресеты'),E('p',{class:'hint'},'Community-пресеты Zapret/Zapret2 хранятся отдельно. Используйте их только если встроенные стратегии не дали результата.'),E('div',{class:'actions'},[btn('Показать пресеты',()=>api.aiPresets().then(r=>modal('Резервные AI-пресеты',r))),btn('Проверить каталог',()=>api.aiCatalog().then(r=>modal('Каталог AI',r)))])]),
      E('section',{class:'card'},[E('h3',{},'AWG / WARP'),E('p',{class:'hint'},'Дополнительный маршрут. Не включается автоматически только потому, что сервис не отвечает.'),E('div',{class:'actions'},[btn('Состояние',()=>api.awg().then(r=>modal('AWG / WARP',r)))])]),
      E('section',{class:'card wide'},[E('h3',{},'Telegram — доступные движки'),E('p',{class:'hint'},'Telegram полностью отделён от общего Strategy Engine. Одновременно активируется только один управляющий Telegram-backend. Доступны Go SOCKS5/WS, Rust Telemt MTProto, внешний SOCKS5 через sing-box и локальный WS-backend.'),E('div',{id:'uowrt-tg-backends',class:'module-grid'}),E('div',{class:'help'},'Go и Rust-движки устанавливаются только после проверки архитектуры и SHA256 release asset. AWG/WireGuard сюда не подмешиваются.')]),
      E('section',{class:'card wide'},[E('h3',{},'Telegram — отдельный канал'),E('p',{class:'hint'},'Telegram не участвует в общем AI-подборе. Для устройств в LAN используется отдельный SOCKS5 → WebSocket bridge. Порт по умолчанию: 1080.'),E('div',{class:'actions'},[btn('SOCKS5: 1080 — состояние',()=>api.tgSock().then(r=>modal('Telegram SOCKS5',r)),'primary'),btn('Установить / обновить',()=>api.tgInstall().then(r=>modal('Telegram SOCKS5',r)).then(refresh)),btn('Включить',()=>confirmRun('Telegram SOCKS5','Запустить отдельный Telegram SOCKS5 bridge на порту 1080?',()=>api.tgEnable({confirm:true}).then(r=>modal('Telegram SOCKS5',r)).then(refresh))),btn('Выключить',()=>confirmRun('Telegram SOCKS5','Остановить Telegram SOCKS5 bridge?',()=>api.tgDisable({confirm:true}).then(r=>modal('Telegram SOCKS5',r)).then(refresh)))])]),
      E('section',{class:'card'},[E('h3',{},'Ресурсы'),E('p',{class:'hint'},'Обновляет списки доменов и данные для автоматического подбора. Сетевой запрос выполняется только по явной команде.'),E('div',{class:'actions'},[btn('Обновить ресурсы',()=>api.resources().then(r=>modal('Ресурсы',r)).then(refresh)),btn('Бенчмарк',()=>api.resourceBenchmark().then(r=>modal('Бенчмарк ресурсов',r)))])]),
      E('section',{class:'card wide'},[E('h3',{},'Ручной подбор стратегии'),E('p',{class:'hint'},'Для опытного пользователя. Если не знаете, какой режим нужен, выключите MASTER и используйте мастер диагностики.'),E('div',{class:'actions'},[btn('Подбор стратегии',()=>api.optimize(speed.value).then(r=>modal('Подбор стратегии',r))),btn('Адаптивный тест',()=>confirmRun('Адаптивный тест','Будут последовательно проверены несколько классов стратегий. Неудачные изменения должны откатываться.',()=>api.adaptive({confirm:true}).then(r=>modal('Адаптивный тест',r)).then(refresh))),btn('Предиктивный анализ',()=>confirmRun('Предиктивный анализ','Использовать историю проблемных ресурсов для выбора следующего теста?',()=>api.predictive({confirm:true}).then(r=>modal('Предиктивный анализ',r)).then(refresh))),btn('Откатить последнее изменение',()=>confirmRun('Откат','Вернуть последнее сохранённое состояние конфигурации?',()=>api.rollback({confirm:true}).then(r=>modal('Откат',r)).then(refresh)),'danger cbi-button-negative')])]),
      E('section',{class:'card full'},[E('h3',{},'Журнал последних действий'),E('p',{class:'hint'},'Технический журнал нужен в основном для диагностики и обращения за помощью.'),log])
    ]));
    root.appendChild(advancedShell);
    return root;
  }
});
