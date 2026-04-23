const fs = require('fs').promises;

// Magic-byte signatures for file types we legitimately accept.
// Content-Type from the client is attacker-controlled; we read the
// first bytes of the saved file and verify them against known headers.
//
// mp4/mov/3gp all share the ISO-BMFF `ftyp` atom at offset 4, so the
// check looks at bytes 4..8 rather than 0..4 for those.

const IMAGE_SIGNATURES = [
  { offset: 0, bytes: [0xff, 0xd8, 0xff] },              // JPEG
  { offset: 0, bytes: [0x89, 0x50, 0x4e, 0x47] },        // PNG
  { offset: 0, bytes: [0x47, 0x49, 0x46, 0x38] },        // GIF87a/GIF89a
  { offset: 0, bytes: [0x52, 0x49, 0x46, 0x46], suffix: { offset: 8, bytes: [0x57, 0x45, 0x42, 0x50] } }, // WEBP
];

const VIDEO_SIGNATURES = [
  { offset: 4, bytes: [0x66, 0x74, 0x79, 0x70] },        // MP4 / MOV / 3GP (ftyp)
  { offset: 0, bytes: [0x1a, 0x45, 0xdf, 0xa3] },        // Matroska / WebM (EBML)
  { offset: 0, bytes: [0x52, 0x49, 0x46, 0x46], suffix: { offset: 8, bytes: [0x41, 0x56, 0x49, 0x20] } }, // AVI
];

function matches(buf, sig) {
  for (let i = 0; i < sig.bytes.length; i++) {
    if (buf[sig.offset + i] !== sig.bytes[i]) return false;
  }
  if (sig.suffix) {
    for (let i = 0; i < sig.suffix.bytes.length; i++) {
      if (buf[sig.suffix.offset + i] !== sig.suffix.bytes[i]) return false;
    }
  }
  return true;
}

async function verifyFile(filePath, signatures) {
  const fh = await fs.open(filePath, 'r');
  try {
    const buf = Buffer.alloc(16);
    await fh.read(buf, 0, 16, 0);
    return signatures.some((sig) => matches(buf, sig));
  } finally {
    await fh.close();
  }
}

async function cleanup(file) {
  if (!file?.path) return;
  try { await fs.unlink(file.path); } catch (_) { /* already gone */ }
}

function verifyMagicBytes({ videos = false, images = false } = {}) {
  const signatures = [
    ...(videos ? VIDEO_SIGNATURES : []),
    ...(images ? IMAGE_SIGNATURES : []),
  ];

  return async (req, res, next) => {
    const files = [];
    if (req.file) files.push(req.file);
    if (req.files) {
      if (Array.isArray(req.files)) files.push(...req.files);
      else for (const k of Object.keys(req.files)) files.push(...req.files[k]);
    }
    if (files.length === 0) return next();

    try {
      for (const f of files) {
        const ok = await verifyFile(f.path, signatures);
        if (!ok) {
          await Promise.all(files.map(cleanup));
          return res.status(415).json({
            status: 'error',
            message: 'File contents do not match a supported media type.',
          });
        }
      }
      next();
    } catch (err) {
      await Promise.all(files.map(cleanup));
      return res.status(400).json({
        status: 'error',
        message: 'Failed to verify uploaded file.',
      });
    }
  };
}

module.exports = { verifyMagicBytes };
