const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

const db = admin.firestore();
const ACTIVE_STATUS = 'activo';
const USER_COLLECTION = 'usuarios';
const USER_LOG_COLLECTION = 'usuarios_logs';
const DOCUMENT_TYPE_COLLECTION = 'tipos_documento';
const ROLE_COLLECTION = 'roles';
const SECTOR_COLLECTION = 'sectores';
const PERIOD_COLLECTION = 'periodos';
const MIN_CONSUMPTION_HISTORY_PERIOD = '2025-12';

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

function normalizeUppercaseCode(value, field) {
  const normalized = normalizeString(value, field).toUpperCase();
  if (!/^[A-Z0-9]+$/.test(normalized)) {
    throw new HttpsError(
      'invalid-argument',
      `El campo ${field} solo puede contener letras y numeros.`,
    );
  }
  return normalized;
}

function normalizeLowercase(value, field) {
  return normalizeString(value, field).toLowerCase();
}

function normalizeOptionalLowercase(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function normalizeOptionalString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function isMissingProfileValue(value) {
  const normalized = typeof value === 'string' ? value.trim().toLowerCase() : '';
  return !normalized || normalized === 'na' || normalized === 'null';
}

function toStorageValue(value) {
  const normalized = normalizeOptionalString(value);
  if (!normalized || normalized.toLowerCase() === 'null') {
    return 'na';
  }
  return normalized;
}

function generateTemporaryPassword() {
  return `Tmp-${crypto.randomBytes(18).toString('base64url')}1a`;
}

function normalizePeriodId(value) {
  const normalized = normalizeString(value, 'periodo').toUpperCase();
  if (!/^\d{4}-\d{2}$/.test(normalized)) {
    throw new HttpsError(
      'invalid-argument',
      'El periodo debe tener formato YYYY-MM, por ejemplo 2026-01.',
    );
  }
  return normalized;
}

function normalizePositiveInteger(value, field) {
  const raw = typeof value === 'number' ? String(value) : normalizeString(value, field);
  const normalized = raw.trim();
  if (!/^\d+$/.test(normalized)) {
    throw new HttpsError('invalid-argument', `El campo ${field} debe ser numerico.`);
  }
  return Number.parseInt(normalized, 10);
}

function normalizeStringList(value, field) {
  if (!Array.isArray(value)) {
    throw new HttpsError('invalid-argument', `El campo ${field} debe ser una lista.`);
  }

  const normalized = value
    .map((item) => (typeof item === 'string' ? item.trim().toUpperCase() : ''))
    .filter((item) => item && item.toLowerCase() !== 'na');

  if (normalized.length === 0) {
    throw new HttpsError('invalid-argument', `El campo ${field} es obligatorio.`);
  }
  for (const item of normalized) {
    if (!/^[A-Z0-9]+$/.test(item)) {
      throw new HttpsError(
        'invalid-argument',
        `El campo ${field} solo puede contener letras y numeros.`,
      );
    }
  }

  const unique = [...new Set(normalized)];
  if (unique.length !== normalized.length) {
    throw new HttpsError(
      'invalid-argument',
      `El campo ${field} no puede tener contadores repetidos.`,
    );
  }

  return unique;
}

function normalizeSingleCounter(value, field) {
  const normalized = normalizeStringList(value, field);
  if (normalized.length !== 1) {
    throw new HttpsError(
      'invalid-argument',
      `El campo ${field} debe tener exactamente un contador.`,
    );
  }
  return normalized;
}

function mapAdminError(error) {
  switch (error?.code) {
    case 'auth/email-already-exists':
      return new HttpsError(
        'already-exists',
        'Ya existe un usuario con ese correo en Firebase Authentication.',
      );
    case 'auth/invalid-email':
      return new HttpsError(
        'invalid-argument',
        'El correo no tiene un formato valido.',
      );
    case 'auth/invalid-password':
      return new HttpsError(
        'invalid-argument',
        'La clave no cumple las reglas minimas de Firebase Authentication.',
      );
    case 'auth/user-not-found':
      return new HttpsError(
        'not-found',
        'El usuario no existe en Firebase Authentication.',
      );
    default:
      return new HttpsError(
        'internal',
        error?.message || 'Ocurrio un error interno al procesar el usuario.',
      );
  }
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

async function ensureUniqueDocumentNumber(uid, numeroDocumento) {
  const snapshot = await db
    .collection(USER_COLLECTION)
    .where('numeroDocumento', '==', numeroDocumento)
    .limit(5)
    .get();

  for (const doc of snapshot.docs) {
    if (doc.id !== uid) {
      throw new HttpsError(
        'already-exists',
        `El número de documento ${numeroDocumento} ya está asignado a otro usuario.`,
      );
    }
  }
}

async function ensureUniqueClientIdentifiers(uid, codigoUsuario, numeroContador) {
  const codeSnapshot = await db
    .collection(USER_COLLECTION)
    .where('codigoUsuario', '==', codigoUsuario)
    .limit(5)
    .get();

  for (const doc of codeSnapshot.docs) {
    if (doc.id !== uid) {
      throw new HttpsError(
        'already-exists',
        `El código de usuario ${codigoUsuario} ya está asignado a otro cliente.`,
      );
    }
  }

  for (const contador of numeroContador) {
    const meterSnapshot = await db
      .collection(USER_COLLECTION)
      .where('numeroContador', 'array-contains', contador)
      .limit(5)
      .get();

    for (const doc of meterSnapshot.docs) {
      if (doc.id !== uid) {
        throw new HttpsError(
          'already-exists',
          `El contador ${contador} ya está asignado a otro cliente.`,
        );
      }
    }
  }
}

async function findUserByClientCode(codigoUsuario) {
  const snapshot = await db
    .collection(USER_COLLECTION)
    .where('codigoUsuario', '==', codigoUsuario)
    .limit(2)
    .get();

  if (snapshot.empty) {
    throw new HttpsError(
      'not-found',
      'No existe un usuario activo con ese codigo de usuario.',
    );
  }
  if (snapshot.size > 1) {
    throw new HttpsError(
      'failed-precondition',
      'Hay mas de un usuario con ese codigo. Contacta al administrador.',
    );
  }

  const doc = snapshot.docs[0];
  const data = doc.data();
  if (data.estado !== ACTIVE_STATUS) {
    throw new HttpsError('permission-denied', 'Esta cuenta esta inactiva.');
  }
  if (data.rol !== 'cliente') {
    throw new HttpsError(
      'permission-denied',
      'El acceso por codigo de usuario solo aplica para clientes.',
    );
  }
  return { doc, data };
}

async function getOrCreateAuthUserForProfile(profileDoc, profileData, email) {
  const existingUid = profileData.uid || profileDoc.id;

  try {
    const user = await admin.auth().getUser(existingUid);
    const update = {
      displayName: profileData.nombre ?? '',
      disabled: profileData.estado !== ACTIVE_STATUS,
    };
    if (email && (user.email ?? '').toLowerCase() !== email) {
      update.email = email;
    }
    await admin.auth().updateUser(existingUid, update);
    return user.uid;
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  if (email) {
    try {
      const userByEmail = await admin.auth().getUserByEmail(email);
      await profileDoc.ref.set(
        {
          uid: userByEmail.uid,
          correo: email,
          fechaActualizacion: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return userByEmail.uid;
    } catch (error) {
      if (error?.code !== 'auth/user-not-found') {
        throw error;
      }
    }
  }

  const createPayload = {
    uid: existingUid,
    displayName: profileData.nombre ?? '',
    disabled: profileData.estado !== ACTIVE_STATUS,
  };
  if (email) {
    createPayload.email = email;
  }
  const created = await admin.auth().createUser(createPayload);
  return created.uid;
}

async function findClientByCode(codigoUsuario) {
  const snapshot = await db
    .collection(USER_COLLECTION)
    .where('codigoUsuario', '==', codigoUsuario)
    .limit(2)
    .get();

  if (snapshot.empty) {
    throw new HttpsError('not-found', 'No existe cliente con ese codigo.');
  }
  if (snapshot.size > 1) {
    throw new HttpsError(
      'failed-precondition',
      'Hay mas de un cliente con ese codigo.',
    );
  }
  const doc = snapshot.docs[0];
  const data = doc.data();
  if (data.rol !== 'cliente') {
    throw new HttpsError('failed-precondition', 'El codigo no pertenece a un cliente.');
  }
  const meters = Array.isArray(data.numeroContador)
    ? data.numeroContador.filter((item) => typeof item === 'string' && item.trim())
    : [];
  if (meters.length !== 1) {
    throw new HttpsError(
      'failed-precondition',
      'El cliente debe tener exactamente un contador.',
    );
  }
  return {
    uid: doc.id,
    data,
    meterCode: meters[0].trim().toUpperCase(),
  };
}

async function fetchPreviousConsumption(meterCode, currentPeriod) {
  const snapshot = await db.collection(PERIOD_COLLECTION).get();
  const periods = snapshot.docs
    .map((doc) => doc.id)
    .filter((period) =>
      period >= MIN_CONSUMPTION_HISTORY_PERIOD && period < currentPeriod)
    .sort((a, b) => b.localeCompare(a));

  for (const period of periods) {
    const reading = await db
      .collection(PERIOD_COLLECTION)
      .doc(period)
      .collection('consumos')
      .doc(meterCode)
      .get();
    if (reading.exists) {
      return reading.data();
    }
  }
  return null;
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
    tipoCliente: data.tipoCliente,
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
    numeroContador: [],
    rol: role.valor,
    tipoCliente: 'na',
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
    payload.tipoCliente = normalizeLowercase(data.tipoCliente, 'tipoCliente');
    if (!['socio', 'suscriptor'].includes(payload.tipoCliente)) {
      throw new HttpsError(
        'invalid-argument',
        'El tipo de cliente debe ser socio o suscriptor.',
      );
    }

    const sector = await getActiveCatalogValue(
      SECTOR_COLLECTION,
      normalizeLowercase(data.sector, 'sector'),
      'sector',
    );
    payload.codigoUsuario = normalizeUppercaseCode(data.codigoUsuario, 'codigoUsuario');
    payload.numeroContador = normalizeSingleCounter(data.numeroContador, 'numeroContador');
    payload.sector = sector.valor;
    await ensureUniqueClientIdentifiers(uid, payload.codigoUsuario, payload.numeroContador);
  }

  return payload;
}

exports.createManagedUser = onCall({ cors: true, invoker: 'public' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
  }

  try {
    const actor = await getAdminProfile(request.auth.uid);
    const data = request.data ?? {};
    const email = normalizeLowercase(data.correo, 'correo');
    let password =
      typeof data.password === 'string' && data.password.trim() !== ''
        ? data.password.trim()
        : null;

    const payload = await buildUserPayload('', data);
    if (payload.rol !== 'cliente' && !password) {
      throw new HttpsError(
        'invalid-argument',
        'La clave temporal es obligatoria para usuarios internos.',
      );
    }
    if (payload.rol === 'cliente' && !password) {
      password = generateTemporaryPassword();
    }

    const authPayload = {
      email,
      displayName: payload.nombre,
      disabled: payload.estado !== ACTIVE_STATUS,
    };
    if (password) {
      authPayload.password = password;
    }
    const authUser = await admin.auth().createUser(authPayload);

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
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    throw mapAdminError(error);
  }
});

exports.updateManagedUser = onCall({ cors: true, invoker: 'public' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
  }

  try {
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
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    throw mapAdminError(error);
  }
});

exports.deleteManagedUser = onCall({ cors: true, invoker: 'public' }, async (request) => {
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

exports.signInWithClientCode = onCall({ cors: true, invoker: 'public' }, async (request) => {
  try {
    const codigoUsuario = normalizeUppercaseCode(request.data?.codigoUsuario, 'codigoUsuario');
    const email = normalizeOptionalLowercase(request.data?.correo);
    const documentNumber =
      typeof request.data?.numeroDocumento === 'string'
        ? request.data.numeroDocumento.trim()
        : '';
    const contactNumber =
      typeof request.data?.numeroContacto === 'string'
        ? request.data.numeroContacto.trim()
        : '';
    const { doc, data } = await findUserByClientCode(codigoUsuario);
    const storedEmail = normalizeOptionalLowercase(data.correo);
    const profileIsIncomplete =
      isMissingProfileValue(data.correo) ||
      isMissingProfileValue(data.numeroDocumento) ||
      isMissingProfileValue(data.numeroContacto);

    if (profileIsIncomplete) {
      if (!email || !documentNumber || !contactNumber) {
        return { requiresProfileCompletion: true };
      }
    }

    if (storedEmail && storedEmail !== 'na' && !email) {
      throw new HttpsError(
        'invalid-argument',
        'Ingresa el correo asociado a este codigo de usuario.',
      );
    }

    if (storedEmail && storedEmail !== 'na' && storedEmail !== email) {
      throw new HttpsError(
        'permission-denied',
        'El correo no coincide con el codigo de usuario.',
      );
    }

    const uid = await getOrCreateAuthUserForProfile(doc, data, email);
    const updateData = {
      uid,
      fechaActualizacion: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (email) {
      updateData.correo = email;
    }
    if (documentNumber) {
      updateData.numeroDocumento = documentNumber;
    }
    if (contactNumber) {
      updateData.numeroContacto = contactNumber;
    }

    if (doc.id !== uid) {
      await db.collection(USER_COLLECTION).doc(uid).set(
        {
          ...data,
          ...updateData,
        },
        { merge: true },
      );
      await doc.ref.delete();
    } else {
      await doc.ref.set(updateData, { merge: true });
    }

    const token = await admin.auth().createCustomToken(uid);
    return { token, requiresProfileCompletion: false };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    throw mapAdminError(error);
  }
});

exports.importMigratedUsers = onCall(
  { cors: true, invoker: 'public', timeoutSeconds: 1800, memory: '1GiB' },
  async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
  }

  const actor = await getAdminProfile(request.auth.uid);
  const rows = Array.isArray(request.data?.rows) ? request.data.rows : [];
  if (rows.length === 0) {
    throw new HttpsError('invalid-argument', 'No hay usuarios para importar.');
  }
  if (rows.length > 400) {
    throw new HttpsError(
      'invalid-argument',
      'Importa maximo 400 usuarios por archivo.',
    );
  }

  const results = [];
  const normalizedRows = [];
  const seenCodes = new Set();
  const seenMeters = new Set();

  for (let index = 0; index < rows.length; index++) {
    const row = rows[index] ?? {};
    const rowNumber = index + 2;
    try {
      const codigoUsuario = normalizeUppercaseCode(row.codigoUsuario, 'codigousuario');
      const numeroContador = normalizeUppercaseCode(row.numeroContador, 'numcontador');
      const tipoCliente = normalizeLowercase(row.tipoUsuario, 'tipousuario');
      if (!['socio', 'suscriptor'].includes(tipoCliente)) {
        throw new HttpsError(
          'invalid-argument',
          'tipousuario debe ser socio o suscriptor.',
        );
      }
      if (seenCodes.has(codigoUsuario)) {
        throw new HttpsError('already-exists', 'codigousuario repetido en el archivo.');
      }
      if (seenMeters.has(numeroContador)) {
        throw new HttpsError('already-exists', 'numcontador repetido en el archivo.');
      }
      seenCodes.add(codigoUsuario);
      seenMeters.add(numeroContador);

      const sector = await getActiveCatalogValue(
        SECTOR_COLLECTION,
        normalizeLowercase(row.sector, 'sector'),
        'sector',
      );

      normalizedRows.push({
        rowNumber,
        tipoCliente,
        sector: sector.valor,
        numeroContador,
        codigoUsuario,
        numeroDocumento: toStorageValue(row.numeroDocumento),
        numeroContacto: toStorageValue(row.numeroContacto),
        nombre: normalizeLowercase(row.nombre, 'nombre'),
        correo: normalizeOptionalLowercase(row.correo) || 'na',
      });
    } catch (error) {
      results.push({
        rowNumber,
        ok: false,
        message: error?.message || 'Fila invalida.',
      });
    }
  }

  if (results.some((item) => !item.ok)) {
    return {
      imported: 0,
      failed: results.length,
      results,
    };
  }

  for (const row of normalizedRows) {
    try {
      const existingByCode = await db
        .collection(USER_COLLECTION)
        .where('codigoUsuario', '==', row.codigoUsuario)
        .limit(1)
        .get();
      const targetRef = existingByCode.empty
        ? db.collection(USER_COLLECTION).doc()
        : existingByCode.docs[0].ref;
      const targetUid = targetRef.id;

      await ensureUniqueClientIdentifiers(targetUid, row.codigoUsuario, [
        row.numeroContador,
      ]);

      const existing = await targetRef.get();
      const payload = {
        uid: targetUid,
        nombre: row.nombre,
        tipoDocumento: 'cc',
        numeroDocumento: row.numeroDocumento,
        numeroContacto: row.numeroContacto,
        codigoUsuario: row.codigoUsuario,
        numeroContador: [row.numeroContador],
        rol: 'cliente',
        tipoCliente: row.tipoCliente,
        sector: row.sector,
        correo: row.correo,
        estado: ACTIVE_STATUS,
        fechaCreacion:
          existing.data()?.fechaCreacion ?? admin.firestore.FieldValue.serverTimestamp(),
        fechaActualizacion: existing.exists
          ? admin.firestore.FieldValue.serverTimestamp()
          : null,
      };

      await targetRef.set(payload, { merge: true });
      results.push({
        rowNumber: row.rowNumber,
        ok: true,
        uid: targetUid,
        codigoUsuario: row.codigoUsuario,
      });
    } catch (error) {
      results.push({
        rowNumber: row.rowNumber,
        ok: false,
        codigoUsuario: row.codigoUsuario,
        message: error?.message || 'No fue posible importar la fila.',
      });
    }
  }

  const imported = results.filter((item) => item.ok).length;
  const failed = results.length - imported;
  await writeUserLog({
    action: 'importacion',
    actor,
    targetUid: 'importacion_usuarios',
    targetName: `Importacion usuarios (${imported})`,
    newData: { imported, failed },
  });

  return { imported, failed, results };
});

exports.normalizeImportedUserPlaceholders = onCall(
  { cors: true, invoker: 'public', timeoutSeconds: 540, memory: '1GiB' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
    }
    await getAdminProfile(request.auth.uid);

    let updated = 0;
    let cursor = null;
    const fields = ['correo', 'numeroDocumento', 'numeroContacto'];

    while (true) {
      let query = db.collection(USER_COLLECTION).orderBy('nombre').limit(400);
      if (cursor) {
        query = query.startAfter(cursor);
      }
      const snapshot = await query.get();
      if (snapshot.empty) {
        break;
      }

      const batch = db.batch();
      for (const doc of snapshot.docs) {
        const data = doc.data();
        const patch = {};
        for (const field of fields) {
          if (typeof data[field] === 'string' && data[field].trim().toLowerCase() === 'null') {
            patch[field] = 'na';
          }
        }
        if (Object.keys(patch).length > 0) {
          patch.fechaActualizacion = admin.firestore.FieldValue.serverTimestamp();
          batch.set(doc.ref, patch, { merge: true });
          updated++;
        }
      }
      await batch.commit();

      cursor = snapshot.docs[snapshot.docs.length - 1];
      if (snapshot.size < 400) {
        break;
      }
    }

    return { updated };
  },
);

exports.importConsumptionReadings = onCall(
  { cors: true, invoker: 'public', timeoutSeconds: 1800, memory: '1GiB' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
    }
    const actor = await getAdminProfile(request.auth.uid);
    const period = normalizePeriodId(request.data?.periodo);
    const rows = Array.isArray(request.data?.rows) ? request.data.rows : [];
    if (rows.length === 0) {
      throw new HttpsError('invalid-argument', 'No hay consumos para importar.');
    }
    if (rows.length > 800) {
      throw new HttpsError(
        'invalid-argument',
        'Importa maximo 800 consumos por archivo.',
      );
    }

    const results = [];
    let imported = 0;
    let ignored = 0;
    let failed = 0;
    const seenCodes = new Set();

    for (let index = 0; index < rows.length; index++) {
      const rowNumber = index + 2;
      const row = rows[index] ?? {};
      let codigoUsuario = '';
      try {
        codigoUsuario = normalizeUppercaseCode(row.codigoUsuario, 'codigousuario');
        const lecturaActual = normalizePositiveInteger(row.lecturaActual, 'lecturaActual');
        if (seenCodes.has(codigoUsuario)) {
          ignored++;
          results.push({
            rowNumber,
            ok: false,
            ignored: true,
            codigoUsuario,
            message: 'Codigo usuario repetido en el archivo.',
          });
          continue;
        }
        seenCodes.add(codigoUsuario);

        const client = await findClientByCode(codigoUsuario);
        const readingRef = db
          .collection(PERIOD_COLLECTION)
          .doc(period)
          .collection('consumos')
          .doc(client.meterCode);
        const existing = await readingRef.get();
        if (existing.exists) {
          ignored++;
          results.push({
            rowNumber,
            ok: false,
            ignored: true,
            codigoUsuario,
            codigoContador: client.meterCode,
            message: 'Ya existe una lectura para ese periodo y contador.',
          });
          continue;
        }

        const previous = await fetchPreviousConsumption(client.meterCode, period);
        const previousValue =
          typeof previous?.lecturaActual === 'number' ? previous.lecturaActual : null;
        const now = admin.firestore.Timestamp.now();
        const payload = {
          id: `${period}|${client.meterCode}`,
          codigoUsuario,
          codigoContador: client.meterCode,
          nombreUsuario: client.data.nombre ?? '',
          lecturaActual,
          periodoActual: period,
          fecha: now,
          nombreOperario: actor.nombre,
          actorUid: actor.uid,
          estado: 'sincronizado',
          lecturaAnterior: previousValue,
          consumoCalculado:
            previousValue == null ? null : lecturaActual - previousValue,
          facturado: false,
          pagado: false,
          conflictoId: null,
          detalleEstado: null,
          observacionesOperario: 'Importado desde archivo',
          observacionesAdmin: null,
          reciboId: null,
          irregularidad: null,
        };
        const historyRef = readingRef
          .collection('historial')
          .doc(`${Date.now()}_${index}`);

        await db.runTransaction(async (transaction) => {
          transaction.set(readingRef, payload, { merge: true });
          transaction.set(historyRef, {
            tipoEvento: 'captura_importada',
            actorUid: actor.uid,
            actorNombre: actor.nombre,
            actorRol: 'administrador',
            fecha: now,
            estadoAnterior: null,
            estadoNuevo: 'sincronizado',
            valorAnterior: previousValue,
            valorNuevo: lecturaActual,
            motivo: 'Importacion masiva de consumos',
            observaciones: null,
            periodosImpactados: [],
          });
        });

        imported++;
        results.push({
          rowNumber,
          ok: true,
          ignored: false,
          codigoUsuario,
          codigoContador: client.meterCode,
        });
      } catch (error) {
        failed++;
        results.push({
          rowNumber,
          ok: false,
          ignored: false,
          codigoUsuario,
          message: error?.message || 'No fue posible importar la lectura.',
        });
      }
    }

    return { imported, ignored, failed, period, results };
  },
);
