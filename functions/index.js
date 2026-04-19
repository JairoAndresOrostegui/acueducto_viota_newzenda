const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const ACTIVE_STATUS = 'activo';
const USER_COLLECTION = 'usuarios';
const USER_LOG_COLLECTION = 'usuarios_logs';
const DOCUMENT_TYPE_COLLECTION = 'tipos_documento';
const ROLE_COLLECTION = 'roles';
const SECTOR_COLLECTION = 'sectores';

async function getAdminProfile(uid) {
  const snapshot = await db.collection(USER_COLLECTION).doc(uid).get();
  if (!snapshot.exists) {
    throw new HttpsError(
      'permission-denied',
      'El usuario autenticado no tiene perfil en Firestore.',
    );
  }

  const data = snapshot.data();
  if (data.rol !== 'administrador' || data.estado !== ACTIVE_STATUS) {
    throw new HttpsError(
      'permission-denied',
      'Solo administradores activos pueden gestionar usuarios.',
    );
  }

  return {
    uid,
    nombre: data.nombre ?? 'Administrador',
  };
}

function normalizeString(value, field) {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) {
    throw new HttpsError('invalid-argument', `El campo ${field} es obligatorio.`);
  }
  return normalized;
}

function normalizeLowercase(value, field) {
  return normalizeString(value, field).toLowerCase();
}

async function getActiveCatalogValue(collectionName, value, field) {
  const normalizedValue = normalizeString(value, field);
  const snapshot = await db
    .collection(collectionName)
    .where('valor', '==', normalizedValue)
    .where('estado', '==', ACTIVE_STATUS)
    .limit(1)
    .get();

  if (snapshot.empty) {
    throw new HttpsError(
      'invalid-argument',
      `El valor ${normalizedValue} no esta activo en el catalogo ${field}.`,
    );
  }

  return snapshot.docs[0].data();
}

function sanitizeUserPayload(data) {
  return {
    uid: data.uid,
    nombre: data.nombre,
    tipoDocumento: data.tipoDocumento,
    numeroDocumento: data.numeroDocumento,
    numeroContacto: data.numeroContacto,
    codigoUsuario: data.codigoUsuario,
    numeroContador: data.numeroContador,
    rol: data.rol,
    sector: data.sector,
    correo: data.correo,
    estado: data.estado,
  };
}

function buildSearchTokens(...values) {
  const text = values
    .flatMap((value) => {
      if (!value) {
        return [];
      }
      if (typeof value === 'object') {
        return Object.values(value)
          .filter((inner) => typeof inner === 'string')
          .map((inner) => inner.toLowerCase());
      }
      return [String(value).toLowerCase()];
    })
    .join(' ');

  return [...new Set(text.match(/[a-z0-9@._-]+/gi) ?? [])];
}

async function writeUserLog({
  action,
  actor,
  targetUid,
  targetName,
  previousData = null,
  newData = null,
}) {
  await db.collection(USER_LOG_COLLECTION).add({
    accion: action,
    actorUid: actor.uid,
    actorNombre: actor.nombre,
    usuarioObjetivoUid: targetUid,
    usuarioObjetivoNombre: targetName,
    anterior: previousData,
    nuevo: newData,
    fecha: admin.firestore.FieldValue.serverTimestamp(),
    searchTokens: buildSearchTokens(
      action,
      actor.uid,
      actor.nombre,
      targetUid,
      targetName,
      previousData,
      newData,
    ),
  });
}

async function buildUserPayload(uid, data, previous = null) {
  const documentType = await getActiveCatalogValue(
    DOCUMENT_TYPE_COLLECTION,
    normalizeLowercase(data.tipoDocumento, 'tipoDocumento'),
    'tipoDocumento',
  );
  const role = await getActiveCatalogValue(
    ROLE_COLLECTION,
    normalizeLowercase(data.rol, 'rol'),
    'rol',
  );

  const payload = {
    uid,
    nombre: normalizeLowercase(data.nombre, 'nombre'),
    tipoDocumento: documentType.valor,
    numeroDocumento: normalizeString(data.numeroDocumento, 'numeroDocumento'),
    numeroContacto: normalizeString(data.numeroContacto, 'numeroContacto'),
    codigoUsuario: 'na',
    numeroContador: 'na',
    rol: role.valor,
    sector: 'na',
    correo: normalizeLowercase(data.correo, 'correo'),
    estado: normalizeLowercase(data.estado, 'estado'),
    fechaCreacion:
      previous?.fechaCreacion ?? admin.firestore.FieldValue.serverTimestamp(),
    fechaActualizacion: previous
      ? admin.firestore.FieldValue.serverTimestamp()
      : null,
  };

  if (!['activo', 'inactivo'].includes(payload.estado)) {
    throw new HttpsError(
      'invalid-argument',
      'El estado del usuario debe ser activo o inactivo.',
    );
  }

  if (payload.rol === 'cliente') {
    const sector = await getActiveCatalogValue(
      SECTOR_COLLECTION,
      normalizeLowercase(data.sector, 'sector'),
      'sector',
    );
    payload.codigoUsuario = normalizeString(data.codigoUsuario, 'codigoUsuario');
    payload.numeroContador = normalizeString(data.numeroContador, 'numeroContador');
    payload.sector = sector.valor;
  }

  return payload;
}

exports.createManagedUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
  }

  const actor = await getAdminProfile(request.auth.uid);
  const data = request.data ?? {};
  const email = normalizeLowercase(data.correo, 'correo');
  const password = normalizeString(data.password, 'password');

  const payload = await buildUserPayload('', data);
  const authUser = await admin.auth().createUser({
    email,
    password,
    displayName: payload.nombre,
    disabled: payload.estado !== ACTIVE_STATUS,
  });

  const userPayload = await buildUserPayload(authUser.uid, data);
  await db.collection(USER_COLLECTION).doc(authUser.uid).set(userPayload);

  await writeUserLog({
    action: 'creacion',
    actor,
    targetUid: authUser.uid,
    targetName: userPayload.nombre,
    newData: sanitizeUserPayload(userPayload),
  });

  return {
    uid: authUser.uid,
    email: authUser.email,
  };
});

exports.updateManagedUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
  }

  const actor = await getAdminProfile(request.auth.uid);
  const data = request.data ?? {};
  const uid = normalizeString(data.uid, 'uid');
  const userRef = db.collection(USER_COLLECTION).doc(uid);
  const existing = await userRef.get();

  if (!existing.exists) {
    throw new HttpsError('not-found', 'El perfil no existe en Firestore.');
  }

  const previous = existing.data();
  const payload = await buildUserPayload(uid, data, previous);

  const authUpdate = {
    email: payload.correo,
    displayName: payload.nombre,
    disabled: payload.estado !== ACTIVE_STATUS,
  };

  if (typeof data.password === 'string' && data.password.trim() !== '') {
    authUpdate.password = data.password.trim();
  }

  await admin.auth().updateUser(uid, authUpdate);
  await userRef.set(payload, { merge: true });
  await writeUserLog({
    action: 'edicion',
    actor,
    targetUid: uid,
    targetName: payload.nombre,
    previousData: sanitizeUserPayload(previous),
    newData: sanitizeUserPayload(payload),
  });

  return { uid };
});

exports.deleteManagedUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
  }

  const actor = await getAdminProfile(request.auth.uid);
  const uid = normalizeString(request.data?.uid, 'uid');
  if (uid === request.auth.uid) {
    throw new HttpsError(
      'failed-precondition',
      'No puedes eliminar tu propio usuario administrador.',
    );
  }

  const userRef = db.collection(USER_COLLECTION).doc(uid);
  const existing = await userRef.get();
  if (!existing.exists) {
    throw new HttpsError('not-found', 'El perfil no existe en Firestore.');
  }

  const previous = existing.data();
  await writeUserLog({
    action: 'eliminacion',
    actor,
    targetUid: uid,
    targetName: previous.nombre ?? uid,
    previousData: sanitizeUserPayload(previous),
  });

  await admin.auth().deleteUser(uid);
  await userRef.delete();

  return { uid };
});
