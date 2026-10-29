const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

initializeApp({
  credential: applicationDefault(),
  projectId: 'app-dau-gia-36729',
});

async function main() {
  const auth = getAuth();
  const user = await auth.getUserByEmail('admin@gmail.com');
  await auth.setCustomUserClaims(user.uid, {
    ...user.customClaims,
    admin: true,
  });
  console.log(`Đã cấp admin cho UID: ${user.uid}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});