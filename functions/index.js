const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();

const db = getFirestore();

/**
 * Creates the coach account after a public team registration and queues the
 * password setup email for the Firebase Trigger Email extension.
 */
exports.createCoachFromRegistration = onDocumentCreated(
  'tournaments/{tournamentId}/registrations/{registrationId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const registration = snapshot.data();
    const email = String(registration.coachEmail || '').trim().toLowerCase();
    const coachName = String(registration.coachName || '').trim();

    if (!email || !coachName) {
      await snapshot.ref.update({
        accountStatus: 'error',
        accountError: 'coachEmail y coachName son obligatorios',
      });
      return;
    }

    const auth = getAuth();
    let user;
    try {
      user = await auth.getUserByEmail(email);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      user = await auth.createUser({ email, displayName: coachName });
    }

    const currentClaims = (await auth.getUser(user.uid)).customClaims || {};
    const roles = Array.from(new Set([
      ...(Array.isArray(currentClaims.roles) ? currentClaims.roles : []),
      'entrenador',
    ]));
    await auth.setCustomUserClaims(user.uid, { ...currentClaims, roles, rol: 'entrenador' });

    await db.collection('users').doc(user.uid).set({
      uid: user.uid,
      email,
      nombre: coachName,
      roles,
      rol: 'entrenador',
      estado: 'activo',
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    const actionCodeSettings = {
      url: 'https://handplaydemo.web.app/login',
      handleCodeInApp: false,
    };
    const resetLink = await auth.generatePasswordResetLink(email, actionCodeSettings);
    const mailRef = db.collection('mail').doc(`coach-${snapshot.id}`);
    await mailRef.set({
      to: email,
      message: {
        subject: 'Activa tu cuenta de entrenador en HandPlay',
        text: `Hola ${coachName}, configura tu contraseña en este enlace: ${resetLink}`,
        html: `<p>Hola ${coachName},</p><p>Configura tu contraseña para acceder a HandPlay:</p><p><a href="${resetLink}">Configurar contraseña</a></p>`,
      },
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    const teamRef = db
      .collection('tournaments')
      .doc(event.params.tournamentId)
      .collection('teams')
      .doc(snapshot.id);

    await teamRef.set({
      id: snapshot.id,
      tournamentId: event.params.tournamentId,
      registrationId: snapshot.id,
      name: String(registration.teamName || '').trim(),
      clubName: String(registration.clubName || '').trim(),
      category: registration.category || null,
      uniformColor: registration.uniformColor || null,
      coachUid: user.uid,
      coachName,
      coachEmail: email,
      players: Array.isArray(registration.players) ? registration.players : [],
      playerCount: Array.isArray(registration.players) ? registration.players.length : 0,
      status: 'pending',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    await snapshot.ref.update({
      coachUid: user.uid,
      teamId: snapshot.id,
      accountStatus: 'created',
      accountUpdatedAt: FieldValue.serverTimestamp(),
    });
  },
);
