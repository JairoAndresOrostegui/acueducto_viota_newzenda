const fs = require('node:fs');
const path = require('node:path');
const {
  after,
  before,
  beforeEach,
  describe,
  it,
} = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'demo-acueducto';
let testEnvironment;

function userProfile({
  uid,
  role,
  status = 'activo',
  superAdmin = false,
}) {
  return {
    uid,
    nombre: uid,
    rol: role,
    estado: status,
    superAdmin,
    codigoUsuario: role === 'cliente' ? uid.toUpperCase() : 'NA',
  };
}

async function seedProfiles() {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    await Promise.all([
      setDoc(
        doc(database, 'usuarios/admin'),
        userProfile({ uid: 'admin', role: 'administrador' }),
      ),
      setDoc(
        doc(database, 'usuarios/other-admin'),
        userProfile({ uid: 'other-admin', role: 'administrador' }),
      ),
      setDoc(
        doc(database, 'usuarios/client'),
        userProfile({ uid: 'client', role: 'cliente' }),
      ),
    ]);
  });
}

describe('Firestore user security rules', () => {
  before(async () => {
    testEnvironment = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: fs.readFileSync(
          path.resolve(__dirname, '../../firestore.rules'),
          'utf8',
        ),
      },
    });
  });

  beforeEach(async () => {
    await testEnvironment.clearFirestore();
    await seedProfiles();
  });

  after(async () => {
    await testEnvironment.cleanup();
  });

  it('allows an active administrator to read user profiles', async () => {
    const database = testEnvironment
      .authenticatedContext('admin')
      .firestore();

    await assertSucceeds(getDoc(doc(database, 'usuarios/client')));
  });

  it('allows a client to read their own profile', async () => {
    const database = testEnvironment
      .authenticatedContext('client')
      .firestore();

    await assertSucceeds(getDoc(doc(database, 'usuarios/client')));
  });

  it('prevents an administrator from granting superAdmin directly', async () => {
    const database = testEnvironment
      .authenticatedContext('admin')
      .firestore();

    await assertFails(
      updateDoc(doc(database, 'usuarios/admin'), { superAdmin: true }),
    );
  });

  it('prevents an administrator from deleting another administrator directly', async () => {
    const database = testEnvironment
      .authenticatedContext('admin')
      .firestore();

    await assertFails(deleteDoc(doc(database, 'usuarios/other-admin')));
  });

  it('prevents direct user creation and forces the Cloud Function path', async () => {
    const database = testEnvironment
      .authenticatedContext('admin')
      .firestore();

    await assertFails(
      setDoc(
        doc(database, 'usuarios/new-client'),
        userProfile({ uid: 'new-client', role: 'cliente' }),
      ),
    );
  });
});
