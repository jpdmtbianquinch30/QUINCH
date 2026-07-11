# QUINCH — Démarrage rapide après redémarrage PC

## Ordre à respecter : Docker → Backend → Flutter

---

## 1. Docker (PostgreSQL)

Ouvre **PowerShell** et lance :

```powershell
cd C:\xampp\htdocs\QUINCH
docker compose up -d
```

Vérifie que tout est OK :
```powershell
docker compose ps
```
Tu dois voir `quinch_db` avec le statut `healthy`.

> Si Docker Desktop n'est pas lancé, ouvre-le d'abord depuis le menu Démarrer avant de taper les commandes.

---

## 2. Backend Laravel (VS Code)

Ouvre VS Code dans le dossier backend :
```powershell
cd C:\xampp\htdocs\QUINCH\backend
code .
```

Dans le terminal VS Code (`` Ctrl+` ``) :
```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

✅ Tu dois voir : `Server running on [http://0.0.0.0:8000]`

> **⚠️ Si erreur d'authentification PostgreSQL** (ça peut arriver après un redémarrage) :
> ```powershell
> docker exec -it quinch_db psql -U quinch_user -d quinch -c "SET password_encryption = 'md5'; ALTER USER quinch_user WITH PASSWORD 'Thiara3003.';"
> ```
> Puis relance `php artisan serve --host=0.0.0.0 --port=8000`

---

## 3. Flutter (Android Studio)

### Connecter le téléphone en WiFi

Ouvre un **nouveau terminal PowerShell** :

```powershell
adb connect 192.168.1.7:5555
```

Vérifie :
```powershell
flutter devices
```
Ton téléphone doit apparaître dans la liste.

> **⚠️ Si `cannot connect` ou `connection refused`** (arrive après redémarrage du téléphone) :
> Le débogage WiFi se désactive après redémarrage. Rebrancher le câble USB une fois suffit :
> 1. Branche le câble USB entre le téléphone et le PC
> 2. Accepte la popup "Autoriser le débogage USB" sur le téléphone
> 3. Tape dans PowerShell :
> ```powershell
 adb tcpip 5555
 adb connect 192.168.1.3:5555
> ```
> 4. Débranche le câble — la connexion WiFi prend le relais

> **⚠️ Si l'IP du PC a changé** (vérifie avec `ipconfig` → carte Wi-Fi) :
> - Mets à jour `flutter_app/lib/config/api_config.dart` ligne `_defaultRealIp`
> - Dans l'app sur le téléphone, tape l'icône ⚙️ en bas du login et change l'URL

> **💡 Pour fixer l'IP du téléphone définitivement** (évite que ça change à chaque redémarrage) :
> Paramètres WiFi → ton réseau → Modifier le réseau → Paramètres IP → **Statique** → IP : `192.168.1.7` → Enregistrer

### Lancer l'app Flutter

Dans Android Studio, ouvre le projet `flutter_app/`, puis dans le terminal intégré :

```powershell
cd C:\xampp\htdocs\QUINCH\flutter_app
flutter run -d 192.168.1.7:5555
```

Ou utilise le bouton ▶ dans Android Studio en sélectionnant ton téléphone comme device.

---

## Commandes Flutter utiles pendant le dev

| Commande | Action |
|----------|--------|
| `r` | Hot reload (rechargement rapide sans perdre l'état) |
| `R` | Hot restart (redémarre l'app complètement) |
| `q` | Quitter |
| `flutter devices` | Voir les appareils connectés |
| `adb connect 192.168.1.7:5555` | Reconnecter le téléphone en WiFi |

---

## Arrêter proprement en fin de session

```powershell
# Arrêter Docker (garde les données)
cd C:\xampp\htdocs\QUINCH
docker compose down

# Arrêter le serveur Laravel : Ctrl+C dans le terminal VS Code
# Arrêter Flutter : q dans le terminal Flutter
```

---

## Résumé des infos importantes

| Info | Valeur |
|------|--------|
| IP du PC (WiFi) | `192.168.1.4` (peut changer — vérifie avec `ipconfig`) |
| IP du téléphone | `192.168.1.7` (peut changer — vérifie dans Paramètres WiFi) |
| Port backend | `8000` |
| URL backend (téléphone) | `http://192.168.1.4:8000` |
| DB PostgreSQL | `quinch` / `quinch_user` / `Thiara3003.` |
| Compte admin | `+221770000001` / `password` |
| Compte test | `+221770000010` / `password` |
| pgAdmin | `http://localhost:5050` — `admin@quinch.sn` / `quinch_secret` |

---

## Si la connexion téléphone échoue

1. Vérifie que téléphone et PC sont sur le **même WiFi**
2. Vérifie l'IP du PC : `ipconfig` → carte Wi-Fi
3. Reconnecte ADB : `adb connect 192.168.1.7:5555`
4. Pare-feu désactivé ? `netsh advfirewall set allprofiles state off`