local runner = require('modules.tasks.runner')
local M = {}
local notify = require('modules.tasks.notifications').send
function M.run(target)
  if runner.isRunning(target.id) then notify(target.title, 'Ya hay una operación en curso.'); return end
  if not target.region or target.region == '' then notify(target.title, 'Configura la región en personal.lua.'); return end
  local config = require('modules.config.personal').data
  local script = hs.configdir .. '/scripts/rds-snapshot.sh'
  local args = { 'inspect', config.awsBinary or '/opt/homebrew/bin/aws', target.profile, target.region, target.instance }
  notify(target.title, 'Verificando cuenta e instancia (solo lectura)...')
  runner.run({id=target.id, title=target.title, script=script, args=args}, function(code, stdout, stderr)
    if code ~= 0 then notify(target.title, stderr ~= '' and stderr or 'No se pudo verificar el destino.', true); return end
    local account = (stdout or ''):match('^%s*(%d+)%s*$')
    if not account or #account ~= 12 then notify(target.title, 'Respuesta de cuenta no válida.', true); return end
    local name = target.instance .. '-' .. os.date('%Y%m%d-%H%M') .. '-manual'
    local details = 'Cuenta: ' .. account .. '\nPerfil: ' .. target.profile .. '\nRegión: ' .. target.region
      .. '\nInstancia: ' .. target.instance .. '\nSnapshot: ' .. name .. '\n\nSe creará un snapshot manual de RDS.'
    if hs.dialog.blockAlert('Crear snapshot', details, 'Crear snapshot', 'Cancelar') ~= 'Crear snapshot' then
      runner.states[target.id] = 'Cancelado'; return
    end
    args[1] = 'create'; args[6] = name; args[7] = account
    runner.run({id=target.id, title=target.title, script=script, args=args,
      progress=function(text)
        if text:find('Solicitado:', 1, true) then notify(target.title, 'Snapshot solicitado. Esperando disponibilidad...') end
      end}, function(exit, _, errorText)
      if exit ~= 0 then notify(target.title, errorText ~= '' and errorText or 'No se confirmó la disponibilidad. Revisa RDS.', true)
      else notify(target.title, 'Snapshot disponible: ' .. name, true) end
    end)
  end)
end
return M
