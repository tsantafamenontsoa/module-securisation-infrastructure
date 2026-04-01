# 🏗️ GUIDE FIL ROUGE — Infrastructure LogiStock

**Sécurisation de l'Infrastructure**  


---

## 📚 Table des matières

1. [Introduction](#introduction)
2. [Prérequis Docker](#prérequis)
3. [Vue d'ensemble du fil rouge](#vue-densemble)
4. [S1 — Infrastructure vulnérable initiale](#s1)
5. [S2 — Ajout du chiffrement](#s2)
6. [S3 — Architecture DMZ sécurisée](#s3)
7. [S4 — Audit de l'infrastructure](#s4)
8. [S5 — Red Team vs Blue Team](#s5)
9. [Commandes essentielles](#commandes)
10. [Troubleshooting](#troubleshooting)

---

## Introduction

Ce guide vous accompagne tout au long du semestre pour **construire et sécuriser** l'infrastructure de l'entreprise LogiStock.

### Principe pédagogique

Au lieu de simplement étudier la théorie de la sécurité, vous allez :
1. **Déployer** une infrastructure vulnérable (S1)
2. **Constater** les failles par vous-mêmes
3. **Corriger** progressivement les problèmes (S2, S3)
4. **Auditer** votre propre architecture (S4)
5. **Attaquer et défendre** en mode Red Team / Blue Team (S5)

### Pourquoi Docker ?

- ✅ **Reproductibilité** : Même environnement pour tous
- ✅ **Isolation** : Chaque service dans son conteneur
- ✅ **Réalisme** : Architecture proche de la production
- ✅ **Réversibilité** : Reset facile en cas d'erreur
- ✅ **Employabilité** : Docker = compétence très demandée

---

## 🔧 Prérequis Docker

### Installation

#### Option A : Play with Docker (RECOMMANDÉ pour S1-S3)
- ✅ Aucune installation requise
- ✅ Fonctionne dans le navigateur
- ✅ URL : https://labs.play-with-docker.com
- ✅ Créer un compte Docker Hub gratuit

**Avantages** : Fonctionne sur n'importe quel ordinateur (même Mac/Windows/Chromebook)

**Limites** : Session de 4h maximum (suffisant pour un TP)

#### Option B : Installation locale (pour S4-S5)
- **Windows** : Docker Desktop (https://www.docker.com/products/docker-desktop)
- **Mac** : Docker Desktop
- **Linux** : `sudo apt install docker.io docker-compose`

### Vérification de l'installation

```bash
# Vérifier que Docker fonctionne
docker --version
# Devrait afficher : Docker version 24.x.x

# Vérifier docker-compose
docker-compose --version
# Devrait afficher : docker-compose version 1.29.x ou 2.x.x

# Tester avec un conteneur de test
docker run hello-world
# Devrait afficher : "Hello from Docker!"
```

### Concepts de base (5 min de lecture)

#### Conteneur vs Image
- **Image** = modèle (comme un ISO de Windows)
- **Conteneur** = instance en cours d'exécution (comme une VM lancée)

#### Réseau Docker
- **Bridge** = réseau virtuel entre conteneurs
- **Isolation** = les conteneurs ne se voient pas sauf si explicitement reliés

#### Volumes
- **Volume** = stockage persistant (survit au redémarrage du conteneur)
- Sans volume, les données sont perdues à chaque `docker-compose down`

---

## 🗺️ Vue d'ensemble du fil rouge

### Évolution de l'infrastructure LogiStock

```
S1 : ┌────────────────────────────────────┐
     │  TOUT SUR UN SEUL RÉSEAU PLAT      │
     │  ⚠️ Vulnérable                     │
     │                                     │
     │  [Web] ←→ [BDD] ←→ [NAS]           │
     │   Tous interconnectés              │
     └────────────────────────────────────┘

S2 : ┌────────────────────────────────────┐
     │  + CHIFFREMENT TLS                 │
     │  + HASHS SHA-256                   │
     │                                     │
     │  [Proxy HTTPS] → [Web] → [BDD]     │
     │  ⚠️ Toujours pas de segmentation   │
     └────────────────────────────────────┘

S3 : ┌─────────────────────────────────────────────┐
     │  ARCHITECTURE SÉCURISÉE                      │
     │                                               │
     │  Internet → [DMZ] → [Firewall] → [Internal]  │
     │             └─ Web               └─ BDD       │
     │             └─ Proxy             └─ NAS       │
     │                                   └─ SIEM     │
     │             [IDS]                             │
     │                                               │
     │             [Admin: Bastion]                  │
     └─────────────────────────────────────────────┘

S4 : Pas de modification Docker
     → Audit de l'architecture S3 avec grille ISO 27001

S5 : ┌─────────────────────────────────────────────┐
     │  S3 + RED TEAM / BLUE TEAM                   │
     │                                               │
     │  [Attacker Kali] ──────→ [DMZ]               │
     │                          └─ [WAF]             │
     │                          └─ [DVWA]            │
     │                          └─ [Honeypot]        │
     │                                               │
     │  [Internal]                                   │
     │  └─ [Prometheus] + [Grafana]                  │
     └─────────────────────────────────────────────┘
```

### Tableau récapitulatif

| Séance | Conteneurs | Réseaux | Nouveauté principale |
|--------|-----------|---------|---------------------|
| **S1** | 3 | 1 | Infrastructure vulnérable de base |
| **S2** | 4 | 1 | Chiffrement TLS + hashs BDD |
| **S3** | 8 | 3 | DMZ + Pare-feu + IDS + Bastion |
| **S4** | 8 | 3 | Identique S3 (audit uniquement) |
| **S5** | 14 | 3 | Attaquant + WAF + Monitoring |

---

## 🔴 S1 — Infrastructure vulnérable initiale

### Objectif pédagogique
Comprendre **pourquoi** la sécurité est nécessaire en voyant concrètement les failles.

### Architecture déployée

```
┌─────────────────────────────────┐
│  Réseau flat_network            │
│                                  │
│  ┌────┐   ┌────┐   ┌────┐      │
│  │Web │ ←→│ DB │ ←→│NAS │      │
│  └────┘   └────┘   └────┘      │
│   :80      :3306    (Alpine)    │
└─────────────────────────────────┘
         ↑
    Port 3306 EXPOSÉ sur Internet ⚠️
```

### Déploiement

```bash
# 1. Créer le dossier de travail
mkdir -p logistock-s1
cd logistock-s1

# 2. Créer des fichiers de paie factices
mkdir -p fiches_paie_sample
echo "Alice Dupont - Salaire 3500€" > fiches_paie_sample/alice.txt
echo "Bob Martin - Salaire 3200€" > fiches_paie_sample/bob.txt

# 3. Télécharger les fichiers Docker
# (fournis par la formatrice ou disponibles sur le dépôt Git)
# - docker-compose-s1-vulnerable.yml
# - s1-init.sql

# 4. Déployer la stack
docker-compose -f docker-compose-s1-vulnerable.yml up -d

# 5. Vérifier que tout tourne
docker ps
# Devrait afficher 3 conteneurs : logistock_web, logistock_db, logistock_nas
```

### TP S1 — Identification des failles (30 min)

#### Exercice 1 : Mots de passe en clair

```bash
# Se connecter à la base de données
docker exec -it logistock_db mysql -u root -pLogiStock2023 logistock

# Dans le prompt MySQL, taper :
SELECT username, password, email FROM users;

# 📝 Observation : Les mots de passe sont visibles EN CLAIR
# ❓ Question : Quelle est la conséquence si un attaquant vole la BDD ?
```

**Réponse attendue** : L'attaquant obtient tous les mots de passe immédiatement. Les utilisateurs qui réutilisent le même mot de passe sur d'autres sites (Gmail, LinkedIn) sont compromis.

#### Exercice 2 : Port MySQL exposé

```bash
# Scanner les ports depuis votre machine hôte
nmap -p 3306 localhost

# 📝 Observation : Le port 3306 est OUVERT
# ❓ Question : Que peut faire un attaquant qui trouve ce port ?
```

**Réponse attendue** : Brute force du mot de passe root MySQL depuis Internet. Avec "LogiStock2023" (mot de passe faible), c'est craqué en quelques minutes.

#### Exercice 3 : Réseau plat (pas d'isolation)

```bash
# Depuis le conteneur web, essayer d'accéder au NAS
docker exec logistock_web ping logistock_nas

# 📝 Observation : Ça marche (le web peut ping le NAS)
# ❓ Question : Quelle est la conséquence ?
```

**Réponse attendue** : Si le serveur web est compromis (injection SQL, XSS), l'attaquant peut pivoter directement vers le NAS RH qui contient les fiches de paie.

#### Exercice 4 : HTTP non chiffré

```bash
# Capturer le trafic réseau
docker exec logistock_web apt-get update && apt-get install -y tcpdump
docker exec logistock_web tcpdump -i any -A port 80

# Dans un autre terminal, faire une requête
curl http://localhost/login.php

# 📝 Observation : Les données transitent EN CLAIR
# ❓ Question : Que voit quelqu'un qui écoute le réseau WiFi ?
```

**Réponse attendue** : Tous les mots de passe tapés dans les formulaires web sont visibles. Un attaquant sur le même WiFi (café, aéroport) peut les capturer avec Wireshark.

#### Exercice 5 : Pas de logs

```bash
# Vérifier les logs d'accès
docker exec logistock_db mysql -u root -pLogiStock2023 logistock -e "SELECT * FROM logs_acces;"

# 📝 Observation : Très peu de logs, pas de détail
# ❓ Question : Comment détecter une intrusion sans logs ?
```

**Réponse attendue** : Impossible. LogiStock a découvert l'incident du ransomware par hasard (un employé a vu l'écran de rançon). Sans logs, pas de détection précoce.

### Livrables S1

À rendre dans le cahier TP :
1. **Tableau des 5 failles identifiées** avec gravité (faible/moyen/critique) et justification
2. **Capture d'écran** : résultat de `SELECT * FROM users;` montrant les mots de passe en clair
3. **Schéma** de l'architecture actuelle (dessiné à la main ou avec draw.io)

---

## 🔒 S2 — Ajout du chiffrement

### Objectif pédagogique
Comprendre et mettre en œuvre le **chiffrement des données en transit et au repos**.

### Architecture déployée

```
┌────────────────────────────────────┐
│  Réseau app_network                │
│                                     │
│  ┌──────┐   ┌────┐   ┌────┐       │
│  │Proxy │→│ Web │→│ DB │       │
│  │HTTPS │   └────┘   └────┘       │
│  └──────┘      ↓                   │
│   :443      [NAS]                  │
└────────────────────────────────────┘
         ↑
    TLS 1.2/1.3 chiffré ✅
    Mots de passe hashés SHA-256 ✅
```

### Nouveautés par rapport à S1

| Aspect | S1 | S2 |
|--------|----|----|
| **Transport** | HTTP (clair) | HTTPS avec TLS |
| **Mots de passe** | Stockage clair | Hashés SHA-256 |
| **Port MySQL** | Exposé (:3306) | Fermé (réseau interne) |
| **Complexité MDP** | Faibles | Forts (12+ caractères) |

### Déploiement

```bash
# 1. Créer le dossier S2
mkdir -p logistock-s2
cd logistock-s2

# 2. Générer les certificats TLS
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/logistock.key \
  -out certs/logistock.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=LogiStock/CN=logistock.local"

# 3. Télécharger les fichiers Docker
# - docker-compose-s2-crypto.yml
# - s2-init-hashed.sql
# - s2-nginx-proxy.conf

# 4. Déployer
docker-compose -f docker-compose-s2-crypto.yml up -d

# 5. Vérifier
docker ps
# Devrait afficher 4 conteneurs
```

### TP S2 — Manipulation du chiffrement (1h)

#### Exercice 1 : Tester HTTPS

```bash
# Accéder au site en HTTPS
curl -k https://localhost
# -k pour ignorer le certificat auto-signé

# Vérifier les détails du certificat
openssl s_client -connect localhost:443 -showcerts

# 📝 Observer : protocole TLS, suite de chiffrement utilisée
# ❓ Question : Pourquoi TLS 1.2 minimum (pas TLS 1.0) ?
```

**Réponse attendue** : TLS 1.0 et 1.1 sont vulnérables (attaques BEAST, POODLE). TLS 1.2 minimum est la recommandation ANSSI.

#### Exercice 2 : Vérifier les hashs en BDD

```bash
# Se connecter à la BDD
docker exec -it logistock_db mysql -u root -pSuperSecurePassword2024! logistock

# Afficher les hashs
SELECT username, password_hash FROM users;

# 📝 Observer : 64 caractères hexadécimaux (SHA-256)
# ❓ Question : Peut-on retrouver le mot de passe original depuis le hash ?
```

**Réponse attendue** : Non, le hachage est une fonction à sens unique. Impossible de "déchiffrer" un hash. L'attaquant doit tester tous les mots de passe possibles (brute force).

#### Exercice 3 : Tester la solidité d'un hash

```bash
# Générer le hash d'un mot de passe faible
docker exec logistock_db mysql -u root -pSuperSecurePassword2024! -e "SELECT SHA2('123456', 256);"

# Générer le hash d'un mot de passe fort
docker exec logistock_db mysql -u root -pSuperSecurePassword2024! -e "SELECT SHA2('LogiStock2024!Secure', 256);"

# 📝 Observer : Les deux hashs ont la même longueur (64 caractères)
# ❓ Question : Lequel se fait craquer plus vite par brute force ?
```

**Réponse attendue** : "123456" est dans tous les dictionnaires (craqué en <1 seconde). "LogiStock2024!Secure" prendrait des années même avec des GPUs puissants.

#### Exercice 4 : Comparer S1 vs S2

```bash
# Afficher la différence de sécurité
echo "=== S1 : Mots de passe EN CLAIR ===" 
echo "alice : LogiStock2023"
echo ""
echo "=== S2 : Mots de passe HASHÉS ===" 
echo "alice : 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
echo ""
echo "Impossible de retrouver 'LogiStock2023' depuis le hash"
```

### Livrables S2

1. **Capture d'écran** : `openssl s_client -connect localhost:443` montrant la négociation TLS
2. **Tableau comparatif** : S1 vs S2 (au moins 5 différences)
3. **Test de hash** : calculer SHA-256 de 3 mots de passe différents et expliquer la différence de sécurité

---

## 🏰 S3 — Architecture DMZ sécurisée

### Objectif pédagogique
Construire une **architecture en profondeur** avec zones isolées et contrôle des flux.

### Architecture déployée

```
┌─────────────────────────────────────────────────┐
│ 🌐 INTERNET                                      │
│                                                   │
│   ↓ :443 HTTPS                                   │
│                                                   │
│ ┌─────────────────────────────────────────┐    │
│ │ DMZ (10.1.0.0/24)                       │    │
│ │                                          │    │
│ │  [Proxy]  [Web]  [IDS Snort]            │    │
│ │   :443     :80     (passif)             │    │
│ └─────────────────────────────────────────┘    │
│                ↓                                 │
│          [FIREWALL]                              │
│        iptables rules                            │
│                ↓                                 │
│ ┌─────────────────────────────────────────┐    │
│ │ INTERNAL (10.2.0.0/24)                  │    │
│ │  🔒 Pas d'accès direct à Internet       │    │
│ │                                          │    │
│ │  [DB]  [NAS RH]  [SIEM]                 │    │
│ │ :3306   (isolé)   :3100                 │    │
│ └─────────────────────────────────────────┘    │
│                                                  │
│ ┌─────────────────────────────────────────┐    │
│ │ ADMIN (10.3.0.0/24)                     │    │
│ │                                          │    │
│ │  [Bastion SSH]                           │    │
│ │    :2222                                 │    │
│ └─────────────────────────────────────────┘    │
└──────────────────────────────────────────────────┘
```

### Principes de segmentation

1. **DMZ** : Zone exposée à Internet
   - ✅ Contient UNIQUEMENT les services publics (web, proxy)
   - ✅ Compromission de la DMZ ≠ accès au réseau interne

2. **Internal** : Zone protégée
   - ✅ Pas d'accès direct à Internet
   - ✅ Contient les données sensibles (BDD, NAS RH)
   - ✅ Accessible uniquement via le pare-feu

3. **Admin** : Zone d'administration
   - ✅ Bastion host = unique point d'entrée SSH
   - ✅ Tous les accès admin sont tracés

### Déploiement

```bash
# 1. Créer le dossier S3
mkdir -p logistock-s3
cd logistock-s3

# 2. Copier tous les fichiers de S2 (certs, app, fiches_paie)
cp -r ../logistock-s2/certs .
cp -r ../logistock-s2/fiches_paie_sample .

# 3. Télécharger docker-compose-s3-dmz.yml

# 4. Déployer
docker-compose -f docker-compose-s3-dmz.yml up -d

# 5. Vérifier les réseaux
docker network ls | grep logistock
# Devrait afficher : logistock_dmz, logistock_internal, logistock_admin
```

### TP S3 — Test de l'isolation (2h)

#### Exercice 1 : Vérifier la segmentation réseau

```bash
# Test 1 : Le web peut-il accéder à la BDD ?
docker exec logistock_web ping -c 2 10.2.0.30
# ✅ Devrait MARCHER (via le firewall)

# Test 2 : Le web peut-il accéder au NAS RH ?
docker exec logistock_web ping -c 2 10.2.0.40
# ❌ Devrait ÉCHOUER (règle firewall bloque)

# Test 3 : La BDD a-t-elle accès à Internet ?
docker exec logistock_db ping -c 2 8.8.8.8
# ❌ Devrait ÉCHOUER (réseau internal = internal:true)

# 📝 Conclusion : Isolation réussie !
```

#### Exercice 2 : Consulter les règles du pare-feu

```bash
# Afficher les règles iptables
docker exec logistock_firewall iptables -L -n -v

# 📝 Observer :
# - Politique par défaut : DROP (tout bloqué)
# - Règles ACCEPT : uniquement web→db:3306
# - Règles DROP : web→nas

# ❓ Question : Que se passe-t-il si le serveur web est compromis ?
```

**Réponse attendue** : L'attaquant peut accéder à la BDD (nécessaire pour le fonctionnement), mais PAS au NAS RH. Les fiches de paie sont protégées même en cas de compromission du web.

#### Exercice 3 : Utiliser le bastion host

```bash
# Se connecter au bastion via SSH
ssh -p 2222 root@localhost
# Mot de passe : BastionSecure2024!

# Une fois dans le bastion, accéder à la BDD
mysql -h 10.2.0.30 -u root -pSuperSecurePassword2024! logistock

# 📝 Observer : Le bastion est le SEUL moyen d'accéder au réseau internal depuis l'extérieur
# ❓ Question : Pourquoi passer par un bastion plutôt que SSH direct sur chaque serveur ?
```

**Réponse attendue** : 
- **Centralisation** : Tous les accès admin passent par un point unique
- **Traçabilité** : Les logs du bastion enregistrent qui a accédé à quoi
- **Réduction de surface d'attaque** : Un seul service SSH exposé au lieu de 5-6

#### Exercice 4 : Consulter les logs IDS

```bash
# Voir les alertes Snort
docker exec logistock_ids tail -f /var/log/snort/alert

# Dans un autre terminal, générer du trafic suspect
nmap -sS -p 1-1000 localhost

# 📝 Observer : L'IDS détecte le scan de ports
# ❓ Question : Quelle est la différence entre IDS et IPS ?
```

**Réponse attendue** : 
- **IDS** (Intrusion Detection) : Détecte et alerte, mais ne bloque pas
- **IPS** (Intrusion Prevention) : Détecte ET bloque en temps réel
- LogiStock utilise un IDS (mode passif) pour éviter les faux positifs qui bloqueraient du trafic légitime

### Livrables S3

1. **Schéma complet** de l'architecture avec les 3 zones (DMZ/Internal/Admin)
2. **Tableau des règles pare-feu** : source → destination → port → action (ACCEPT/DROP)
3. **Capture de logs IDS** : copier 5 alertes générées par vos tests

---

## 📋 S4 — Audit de l'infrastructure

### Objectif pédagogique
Évaluer l'infrastructure S3 selon les **contrôles ISO 27001**.

**Note importante** : Pas de modification Docker en S4. On audite ce qui existe.

### Grille d'audit ISO 27001

Remplir cette grille en analysant votre stack S3 :

| Contrôle ISO | Description | Implémenté ? | Preuve technique | Score /5 |
|-------------|-------------|--------------|------------------|----------|
| A.9.1.2 | Accès aux réseaux et aux services réseau | ✅ OUI | DMZ isolée du réseau internal | 5 |
| A.10.1.1 | Politique d'utilisation des mesures de chiffrement | ✅ OUI | TLS + hashs SHA-256 | 4 |
| A.12.4.1 | Enregistrement des événements | ⚠️ PARTIEL | IDS logs, mais pas centralisés | 3 |
| A.13.1.1 | Contrôles réseaux | ✅ OUI | Pare-feu iptables + segmentation | 5 |
| A.14.2.5 | Tests de sécurité des systèmes | ❌ NON | Pas de scan automatique régulier | 1 |
| A.18.2.3 | Conformité technique | ⚠️ PARTIEL | Architecture sécurisée, mais pas de doc formelle | 2 |

### TP S4 — Audit pratique (1h)

#### Exercice 1 : Vérifier les contrôles d'accès (A.9.1.2)

```bash
# Test 1 : Un conteneur de la DMZ peut-il joindre le réseau internal ?
docker run --network logistock_dmz alpine ping -c 2 10.2.0.30
# ❌ Devrait échouer (pas de route)

# Test 2 : Le bastion peut-il joindre le réseau internal ?
docker exec logistock_bastion ping -c 2 10.2.0.30
# ✅ Devrait marcher (connecté aux deux réseaux)

# 📝 Conclusion : Contrôle d'accès réseau fonctionnel
# Score : 5/5
```

#### Exercice 2 : Vérifier le chiffrement (A.10.1.1)

```bash
# Test 1 : HTTPS actif ?
curl -k https://localhost -I | grep "HTTP"
# ✅ Devrait afficher "HTTP/1.1 200" ou "HTTP/2"

# Test 2 : Hashs en BDD ?
docker exec logistock_db mysql -u root -pSuperSecurePassword2024! -e "DESCRIBE logistock.users;" | grep password
# ✅ Devrait afficher "password_hash CHAR(64)"

# 📝 Conclusion : Chiffrement implémenté
# Mais : SHA-256 simple (pas de sel) = amélioration possible (bcrypt/Argon2)
# Score : 4/5
```

#### Exercice 3 : Vérifier les logs (A.12.4.1)

```bash
# Test 1 : Logs IDS présents ?
docker exec logistock_ids ls -lh /var/log/snort/
# ✅ Fichiers alert, snort.log présents

# Test 2 : Logs pare-feu ?
docker exec logistock_firewall dmesg | grep "FW BLOCK" | wc -l
# ✅ Affiche le nombre de paquets bloqués

# Test 3 : Centralisation des logs ?
docker exec logistock_siem curl localhost:3100/ready
# ⚠️ Loki tourne, mais pas de collecte automatique

# 📝 Conclusion : Logs présents mais pas centralisés ni analysés automatiquement
# Score : 3/5
```

### Livrables S4

1. **Grille d'audit complétée** (minimum 10 contrôles ISO 27001)
2. **Rapport d'amélioration** : liste de 5 mesures à implémenter pour atteindre la conformité totale
3. **Schéma de gouvernance** : qui est responsable de quoi dans l'organisation LogiStock ?

---

## ⚔️ S5 — Red Team vs Blue Team

### Objectif pédagogique
Mettre en pratique **l'ensemble du semestre** dans un exercice d'attaque et de défense.

### Architecture déployée (extension de S3)

```
┌──────────────────────────────────────────────┐
│ DMZ                                           │
│                                                │
│  [Attacker Kali] ──→ [WAF] ──→ [Web]         │
│       (Red Team)      ↓                       │
│                   [DVWA vulnerable]            │
│                   [Honeypot SSH trap]          │
│                                                │
└──────────────────────────────────────────────┘
                  ↓ Firewall
┌──────────────────────────────────────────────┐
│ Internal                                      │
│                                                │
│  [DB]  [NAS]  [SIEM]                          │
│  [Prometheus]  [Grafana]                       │
│       (Blue Team monitoring)                   │
└──────────────────────────────────────────────┘
```

### Déploiement

```bash
# 1. Copier tout de S3
cp -r ../logistock-s3/* ./logistock-s5/
cd logistock-s5

# 2. Déployer S5
docker-compose -f docker-compose-s5-redteam.yml up -d

# 3. Vérifier (14 conteneurs)
docker ps | wc -l
# Devrait afficher : 15 (14 conteneurs + header)
```

### TP S5 — Red Team vs Blue Team (2h)

**FORMAT** : 
- Groupe A = Red Team (attaque)
- Groupe B = Blue Team (défense)
- Inverser les rôles après 1h

#### Phase 1 : Red Team — Reconnaissance (15 min)

```bash
# Entrer dans le conteneur attaquant
docker exec -it logistock_attacker bash

# Scanner les cibles
nmap -sS -p 1-10000 10.1.0.0/24

# Identifier les services
nmap -sV 10.1.0.20  # Serveur web
nmap -sV 10.1.0.60  # DVWA

# 📝 Noter : ports ouverts, services, versions
```

#### Phase 2 : Red Team — Exploitation (20 min)

```bash
# Exploitation SQLi sur DVWA
sqlmap -u "http://10.1.0.60/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="PHPSESSID=xxx;security=low" \
  --dbs

# Brute force SSH sur honeypot
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://10.1.0.80:2223

# Scan vulnérabilités web
nikto -h http://10.1.0.20

# 📝 Documenter : quelles attaques ont réussi ?
```

#### Phase 3 : Blue Team — Détection (en parallèle)

```bash
# Surveiller les logs IDS
docker logs -f logistock_ids | grep "ALERT"

# Consulter le honeypot
docker exec logistock_honeypot cat /cowrie/var/log/cowrie/cowrie.json | jq

# Dashboard Grafana
# Ouvrir http://localhost:3000
# Login : admin / GrafanaSecure2024!

# 📝 Documenter : quelles attaques détectées ?
```

#### Phase 4 : Blue Team — Réponse à incident (15 min)

```bash
# Bloquer l'IP de l'attaquant
docker exec logistock_firewall iptables -A INPUT -s 10.1.0.100 -j DROP

# Isoler le serveur compromis (si DVWA exploité)
docker exec logistock_firewall iptables -A FORWARD -s 10.1.0.60 -j DROP

# Analyser les logs
docker exec logistock_siem curl localhost:3100/loki/api/v1/query?query='{job="firewall"}'

# 📝 Documenter : contre-mesures prises
```

### Debriefing S5 (30 min)

Questions pour la discussion collective :

1. **Attaques réussies** : Lesquelles ont fonctionné ? Pourquoi ?
2. **Détection** : À quel moment l'attaque a-t-elle été détectée ?
3. **Délai de réponse** : Combien de temps entre la détection et le blocage ?
4. **Améliorations** : Que manque-t-il encore dans l'architecture ?
5. **Réalisme** : Quelles différences entre ce lab et une vraie entreprise ?

### Livrables S5

1. **Rapport Red Team** : timeline des attaques, résultats, captures d'écran
2. **Rapport Blue Team** : logs de détection, contre-mesures appliquées
3. **Synthèse** : 3 leçons apprises (ce qui a marché / ce qui n'a pas marché)

---

## 🛠️ Commandes essentielles Docker

### Gestion des conteneurs

```bash
# Lister les conteneurs actifs
docker ps

# Lister TOUS les conteneurs (y compris arrêtés)
docker ps -a

# Arrêter un conteneur
docker stop logistock_web

# Démarrer un conteneur arrêté
docker start logistock_web

# Redémarrer un conteneur
docker restart logistock_web

# Supprimer un conteneur (doit être arrêté avant)
docker rm logistock_web

# Supprimer TOUS les conteneurs arrêtés
docker container prune
```

### Gestion de Docker Compose

```bash
# Démarrer la stack (crée les conteneurs)
docker-compose up -d

# Arrêter la stack (conteneurs arrêtés mais conservés)
docker-compose stop

# Supprimer la stack (conteneurs + réseaux supprimés)
docker-compose down

# Supprimer la stack + volumes (⚠️ PERTE DE DONNÉES)
docker-compose down -v

# Voir les logs en temps réel
docker-compose logs -f

# Voir les logs d'un service spécifique
docker-compose logs -f web

# Reconstruire les images (après modification du Dockerfile)
docker-compose build
```

### Accès aux conteneurs

```bash
# Ouvrir un shell dans un conteneur
docker exec -it logistock_web bash
# ou
docker exec -it logistock_web sh

# Exécuter une commande sans entrer dans le conteneur
docker exec logistock_db mysql -u root -p

# Copier un fichier depuis le conteneur vers l'hôte
docker cp logistock_web:/var/log/apache2/access.log ./logs/

# Copier un fichier de l'hôte vers le conteneur
docker cp ./config.php logistock_web:/var/www/html/
```

### Gestion des réseaux

```bash
# Lister les réseaux
docker network ls

# Inspecter un réseau (voir les conteneurs connectés)
docker network inspect logistock_dmz

# Créer un réseau manuellement
docker network create mon_reseau

# Connecter un conteneur à un réseau
docker network connect logistock_internal logistock_web

# Déconnecter un conteneur d'un réseau
docker network disconnect logistock_dmz logistock_web
```

### Gestion des volumes

```bash
# Lister les volumes
docker volume ls

# Inspecter un volume
docker volume inspect logistock_db_data

# Supprimer un volume (⚠️ perte de données)
docker volume rm logistock_db_data

# Supprimer TOUS les volumes non utilisés
docker volume prune
```

### Diagnostic et logs

```bash
# Voir les stats de consommation (CPU, RAM)
docker stats

# Voir les processus dans un conteneur
docker top logistock_web

# Inspecter un conteneur (config complète)
docker inspect logistock_web

# Voir les logs depuis un moment précis
docker logs --since 30m logistock_web

# Filtrer les logs
docker logs logistock_web 2>&1 | grep "ERROR"
```

---

## 🔧 Troubleshooting

### Problème : "Cannot connect to Docker daemon"

**Cause** : Docker n'est pas démarré ou vous n'avez pas les permissions.

**Solution** :
```bash
# Linux
sudo systemctl start docker
sudo usermod -aG docker $USER
# Déconnexion/reconnexion nécessaire

# Windows/Mac Docker Desktop
# Lancer Docker Desktop manuellement
```

---

### Problème : "Port already in use"

**Cause** : Un autre service utilise déjà le port (ex: :80, :443).

**Solution** :
```bash
# Trouver quel processus utilise le port
sudo lsof -i :80
# ou
sudo netstat -tulpn | grep :80

# Arrêter le processus ou changer le port dans docker-compose.yml
ports:
  - "8080:80"  # Au lieu de "80:80"
```

---

### Problème : Conteneur qui redémarre en boucle

**Cause** : Erreur dans la commande du conteneur ou fichier manquant.

**Solution** :
```bash
# Voir les logs
docker logs logistock_web

# Regarder les dernières lignes avant le crash
docker logs --tail 50 logistock_web

# Si besoin, désactiver le restart
docker update --restart=no logistock_web
```

---

### Problème : "No space left on device"

**Cause** : Docker a consommé tout l'espace disque (images, conteneurs, volumes).

**Solution** :
```bash
# Voir l'utilisation du disque
docker system df

# Nettoyer tout ce qui n'est pas utilisé
docker system prune -a --volumes

# ⚠️ ATTENTION : supprime TOUT sauf les conteneurs actifs
```

---

### Problème : Réseau qui ne fonctionne pas

**Cause** : Conflit d'adresses IP ou problème de routage.

**Solution** :
```bash
# Recréer les réseaux
docker-compose down
docker network prune
docker-compose up -d

# Vérifier les routes
docker exec logistock_web ip route

# Tester la connectivité
docker exec logistock_web ping -c 2 10.2.0.30
```

---

### Problème : Volumes qui ne se montent pas

**Cause** : Chemin incorrect ou permissions.

**Solution** :
```bash
# Vérifier le chemin absolu
pwd
# Utiliser un chemin absolu dans docker-compose.yml
volumes:
  - /home/user/logistock/data:/data

# Vérifier les permissions
ls -la ./data
chmod 755 ./data
```

---

### Problème : Modifications non prises en compte

**Cause** : Docker utilise une version en cache.

**Solution** :
```bash
# Forcer la reconstruction
docker-compose build --no-cache
docker-compose up -d --force-recreate
```

---

## 📚 Ressources supplémentaires

### Documentation officielle
- Docker : https://docs.docker.com
- Docker Compose : https://docs.docker.com/compose/
- Play with Docker : https://labs.play-with-docker.com

### Tutoriels recommandés
- Docker pour débutants : https://www.youtube.com/watch?v=3c-iBn73dDE
- Networking Docker : https://docs.docker.com/network/

### Outils utiles
- Portainer (interface graphique Docker) : https://www.portainer.io
- Docker Hub (images) : https://hub.docker.com
- Dive (analyser les images) : https://github.com/wagoodman/dive

---

## ✅ Checklist de fin de semestre

Avant de rendre votre projet final, vérifiez :

- [ ] Tous les docker-compose.yml sont commentés et documentés
- [ ] Les 5 livrables (S1 à S5) sont dans le cahier TP
- [ ] Les schémas d'architecture sont clairs et légendés
- [ ] Les captures d'écran montrent bien les résultats attendus
- [ ] Le rapport de synthèse S5 est complet (3-5 pages)
- [ ] Tous les fichiers Docker sont dans un dépôt Git
- [ ] Le README.md explique comment déployer chaque séance

---

**Bon courage et amusez-vous bien ! 🚀**

*Ce guide sera votre compagnon tout au long du semestre. N'hésitez pas à y revenir régulièrement.*
