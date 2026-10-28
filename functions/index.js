const {
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');

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
    let createdCoachAccount = false;
    try {
      user = await auth.getUserByEmail(email);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      user = await auth.createUser({ email, displayName: coachName });
      createdCoachAccount = true;
    }

    const currentClaims = (await auth.getUser(user.uid)).customClaims || {};
    const currentRoles = new Set([
      ...(Array.isArray(currentClaims.roles) ? currentClaims.roles : []),
      ...(typeof currentClaims.rol === 'string' ? [currentClaims.rol] : []),
    ].map((role) => String(role).trim().toLowerCase()));
    const isCoachAccount = createdCoachAccount || currentRoles.has('entrenador') || currentRoles.has('coach');
    let accountStatus = isCoachAccount ? 'created' : 'needs_admin_review';

    if (createdCoachAccount) {
      const roles = Array.from(new Set([...currentRoles, 'entrenador']));
      await auth.setCustomUserClaims(user.uid, { ...currentClaims, roles, rol: 'entrenador' });
      await db.collection('users').doc(user.uid).set({
        uid: user.uid,
        email,
        displayName: coachName,
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
    } else if (isCoachAccount) {
      accountStatus = 'linked_existing_coach';
    }

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
      ...(isCoachAccount ? { coachUid: user.uid } : {}),
      coachName,
      coachEmail: email,
      players: Array.isArray(registration.players) ? registration.players : [],
      playerCount: Array.isArray(registration.players) ? registration.players.length : 0,
      status: 'pending',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    await snapshot.ref.update({
      ...(isCoachAccount ? { coachUid: user.uid } : {}),
      teamId: snapshot.id,
      accountStatus,
      accountUpdatedAt: FieldValue.serverTimestamp(),
    });
  },
);

exports.syncPublicTeamSummary = onDocumentUpdated(
  'tournaments/{tournamentId}/registrations/{registrationId}',
  async (event) => {
    const registration = event.data?.after.data();
    if (!registration) return;

    const publicTeamRef = db
      .collection('tournaments')
      .doc(event.params.tournamentId)
      .collection('public_teams')
      .doc(event.params.registrationId);

    if (registration.status !== 'approved') {
      if (event.data.before.data()?.status === 'approved') {
        await publicTeamRef.delete();
      }
      return;
    }

    const players = Array.isArray(registration.players) ? registration.players : [];
    await publicTeamRef.set({
      registrationId: event.params.registrationId,
      teamName: String(registration.teamName || ''),
      clubName: String(registration.clubName || ''),
      clubs: Array.isArray(registration.clubs) ? registration.clubs : [],
      category: registration.category || null,
      uniformColor: registration.uniformColor || null,
      playerCount: players.length,
      players: players.map((player) => ({
        ...(player.name != null ? { name: player.name } : {}),
        ...(player.number != null ? { number: player.number } : {}),
        ...(player.position != null ? { position: player.position } : {}),
        ...(player.gender != null ? { gender: player.gender } : {}),
        ...(player.club != null ? { club: player.club } : {}),
      })),
      status: 'approved',
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  },
);

exports.activateTournamentWhenMatchFinishes = onDocumentUpdated(
  'tournaments/{tournamentId}/matches/{matchId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === 'finished' || after.status !== 'finished') {
      return;
    }

    const matchRef = event.data.after.ref;
    const tournamentRef = db.collection('tournaments').doc(event.params.tournamentId);
    await db.runTransaction(async (transaction) => {
      const currentMatch = await transaction.get(matchRef);
      const match = currentMatch.data();
      if (!match || match.status !== 'finished' || match.standingsAppliedAt) return;

      const tournament = await transaction.get(tournamentRef);
      const homeId = String(match.homeTeam || match.homeTeamId || match.local || '').trim();
      const awayId = String(match.awayTeam || match.awayTeamId || match.visitante || '').trim();
      const homeRef = tournamentRef.collection('registrations').doc(homeId);
      const awayRef = tournamentRef.collection('registrations').doc(awayId);
      const canUpdateStandings = homeId && awayId && homeId !== awayId;
      const homeSnapshot = canUpdateStandings ? await transaction.get(homeRef) : null;
      const awaySnapshot = canUpdateStandings ? await transaction.get(awayRef) : null;

      if (homeSnapshot?.exists && awaySnapshot?.exists
        && homeSnapshot.data().status === 'approved'
        && awaySnapshot.data().status === 'approved') {
        const home = homeSnapshot.data();
        const away = awaySnapshot.data();
        const homeScore = Number(match.finalHomeScore ?? match.homeScore ?? 0);
        const awayScore = Number(match.finalAwayScore ?? match.awayScore ?? 0);
        const draw = homeScore === awayScore;
        const makeStats = (current, scoreFor, scoreAgainst, win) => {
          const points = (Number(current.points) || 0) + (win ? 3 : draw ? 1 : 0);
          const played = (Number(current.played) || 0) + 1;
          const wins = (Number(current.wins) || 0) + (win ? 1 : 0);
          const draws = (Number(current.draws) || 0) + (draw ? 1 : 0);
          const losses = (Number(current.losses) || 0) + (!win && !draw ? 1 : 0);
          const goalsFor = (Number(current.goalsFor) || 0) + scoreFor;
          const goalsAgainst = (Number(current.goalsAgainst) || 0) + scoreAgainst;
          return {
            points, played, wins, draws, losses, goalsFor, goalsAgainst,
            pts: points, pj: played, pg: wins, pe: draws, pp: losses,
            gf: goalsFor, gc: goalsAgainst,
          };
        };
        const homeStats = makeStats(home, homeScore, awayScore, homeScore > awayScore);
        const awayStats = makeStats(away, awayScore, homeScore, awayScore > homeScore);
        const publicHomeRef = tournamentRef.collection('public_teams').doc(homeId);
        const publicAwayRef = tournamentRef.collection('public_teams').doc(awayId);
        const publicHome = await transaction.get(publicHomeRef);
        const publicAway = await transaction.get(publicAwayRef);

        const publicFields = (registration, registrationId, stats) => ({
          registrationId,
          teamName: String(registration.teamName || ''),
          clubName: String(registration.clubName || ''),
          clubs: Array.isArray(registration.clubs) ? registration.clubs : [],
          category: registration.category || null,
          uniformColor: registration.uniformColor || null,
          playerCount: Array.isArray(registration.players) ? registration.players.length : 0,
          players: (Array.isArray(registration.players) ? registration.players : []).map((player) => ({
            ...(player.name != null ? { name: player.name } : {}),
            ...(player.number != null ? { number: player.number } : {}),
            ...(player.position != null ? { position: player.position } : {}),
            ...(player.gender != null ? { gender: player.gender } : {}),
            ...(player.club != null ? { club: player.club } : {}),
          })),
          status: 'approved',
          ...stats,
          updatedAt: FieldValue.serverTimestamp(),
        });

        transaction.update(homeRef, homeStats);
        transaction.update(awayRef, awayStats);
        transaction.set(publicHomeRef, publicFields(home, homeId, homeStats), { merge: true });
        transaction.set(publicAwayRef, publicFields(away, awayId, awayStats), { merge: true });
        if (!publicHome.exists || !publicAway.exists) {
          logger.info('Created missing public team summaries while finalizing match', {
            tournamentId: event.params.tournamentId,
            matchId: event.params.matchId,
          });
        }
      } else {
        logger.warn('Standings skipped because approved team registrations were not found', {
          tournamentId: event.params.tournamentId,
          matchId: event.params.matchId,
        });
      }

      if (tournament.exists) {
        transaction.update(tournamentRef, {
          status: 'active',
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.update(matchRef, {
        standingsAppliedAt: FieldValue.serverTimestamp(),
        standingsUpdateStatus: homeSnapshot?.exists && awaySnapshot?.exists
          ? 'updated'
          : 'skipped',
      });
    });
  },
);
