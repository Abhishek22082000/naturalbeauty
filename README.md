# NaturalBeauty

A social photo-sharing app — Node.js/Express REST API with a Flutter client.

```
naturalbeauty/
├── backend/          Node.js + Express + MySQL API
└── app/              Flutter client (not started yet)
```

---

## Backend

### Stack

| | |
|---|---|
| Runtime | Node.js (CommonJS) |
| Framework | Express 5 |
| Database | MySQL (mysql2, promise pool) |
| Auth | JWT (jsonwebtoken) + bcrypt |
| Uploads | multer, local disk storage |

### Setup

```bash
cd backend
npm install
cp .env.example .env    # then fill in real values
npm run dev
```

Runs on `http://localhost:3000`.

### Environment variables

See `backend/.env.example`. `.env` is gitignored and must never be committed.

| Variable | Purpose |
|---|---|
| `JWT_SECRET` | Signs and verifies auth tokens |
| `DB_HOST` `DB_USER` `DB_PASSWORD` `DB_NAME` | MySQL connection |

### Folder structure

```
backend/
├── app.js              Express app — middleware, route mounting, listener
├── config/
│   └── connection.js   MySQL connection pool
├── routes/             URL → controller mapping
├── controllers/        HTTP layer: reads req, calls DB, sends res
├── middlewares/
│   ├── auth.js         JWT verification, sets req.user
│   └── upload.js       multer config: storage, file filter, size limit
├── models/             (unused — controllers query directly for now)
├── services/           (unused — reserved for business logic)
└── uploads/posts/      Uploaded images (gitignored)
```

A request flows: `app.js` → `routes/` → `middlewares/` → `controllers/` → MySQL.

---

## API

Base URL: `http://localhost:3000`

Protected routes need `Authorization: Bearer <token>`.

### Auth

| Method | Endpoint | Auth | Body |
|---|---|---|---|
| POST | `/auth/signup` | — | JSON: `username`, `name`, `email`, `password`, `phone`, `gender` |
| POST | `/auth/login` | — | JSON: `email`, `password` → returns `token` |

### Posts

| Method | Endpoint | Auth | Body |
|---|---|---|---|
| POST | `/posts/create` | ✓ | form-data: `image` (file), `caption`, `location` |

### Likes

| Method | Endpoint | Auth | Body |
|---|---|---|---|
| POST | `/likes/:id/like` | ✓ | — |
| DELETE | `/likes/:id/unlike` | ✓ | — |

`:id` is the post id.

### Notes

- Post creation uses `multipart/form-data`, not JSON — the file cannot travel in a JSON body.
- `user_id` always comes from the verified token, never from the request body.
- Images are limited to 5MB, JPEG/PNG/WEBP only.

---

## Database schema

```sql
CREATE TABLE users (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username        VARCHAR(30)  NOT NULL UNIQUE,
  email           VARCHAR(191) NOT NULL UNIQUE,
  phone           VARCHAR(20)  UNIQUE,
  password        VARCHAR(255) NOT NULL,
  full_name       VARCHAR(100),
  bio             VARCHAR(150),
  website         VARCHAR(255),
  profile_picture VARCHAR(255),
  gender          ENUM('male','female','other','prefer_not_to_say'),
  date_of_birth   DATE,
  is_private      TINYINT(1) NOT NULL DEFAULT 0,
  is_verified     TINYINT(1) NOT NULL DEFAULT 0,
  is_active       TINYINT(1) NOT NULL DEFAULT 1,
  email_verified  TINYINT(1) NOT NULL DEFAULT 0,
  phone_verified  TINYINT(1) NOT NULL DEFAULT 0,
  last_login      DATETIME,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_username (username),
  INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE posts (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  image_url  VARCHAR(255) NOT NULL,
  caption    VARCHAR(2200),
  location   VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_created (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE likes (
  user_id    INT UNSIGNED NOT NULL,
  post_id    INT UNSIGNED NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, post_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  INDEX idx_post (post_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

The `likes` composite primary key `(user_id, post_id)` makes double-liking impossible at the database level — no application check needed.

---

## Roadmap

**Backend**
- [ ] `getPost`, `getUserPost`, `deletePost` (stubs exist)
- [ ] Serve uploads: `app.use('/uploads', express.static('uploads'))`
- [ ] Centralised error-handling middleware
- [ ] Split `app.js` / `server.js`
- [ ] Comments table + endpoints
- [ ] Follows table + endpoints
- [ ] Feed endpoint with pagination

**App**
- [ ] Flutter project scaffold
- [ ] Login / signup screens
- [ ] Feed, post creation, profile
