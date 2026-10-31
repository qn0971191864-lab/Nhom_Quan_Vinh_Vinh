const { FieldValue, Timestamp } = require('firebase-admin/firestore');

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function renderTemplate(eventType, data) {
  const brand = 'Sàn đấu giá';
  const common = (title, rows, actionUrl = null) => {
    const body = rows.map(([label, value]) =>
      `<tr><td style="padding:8px 0;color:#667085">${escapeHtml(label)}</td><td style="padding:8px 0;text-align:right;font-weight:700">${escapeHtml(value)}</td></tr>`).join('');
    const button = actionUrl
      ? `<p><a href="${escapeHtml(actionUrl)}" style="display:inline-block;padding:12px 18px;background:#14243A;color:white;text-decoration:none;border-radius:8px">Mở phòng đấu giá</a></p>`
      : '';
    return {
      subject: `${brand} - ${title}`,
      html: `<div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;color:#101828"><h2>${escapeHtml(title)}</h2><table width="100%" style="border-collapse:collapse">${body}</table>${button}<p style="color:#667085;font-size:12px">Email tự động từ ${brand}</p></div>`,
      text: `${title}\n${rows.map(([label, value]) => `${label}: ${value}`).join('\n')}${actionUrl ? `\n${actionUrl}` : ''}`,
    };
  };

  if (eventType === 'AUCTION_CREATED') {
    return common('Phiên đấu giá đã được tạo', [
      ['Tên vật phẩm', data.itemName],
      ['Mã phiên', data.auctionId],
      ['Giá khởi điểm', `${data.startingPrice} VNĐ`],
      ['Bước giá', `${data.minimumIncrement} VNĐ`],
      ['Thời gian bắt đầu', data.startTime],
      ['Thời gian kết thúc', data.endTime],
    ], data.auctionUrl);
  }
  if (eventType === 'BID_PLACED') {
    return common('Đặt giá thành công', [
      ['Mã phiên', data.auctionId],
      ['Max Bid', `${data.maxBid} VNĐ`],
      ['Giá hiện tại', `${data.currentBid} VNĐ`],
      ['Tiền cọc khóa', `${data.depositLocked ?? 0} VNĐ`],
      ['Thời gian đặt', data.bidTime],
    ], data.auctionUrl);
  }
  if (eventType === 'WINNER_PAYMENT_SUCCESS') {
    return common('Thanh toán thành công', [
      ['Mã đơn hàng', data.orderId],
      ['Giá trúng', `${data.winningBid} VNĐ`],
      ['Tiền cọc đã khấu trừ', `${data.depositApplied} VNĐ`],
      ['Số tiền vừa thanh toán', `${data.paidAmount} VNĐ`],
      ['Người nhận', data.fullName],
      ['Địa chỉ nhận hàng', data.address],
    ]);
  }
  if (eventType === 'SELLER_PAYOUT_SUCCESS') {
    return common('Đã giải ngân tiền thắng đấu giá', [
      ['Mã đơn hàng', data.orderId],
      ['Tổng giá trị trúng đấu giá', `${data.winningBid} VNĐ`],
      ['Phí dịch vụ sàn', `${data.platformFee} VNĐ (${data.platformFeeRate}%)`],
      ['Số tiền thực nhận', `${data.netAmount} VNĐ`],
      ['Trạng thái ví người bán', 'Đã cộng vào ví'],
    ]);
  }
  throw new Error(`Unsupported email event: ${eventType}`);
}

async function enqueueEmail(db, { userUid, email, eventType, data }) {
  const template = renderTemplate(eventType, data);
  await db.collection('email_logs').doc().set({
    userUid,
    toEmail: email,
    eventType,
    subject: template.subject,
    htmlBody: template.html,
    textBody: template.text,
    status: 'pending',
    attempts: 0,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

async function processEmailQueue(db) {
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASS) {
    return { sent: 0, skipped: true };
  }
  const nodemailer = require('nodemailer');
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  const snapshot = await db.collection('email_logs')
    .where('status', 'in', ['pending', 'retry'])
    .limit(20)
    .get();
  let sent = 0;
  for (const doc of snapshot.docs) {
    const log = doc.data();
    try {
      await transporter.sendMail({
        from: process.env.SMTP_FROM || process.env.SMTP_USER,
        to: log.toEmail,
        subject: log.subject,
        text: log.textBody,
        html: log.htmlBody,
      });
      await doc.ref.update({
        status: 'sent',
        sentAt: Timestamp.now(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      sent++;
    } catch (error) {
      await doc.ref.update({
        status: 'retry',
        attempts: (log.attempts ?? 0) + 1,
        lastError: String(error.message ?? error).slice(0, 500),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }
  return { sent };
}

module.exports = { enqueueEmail, processEmailQueue, renderTemplate };
