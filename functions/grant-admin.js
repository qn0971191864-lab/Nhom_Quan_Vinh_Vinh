const fs = require('fs');
const path = require('path');
const os = require('os');
const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const PROJECT_ID = 'app-dau-gia-36729';
const TARGET_EMAILS = process.argv.slice(2).length > 0
  ? process.argv.slice(2)
  : ['admin@gmail.com', 'admin1@gmail.com'];

function getCredential() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (fs.existsSync(configPath)) {
    try {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      if (config.tokens?.access_token) {
        return {
          accessToken: config.tokens.access_token,
          credential: {
            getAccessToken: () => Promise.resolve({
              access_token: config.tokens.access_token,
              expires_in: 3600,
            }),
          },
        };
      }
    } catch (_) {}
  }
  return {
    accessToken: null,
    credential: applicationDefault(),
  };
}

const { accessToken, credential } = getCredential();
const app = initializeApp({
  credential,
  projectId: PROJECT_ID,
});

async function updateFirestoreRole(uid, role, token) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}?updateMask.fieldPaths=role`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      fields: {
        role: { stringValue: role },
      },
    }),
  });

  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Lỗi cập nhật Firestore (HTTP ${res.status}): ${errorText}`);
  }
  return await res.json();
}

async function verifyFirestoreRole(uid, token) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`;
  const res = await fetch(url, {
    headers: { 'Authorization': `Bearer ${token}` },
  });
  if (!res.ok) return null;
  const data = await res.json();
  return data.fields?.role?.stringValue;
}

async function main() {
  const auth = getAuth(app);
  console.log(`=== BẮT ĐẦU CẤP QUYỀN ADMIN CHO DỰ ÁN [${PROJECT_ID}] ===\n`);

  for (const email of TARGET_EMAILS) {
    console.log(`➤ Đang xử lý tài khoản: ${email}`);
    try {
      const user = await auth.getUserByEmail(email.trim());
      console.log(`   - UID: ${user.uid}`);
      console.log(`   - Tên hiển thị: ${user.displayName || '(chưa đặt)'}`);
      
      // 1. Cấp Firebase Auth Custom Claim: { admin: true }
      await auth.setCustomUserClaims(user.uid, {
        ...user.customClaims,
        admin: true,
      });
      console.log(`   ✔ [Firebase Auth] Đã gán Custom Claim: { admin: true }`);

      // 2. Cập nhật role = 'ADMIN' trong Firestore users/{uid}
      if (accessToken) {
        await updateFirestoreRole(user.uid, 'ADMIN', accessToken);
        const verifiedRole = await verifyFirestoreRole(user.uid, accessToken);
        console.log(`   ✔ [Cloud Firestore] Đã cập nhật users/${user.uid}.role = '${verifiedRole}'`);
      } else {
        console.log(`   ⚠ Không có Firebase CLI token để ghi Firestore trực tiếp qua REST.`);
      }

      // 3. Xác minh lại Auth Claims
      const updatedUser = await auth.getUser(user.uid);
      console.log(`   ✔ [Xác minh Auth] Claims hiện tại:`, JSON.stringify(updatedUser.customClaims));
      console.log(`   ==> CẤP QUYỀN THÀNH CÔNG CHO: ${email}\n`);
    } catch (error) {
      console.error(`   ✖ Lỗi khi xử lý ${email}:`, error.message, '\n');
      process.exitCode = 1;
    }
  }

  console.log(`=== HOÀN TẤT QUÁ TRÌNH CẤP QUYỀN ===`);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exitCode = 1;
});
