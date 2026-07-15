# Deploying the Stella backend to Railway

The backend (Django + a shared ConvNeXt leaf gate + 3 disease models) runs on a single
Railway service (~$5/mo, 1 GB RAM). The leaf gate remains cached; disease
models load **per request** and are freed after inference.

The Flutter app then just points at the Railway URL, and you distribute the APK
separately (GitHub Releases or a static page).

---

## 0. One-time: put the models in Git LFS

The 4 production model files are about 107 MB each — GitHub rejects normal files over 100 MB, so
they go through Git LFS. They stay **private** in your private repo.

```bash
# from the repo root
git lfs install
git lfs track "backend/ml/*.pth"
git add .gitattributes
git add backend/ml/convnext_tiny_binary_leaf_gate.pth \
        backend/ml/tomato_convnext_tiny_v1.pth \
        backend/ml/potato_convnext_plantdoc.pth \
        backend/ml/pepper_convnext_plantdoc.pth
git add backend/ .gitignore
git commit -m "Add Railway deploy config + LFS models"
git push
```

> Make sure the GitHub repo is **Private** (Settings → General → Danger Zone) so
> the models aren't public.

Free GitHub LFS = 1 GB storage + 1 GB/month bandwidth. These 4 files are ~425 MB,
and each Railway build downloads them once — fine for a few deploys a month.

---

## 1. Create the Railway project

1. Go to https://railway.app → **New Project** → **Deploy from GitHub repo**.
2. Pick your repo.
3. Open the service → **Settings** → set **Root Directory** to `backend`.
   (Railway will then find `requirements.txt`, `Procfile`, and `runtime.txt`.)

---

## 2. Add PostgreSQL

1. In the project, **New** → **Database** → **Add PostgreSQL**.
2. Railway auto-creates a `DATABASE_URL`. Wire it into the web service:
   - Web service → **Variables** → **New Variable** →
     `DATABASE_URL` = `${{ Postgres.DATABASE_URL }}` (reference the Postgres service).

`settings.py` already reads `DATABASE_URL` in production.

---

## 3. Add a volume for uploaded images

Scan photos are written to disk; without a volume they vanish on every redeploy.

1. Web service → **Settings** → **Volumes** → **New Volume**.
2. Mount path: `/data`.

---

## 4. Set environment variables

Web service → **Variables**:

| Variable      | Value                                    |
|---------------|------------------------------------------|
| `SECRET_KEY`  | `<paste a long random string>`           |
| `DEBUG`       | `False`                                  |
| `MEDIA_ROOT`  | `/data/media`                            |
| `DATABASE_URL`| `${{ Postgres.DATABASE_URL }}` (step 2)  |

A freshly generated key you can use:

```
SECRET_KEY = o7xmj#d(&nbg86j%)5+8h&-)nqfsmrgc#g(43f5jt=a!*a#6*!
```

(You don't need `MODELS_DIR` — the models ship inside `backend/ml/`.)

---

## 5. Deploy

Railway builds automatically on push. On boot the `Procfile` runs:

```
migrate  →  collectstatic  →  gunicorn (1 worker, 4 threads)
```

Watch **Deployments → Logs**. First build is slow (installing CPU torch + LFS
pull). When it's up, Railway gives you a URL like
`https://stella-production.up.railway.app`.

Test it:

```bash
curl https://<your-app>.up.railway.app/api/species/
```

(401/403 is fine — it means Django is running and auth is enforced.)

---

## 6. Point the Flutter app at it

In the frontend, replace the local API base URL (e.g. `http://10.0.2.2:8000`)
with your Railway URL, then rebuild the APK:

```bash
cd frontend
flutter build apk --release
```

The APK is at `build/app/outputs/flutter-apk/app-release.apk`. Upload it to a
**GitHub Release** (or any static host) and share the download link.

---

## Notes & gotchas

- **Cold starts**: on the free-ish tier the service sleeps when idle; the first
  request after a nap takes ~30–60 s. Hit it once before demoing.
- **First scan per species is slow** (~1–2 s) because the model loads on demand;
  repeats are fast until another species is scanned.
- **torch version**: `requirements.txt` pins CPU builds matching your training
  versions so checkpoints load. If Railway can't find those exact wheels, bump to
  the latest `+cpu` versions available at https://download.pytorch.org/whl/cpu —
  the state-dicts will still load.
- **RAM**: 1 worker is deliberate. More workers = more copies of torch/model in
  RAM and you'll OOM on a small box.
