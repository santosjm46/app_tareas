const BOOK_ID = '1c9AxyjnvhGGNaK7O-QgGie-hnPTU3ph87mbr00KRvf0';
const INITIAL_PASSWORD = '123456';
const SUPERADMIN_USER = 'santos.jahuira';
const SUPERADMIN_ALIASES = ['santos.jahuira', 'santos'];
const INITIAL_PATIOS = ['CAJA FERROVIARIA','CENTRO','CHASQUIPAMPA','HUAYLLANI','INCALLOJETA','INTEGRADORA','IRPAVI','LA PORTADA','SUB ALCALDÍA M.','VILLA SALOMÉ'];
const INITIAL_BA = ['002','003','004','005','006','007','008','009','010','011','012','013','014','015','018','019','021','022','023','024','026','028','029','030','031','033','034','035','037','038','039','040','041','044','045','046','047','049','050','051','052','053','054','055','056','057','058','060','061','062','063','064','065','066','068','071','073','074','075','076','077','078','080','081','082','084','087','088','089','090','091','092','093','094','095','096','097','099','100','103','104','108','109','110','111','112','114','116','117','118','120','121','122','123','124','127','128','132','133','134','135','136','137','138','139','142','145','173'];
const INITIAL_BS = ['001','002','003','004','005','006','007','008','009','010','011','012','013','014','015','016','017','018','019','020','021','022','023','024','025','026','027','028','029','030','031','032','033','034','035','036','037','038','039'];
const INITIAL_BAR = ['001','016','017','020','025','027','032','036','042','043','048','059','067','069','070','072','079','083','085','086','098','101','102','105','106','107','113','115','119','125','126','129','130','131','140','141','143','144','146','147','148','149','150','151','152','153','154','155','156','157','158','159','160','161','162','163','164','165','166','167','168','169','170','171','172','174'];

function doGet(e) {
  if (e && e.parameter && e.parameter.payload) {
    return handleRequest_(JSON.parse(e.parameter.payload));
  }
  return json_({ ok: true, service: 'SSUMA Trabajos', version: 3 });
}

function doPost(e) {
  const body = JSON.parse((e && e.postData && e.postData.contents) || '{}');
  return handleRequest_(body);
}

function handleRequest_(body) {
  try {
    const actions = {
      login: () => login_(body),
      changePassword: () => changePassword_(body),
      resetPassword: () => resetPassword_(body),
      listJobs: () => listJobs_(body),
      saveJob: () => saveJob_(body),
      createOperationalUser: () => createOperationalUser_(body),
      listUsers: () => listUsers_(body),
      updateUser: () => updateUser_(body),
      getCatalogs: () => getCatalogs_(body),
      addCatalog: () => addCatalog_(body),
      dashboard: () => dashboard_(body),
      ensureMonth: () => ensureMonth_(new Date())
    };
    if (!actions[body.action]) throw new Error('Acción no válida');
    return json_({ ok: true, data: actions[body.action]() });
  } catch (err) {
    return json_({ ok: false, error: String(err.message || err) });
  }
}

function setup() {
  const users = sheet_('USUARIOS');
  const last = users.getLastRow();
  if (last > 1) {
    const values = users.getRange(2, 1, last - 1, 12).getValues();
    values.forEach((row, i) => {
      if (!row[7]) users.getRange(i + 2, 8).setValue(hash_(row[1], INITIAL_PASSWORD));
      users.getRange(i + 2, 9).setValue('Sí');
    });
  }
  const santos = findUser_(SUPERADMIN_USER);
  if (santos) {
    users.getRange(santos._row, 7).setValue('Administrador');
    users.getRange(santos._row, 10).setValue('Sí');
  }
  ensureCatalogSheets_();
  ensureMonth_(new Date());
  ScriptApp.newTrigger('monthlyRollover').timeBased().onMonthDay(1).atHour(1).create();
  return 'Configuración completada';
}

function monthlyRollover() { ensureMonth_(new Date()); }

function login_(b) {
  const user = findUser_(b.username);
  if (!user || user.ACTIVO !== 'Sí' || user.CLAVE_HASH !== hash_(b.username, b.password)) throw new Error('Usuario o contraseña incorrectos');
  const token = Utilities.getUuid() + Utilities.getUuid();
  CacheService.getScriptCache().put('session:' + token, JSON.stringify(user), 21600);
  return { token, user: publicUser_(user), mustChangePassword: user.CAMBIAR_CLAVE === 'Sí' };
}

function changePassword_(b) {
  const user = auth_(b.token);
  if (!b.newPassword || String(b.newPassword).length < 6) throw new Error('La contraseña debe tener al menos 6 caracteres');
  const sh = sheet_('USUARIOS');
  sh.getRange(user._row, 8).setValue(hash_(user.USUARIO, b.newPassword));
  sh.getRange(user._row, 9).setValue('No');
  return true;
}

function resetPassword_(b) {
  requireSuperAdmin_(auth_(b.token));
  const target = findUser_(b.username);
  if (!target) throw new Error('Usuario no encontrado');
  const sh = sheet_('USUARIOS');
  sh.getRange(target._row, 8).setValue(hash_(target.USUARIO, INITIAL_PASSWORD));
  sh.getRange(target._row, 9).setValue('Sí');
  return { username: target.USUARIO, temporaryPassword: INITIAL_PASSWORD };
}

function listJobs_(b) {
  const user = auth_(b.token);
  const names = ensureMonth_(b.month ? new Date(b.month + '-01T12:00:00') : new Date());
  const jobsSheet = sheet_(names.jobs);
  const dateHeader = String(jobsSheet.getRange(1, 2).getValue());
  const tz = Session.getScriptTimeZone();
  const rows = objects_(jobsSheet).map(r => {
    const date = r[dateHeader] instanceof Date ? r[dateHeader] : new Date(r[dateHeader]);
    r.FECHA_ISO = isNaN(date.getTime()) ? '' : Utilities.formatDate(date, tz, 'yyyy-MM-dd');
    return r;
  });
  if (user.ROL === 'Técnico') return rows.filter(r => r.USUARIO === user.USUARIO);
  if (['Supervisor', 'Responsable'].includes(user.ROL)) return rows.filter(r => r['ÁREA'] === user['ÁREA']);
  if (['Administrador', 'Jefe'].includes(user.ROL)) return rows;
  return rows.filter(r => r.USUARIO === user.USUARIO);
}

function saveJob_(b) {
  const user = auth_(b.token);
  const p = b.job || {};
  if (!p.place || !p.patio || !p.description || !p.start || !p.end || p.progress === undefined) throw new Error('Faltan campos obligatorios');
  if (p.place === 'Bus' && (!p.asset || !p.order)) throw new Error('Para Bus son obligatorios el código y el número de OT');
  if (p.start === p.end) throw new Error('La hora de inicio y fin no pueden ser iguales');
  const requestId = String(p.requestId || '');
  const cache = CacheService.getScriptCache();
  const cached = requestId ? cache.get('job-request:' + requestId) : null;
  if (cached) return JSON.parse(cached);
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
  const cachedAfterLock = requestId ? cache.get('job-request:' + requestId) : null;
  if (cachedAfterLock) return JSON.parse(cachedAfterLock);
  const names = ensureMonth_(new Date(p.date || new Date()));
  const start = minutes_(p.start), end = minutes_(p.end);
  const duration = ((end < start ? end + 1440 : end) - start);
  if (!isFinite(duration) || duration <= 0 || duration > 1440) throw new Error('El rango de horas no es válido');
  const id = p.id || ('TR-' + Utilities.getUuid().slice(0, 8).toUpperCase());
  const jobsSheet = sheet_(names.jobs);
  const progressSheet = sheet_(names.progress);
  if (!jobsSheet.getRange(1, 21).getValue()) jobsSheet.getRange(1, 21).setValue('PATIO');
  let total = duration;

  const sameText = (a, c) => String(a || '').trim().toUpperCase() === String(c || '').trim().toUpperCase();
  const dayKey = Utilities.formatDate(new Date(p.date || new Date()), Session.getScriptTimeZone(), 'yyyy-MM-dd');
  const dateKey = value => {
    const d = value instanceof Date ? value : new Date(value);
    return isNaN(d.getTime()) ? '' : Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM-dd');
  };
  const progressHeaders = progressSheet.getRange(1, 1, 1, progressSheet.getLastColumn()).getValues()[0];
  const duplicateProgress = objects_(progressSheet).some(r =>
    (!p.id || sameText(r[progressHeaders[1]], p.id)) && dateKey(r[progressHeaders[2]]) === dayKey &&
    sameText(r[progressHeaders[3]], user.USUARIO) && Number(r[progressHeaders[4]]) === Number(p.progress) &&
    sameText(r[progressHeaders[5]], p.description) && sameText(r[progressHeaders[6]], p.start) && sameText(r[progressHeaders[7]], p.end)
  );
  if (duplicateProgress) throw new Error('Este registro ya fue guardado anteriormente');
  const overlaps = objects_(progressSheet).some(r => {
    if (dateKey(r[progressHeaders[2]]) !== dayKey || !sameText(r[progressHeaders[3]], user.USUARIO)) return false;
    const oldStart = minutes_(r[progressHeaders[6]]), oldEndRaw = minutes_(r[progressHeaders[7]]);
    if (!isFinite(oldStart) || !isFinite(oldEndRaw)) return false;
    const oldEnd = oldEndRaw <= oldStart ? oldEndRaw + 1440 : oldEndRaw;
    const newEnd = end <= start ? end + 1440 : end;
    return start < oldEnd && newEnd > oldStart;
  });
  if (overlaps) throw new Error('El horario se superpone con otro trabajo registrado por el mismo usuario');

  if (p.id) {
    const idHeader = String(jobsSheet.getRange(1, 1).getValue());
    const existing = objects_(jobsSheet).find(r => String(r[idHeader]) === String(p.id));
    if (!existing) throw new Error('No se encontró el trabajo que se desea continuar');
    if (existing.ESTADO === 'Finalizado' || Number(existing.AVANCE_ACTUAL) >= 100) throw new Error('El trabajo ya está finalizado y no puede modificarse');
    if (existing.USUARIO !== user.USUARIO) throw new Error('Solo el trabajador que registró el trabajo puede continuarlo');
    if (Number(p.progress) <= Number(existing.AVANCE_ACTUAL || 0)) throw new Error('El nuevo avance debe ser mayor al avance anterior');
    total = Number(existing.TIEMPO_TOTAL_MIN || 0) + duration;
    const row = existing._row;
    jobsSheet.getRange(row, 12).setValue(p.end);
    jobsSheet.getRange(row, 13).setValue(Number(p.progress));
    jobsSheet.getRange(row, 14).setValue(Number(p.progress) === 100 ? 'Finalizado' : 'En progreso');
    if (p.materials === 'Sí') jobsSheet.getRange(row, 15).setValue('Sí');
    if (p.notes) jobsSheet.getRange(row, 16).setValue([existing.OBSERVACIONES || '', p.notes].filter(Boolean).join(' | '));
    jobsSheet.getRange(row, 18).setValue(new Date());
    jobsSheet.getRange(row, 19).setValue(total);
    jobsSheet.getRange(row, 20).setValue(formatMinutes_(total));
    if (p.patio) jobsSheet.getRange(row, 21).setValue(p.patio);
  } else {
    const jobHeaders = jobsSheet.getRange(1, 1, 1, jobsSheet.getLastColumn()).getValues()[0];
    const duplicateJob = objects_(jobsSheet).some(r => dateKey(r[jobHeaders[1]]) === dayKey &&
      sameText(r[jobHeaders[2]], user.USUARIO) && sameText(r[jobHeaders[5]], p.place) &&
      sameText(r[jobHeaders[6]], p.asset) && sameText(r[jobHeaders[8]], p.order) &&
      sameText(r[jobHeaders[9]], p.description) && sameText(r[jobHeaders[10]], p.start) && sameText(r[jobHeaders[11]], p.end));
    if (duplicateJob) throw new Error('Ya existe un trabajo con los mismos datos, horario y usuario');
    jobsSheet.appendRow([id, new Date(), user.USUARIO, user.NOMBRE_COMPLETO, user['ÁREA'], p.place, p.asset, p.hasOrder ? 'Sí' : 'No', p.order || '', p.description, p.start, p.end, Number(p.progress), Number(p.progress) === 100 ? 'Finalizado' : 'En progreso', p.materials || 'No', p.notes || '', '', new Date(), duration, formatMinutes_(duration), p.patio || '']);
  }

  progressSheet.appendRow(['AV-' + Utilities.getUuid().slice(0, 8).toUpperCase(), id, new Date(p.date || new Date()), user.USUARIO, Number(p.progress), p.description, p.start, p.end, p.materials || 'No', p.notes || '', Number(p.progress) === 100 ? 'Sí' : 'No', new Date(), duration, formatMinutes_(duration)]);
  const result = { id, duration, durationText: formatMinutes_(duration), totalMinutes: total, totalText: formatMinutes_(total), completed: Number(p.progress) === 100 };
  if (requestId) cache.put('job-request:' + requestId, JSON.stringify(result), 21600);
  return result;
  } finally {
    lock.releaseLock();
  }
}

function createOperationalUser_(b) {
  const actor = auth_(b.token);
  requireSuperAdmin_(actor);
  if (!b.username || !b.fullName || !b.area || !b.location || !b.shift) throw new Error('Completa todos los campos obligatorios');
  if (!/^[a-zA-Z0-9._-]{3,30}$/.test(String(b.username))) throw new Error('El nombre de usuario no es válido');
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    if (findUser_(b.username)) throw new Error('El usuario ya existe');
    const sh = sheet_('USUARIOS');
    const id = 'UMA-' + String(sh.getLastRow()).padStart(3, '0');
    sh.appendRow([id, String(b.username).toLowerCase(), b.fullName, b.area, b.location, b.shift, 'Técnico', hash_(b.username, INITIAL_PASSWORD), 'Sí', 'Sí', new Date(), '']);
    return { id, username: String(b.username).toLowerCase(), role: 'Técnico' };
  } finally { lock.releaseLock(); }
}

function listUsers_(b) {
  requireSuperAdmin_(auth_(b.token));
  return objects_(sheet_('USUARIOS')).map(u => ({
    id: u.ID_USUARIO, username: u.USUARIO, name: u.NOMBRE_COMPLETO,
    area: u['ÁREA'], location: u['UBICACIÓN_BASE'], shift: u.TURNO,
    role: u.ROL, active: u.ACTIVO === 'Sí', superadmin: isSuperAdmin_(u)
  }));
}

function updateUser_(b) {
  requireSuperAdmin_(auth_(b.token));
  const target = findUser_(b.username);
  if (!target) throw new Error('Usuario no encontrado');
  const sh = sheet_('USUARIOS');
  if (target.USUARIO === SUPERADMIN_USER) {
    if (b.fullName) sh.getRange(target._row, 3).setValue(b.fullName);
    if (b.area) sh.getRange(target._row, 4).setValue(b.area);
    if (b.location !== undefined) sh.getRange(target._row, 5).setValue(b.location);
    if (b.shift !== undefined) sh.getRange(target._row, 6).setValue(b.shift);
    sh.getRange(target._row, 7).setValue('Administrador');
    sh.getRange(target._row, 10).setValue('Sí');
    return true;
  }
  if (b.fullName) sh.getRange(target._row, 3).setValue(b.fullName);
  if (b.area) sh.getRange(target._row, 4).setValue(b.area);
  if (b.location !== undefined) sh.getRange(target._row, 5).setValue(b.location);
  if (b.shift !== undefined) sh.getRange(target._row, 6).setValue(b.shift);
  if (b.role) sh.getRange(target._row, 7).setValue(b.role);
  if (b.active !== undefined) sh.getRange(target._row, 10).setValue(b.active ? 'Sí' : 'No');
  return true;
}

function ensureCatalogSheets_() {
  const book = SpreadsheetApp.openById(BOOK_ID);
  let patios = book.getSheetByName('PATIOS_APP');
  if (!patios) patios = book.insertSheet('PATIOS_APP');
  if (patios.getLastRow() === 0) patios.appendRow(['NOMBRE', 'ACTIVO', 'CREADO_EN', 'CREADO_POR']);
  if (patios.getLastRow() === 1) patios.getRange(2, 1, INITIAL_PATIOS.length, 4).setValues(INITIAL_PATIOS.map(x => [x, 'Sí', new Date(), SUPERADMIN_USER]));

  let buses = book.getSheetByName('BUSES_APP');
  if (!buses) buses = book.insertSheet('BUSES_APP');
  if (buses.getLastRow() === 0) buses.appendRow(['CODIGO', 'ACTIVO', 'CREADO_EN', 'CREADO_POR']);
  const initialBuses = [].concat(INITIAL_BA.map(x => 'BA-' + x), INITIAL_BS.map(x => 'BS-' + x), INITIAL_BAR.map(x => 'BAR-' + x));
  if (buses.getLastRow() === 1) buses.getRange(2, 1, initialBuses.length, 4).setValues(initialBuses.map(x => [x, 'Sí', new Date(), SUPERADMIN_USER]));
  return { patios, buses };
}

function getCatalogs_(b) {
  auth_(b.token);
  const c = ensureCatalogSheets_();
  const patios = objects_(c.patios).filter(x => x.ACTIVO === 'Sí').map(x => String(x.NOMBRE)).sort();
  const buses = objects_(c.buses).filter(x => x.ACTIVO === 'Sí').map(x => String(x.CODIGO)).sort();
  return { patios, buses };
}

function addCatalog_(b) {
  const actor = auth_(b.token);
  requireSuperAdmin_(actor);
  const type = String(b.type || '');
  const value = String(b.value || '').trim().toUpperCase();
  if (!value) throw new Error('Ingresa un valor');
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const c = ensureCatalogSheets_();
    if (type === 'bus') {
      if (!/^(BA|BS|BAR)-\d{3}$/.test(value)) throw new Error('Usa el formato BA-000, BS-000 o BAR-000');
      if (objects_(c.buses).some(x => String(x.CODIGO) === value)) throw new Error('El bus ya existe');
      c.buses.appendRow([value, 'Sí', new Date(), actor.USUARIO]);
    } else if (type === 'patio') {
      if (objects_(c.patios).some(x => String(x.NOMBRE).toUpperCase() === value)) throw new Error('El patio ya existe');
      c.patios.appendRow([value, 'Sí', new Date(), actor.USUARIO]);
    } else throw new Error('Tipo de catálogo no válido');
    return true;
  } finally { lock.releaseLock(); }
}

function requireSuperAdmin_(user) {
  if (!isSuperAdmin_(user)) throw new Error('Acceso exclusivo del Superadministrador Santos Jahuira');
}

function normalizeUser_(value) {
  return String(value || '').trim().toLowerCase();
}

function isSuperAdmin_(user) {
  if (!user) return false;
  const username = normalizeUser_(user.USUARIO || user.username);
  return SUPERADMIN_ALIASES.includes(username);
}

function dashboard_(b) {
  const user = auth_(b.token);
  if (user.ROL === 'Técnico') throw new Error('Sin permiso para estadísticas');
  const jobs = listJobs_(b);
  return { total: jobs.length, completed: jobs.filter(x => x.ESTADO === 'Finalizado').length, inProgress: jobs.filter(x => x.ESTADO === 'En progreso').length, totalMinutes: jobs.reduce((s, x) => s + Number(x.TIEMPO_TOTAL_MIN || 0), 0) };
}

function ensureMonth_(date) {
  const tz = Session.getScriptTimeZone();
  const key = Utilities.formatDate(date, tz, 'yyyy_MM');
  const jobs = 'TRABAJOS_' + key, progress = 'AVANCES_' + key;
  const book = SpreadsheetApp.openById(BOOK_ID);
  if (!book.getSheetByName(jobs)) book.getSheetByName('TRABAJOS').copyTo(book).setName(jobs);
  if (!book.getSheetByName(progress)) book.getSheetByName('AVANCES').copyTo(book).setName(progress);
  if (!book.getSheetByName(jobs).getRange(1, 21).getValue()) book.getSheetByName(jobs).getRange(1, 21).setValue('PATIO');
  const index = book.getSheetByName('MESES');
  const exists = index.getRange(2, 1, Math.max(index.getLastRow() - 1, 1), 1).getDisplayValues().flat().includes(key.replace('_', '-'));
  if (!exists) index.appendRow([key.replace('_', '-'), jobs, progress, 'Activo', new Date(), '']);
  return { jobs, progress };
}

function findUser_(username) {
  const rows = objects_(sheet_('USUARIOS'));
  return rows.find(r => String(r.USUARIO).toLowerCase() === String(username || '').toLowerCase());
}
function auth_(token) { const raw = CacheService.getScriptCache().get('session:' + token); if (!raw) throw new Error('Sesión vencida'); return JSON.parse(raw); }
function sheet_(name) { const s = SpreadsheetApp.openById(BOOK_ID).getSheetByName(name); if (!s) throw new Error('No existe la hoja ' + name); return s; }
function objects_(sh) { const v = sh.getDataRange().getValues(); if (v.length < 2) return []; const h = v.shift(); return v.filter(r => r[0]).map((r, i) => { const o = { _row: i + 2 }; h.forEach((x, j) => o[x] = r[j]); return o; }); }
function publicUser_(u) { return { id: u.ID_USUARIO, username: u.USUARIO, name: u.NOMBRE_COMPLETO, area: u['ÁREA'], role: u.ROL, location: u['UBICACIÓN_BASE'], shift: u.TURNO }; }
function hash_(u, p) { return Utilities.base64Encode(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(u).toLowerCase() + ':' + p)); }
function minutes_(v) { const a = String(v).split(':').map(Number); return a[0] * 60 + a[1]; }
function formatMinutes_(m) { return Math.floor(m / 60) + ' h ' + String(m % 60).padStart(2, '0') + ' min'; }
function json_(o) { return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON); }
