const fs = require('fs');
const multer = require('multer');
const path = require('path');

const MAX_BYTES = 5 * 1024 * 1024; // 5MB

const ALLOWED_MIMES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const ALLOWED_EXTS = ['.jpg', '.jpeg', '.png', '.webp'];

// Mimetype comes from the client and is trivially spoofed, so the
// extension is checked too. Neither is proof — the real defence is that
// uploads are renamed, so an attacker cannot predict the resulting URL.
const fileFilter = (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();

    if (ALLOWED_MIMES.includes(file.mimetype) || ALLOWED_EXTS.includes(ext)) {
        cb(null, true);
    } else {
        cb(new Error('Only JPEG, JPG, PNG and WEBP allowed'), false);
    }
};

/**
 * Builds an uploader writing into `uploads/<folder>`.
 *
 * Posts and avatars are kept apart so one can be cleared or backed up
 * without touching the other.
 */
const uploaderFor = (folder) => {
    const dir = path.join('uploads', folder);

    // multer will not create a missing directory — it throws ENOENT on the
    // first upload instead. recursive:true makes this a no-op if it exists.
    fs.mkdirSync(dir, { recursive: true });

    return multer({
        storage: multer.diskStorage({
            destination: (req, file, cb) => cb(null, dir),
            filename: (req, file, cb) => {
                const unique =
                    Date.now() + '-' + Math.round(Math.random() * 1e9);
                cb(null, unique + path.extname(file.originalname));
            }
        }),
        fileFilter,
        limits: { fileSize: MAX_BYTES }
    });
};

const upload = uploaderFor('posts');
const uploadAvatar = uploaderFor('avatars');

// `upload` stays the default export so existing routes keep working.
module.exports = upload;
module.exports.avatar = uploadAvatar;
