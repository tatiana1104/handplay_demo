const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const serviceAccount = require('../serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const auth = getAuth();
const db = getFirestore();

const testUsers = [
  { email: 'admin.liga.test@handplaydemo.test', name: 'Administrador de liga', role: 'admin_liga' },
  { email: 'jugador.test@handplaydemo.test', name: 'Jugador de prueba', role: 'jugador' },
  { email: 'entrenador.test@handplaydemo.test', name: 'Entrenador de prueba', role: 'entrenador' },
  { email: 'arbitro.test@handplaydemo.test', name: 'Árbitro de prueba', role: 'arbitro' },
];

function createTemporaryPassword() {
  return `Hp-${Math.random().toString(36).slice(2, 10)}-${Date.now().toString(36)}`;
}

async function createOrUpdateUser(definition) {
  const password = createTemporaryPassword();
  let user;

  try {
    user = await auth.getUserByEmail(definition.email);
    user = await auth.updateUser(user.uid, {
      displayName: definition.name,
      password,
      emailVerified: false,
    });
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    user = await auth.createUser({
      email: definition.email,
      password,
      displayName: definition.name,
      emailVerified: false,
    });
  }

  await auth.setCustomUserClaims(user.uid, { rol: definition.role });
  await db.collection('users').doc(user.uid).set({
    uid: user.uid,
    nombre: definition.name,
    correo: definition.email,
    rol: definition.role,
    estado: 'activo',
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ...definition, uid: user.uid, password };
}

(async () => {
  const createdUsers = [];
  for (const definition of testUsers) {
    createdUsers.push(await createOrUpdateUser(definition));
  }

  console.log('\nUsuarios creados/actualizados. Guarda estas contraseñas temporalmente:');
  console.table(createdUsers.map(({ email, role, uid, password }) => ({ email, role, uid, password })));
  console.log('\nEl usuario debe cerrar sesión y volver a entrar para recibir el custom claim.');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
