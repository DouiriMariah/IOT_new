# Inception-of-Things (IoT)

Projet système : mise en place de plusieurs infrastructures Kubernetes
via **Vagrant**, **K3s** et **K3d + Argo CD**.

Login utilisé : **amattei**

```
.
├── p1/      Vagrant + K3s (2 VMs : serveur + agent)
├── p2/      Vagrant + K3s (1 VM) + 3 applications derrière un Ingress
└── p3/      K3d + Argo CD (GitOps)
```

## Prérequis (sur la machine hôte / VM d'évaluation)

- [Vagrant](https://www.vagrantup.com/) (>= 2.3)
- Provider Vagrant : **libvirt/QEMU** (plugin `vagrant-libvirt`), utilisé
  en émulation logicielle pure (`driver = "qemu"`) plutôt que VirtualBox
  — voir [HOST-SETUP.md](HOST-SETUP.md) pour l'installation complète et
  le pourquoi de ce choix. `vagrant up` fonctionne tel quel une fois le
  provider installé, sans argument `--provider` à passer.
- Pour la partie 3 uniquement : `p3/scripts/install.sh` installe lui-même
  Docker, kubectl, K3d et le CLI Argo CD (voir plus bas).

---

## Partie 1 — K3s + Vagrant (2 VMs)

```bash
cd p1
vagrant up
```

Deux VMs Debian 12 sont créées :

| Nom        | IP              | Rôle              |
|------------|------------------|-------------------|
| amatteiS   | 192.168.56.110   | K3s server (control-plane) |
| amatteiSW  | 192.168.56.111   | K3s agent (worker)         |

Le token de jointure est transmis du serveur vers l'agent via le
dossier synchronisé `/vagrant` (chaque VM monte le dossier `p1/` de
l'hôte) — voir `scripts/setup_server.sh` et `scripts/setup_worker.sh`.

**Vérifications :**

```bash
vagrant ssh amatteiS
ip a show <interface>      # vérifie l'IP 192.168.56.110
kubectl get nodes -o wide  # les 2 nœuds doivent apparaître Ready
```

---

## Partie 2 — K3s + 3 applications + Ingress

```bash
cd p2
vagrant up
```

Une seule VM (`amatteiS`, 192.168.56.110) est créée avec K3s en mode
serveur. Le script de provisioning déploie ensuite 3 applications
(`p2/confs/app1.yaml`, `app2.yaml`, `app3.yaml`) et un `Ingress`
(`p2/confs/ingress.yaml`) routé sur le header `Host` via Traefik
(inclus par défaut dans K3s) :

- `Host: app1.com` → **app1** (1 réplique)
- `Host: app2.com` → **app2** (3 répliques)
- tout le reste     → **app3** (backend par défaut)

**Vérifications :**

```bash
vagrant ssh amatteiS
kubectl get all
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110               # -> app3 par défaut
```

---

## Partie 3 — K3d + Argo CD

Contrairement aux parties précédentes, **pas de Vagrant** ici : tout se
passe sur une VM déjà existante (ex. relancez `vagrant up` dans `p2/`
en repartant d'une machine propre, ou toute VM Debian de votre choix).

### 1. Installer les outils

```bash
cd p3
sudo scripts/install.sh
```

Installe Docker, kubectl, K3d et le CLI Argo CD (idempotent).

### 2. Dépôt GitHub public

Le projet est poussé sur : `git@github.com:DouiriMariah/IOT_new.git`
(dépôt public).

⚠️ Le nom du dépôt (`IOT_new`) ne contient pas de login de membre du
groupe, alors que la grille de correction officielle le vérifie
explicitement ("Check that the login of someone of the group was put
in the name of the Github repository"). C'est un choix assumé — pensez
à renommer le dépôt avant la soutenance si vous voulez lever ce risque.

`p3/confs/application.yaml` pointe déjà sur ce dépôt
(`https://github.com/DouiriMariah/IOT_new.git`, chemin `p3/manifests`).

### 3. Créer le cluster K3d + installer Argo CD

```bash
scripts/setup.sh
```

Ce script :
- crée le cluster K3d (`confs/k3d-config.yaml`, expose le port 8888) ;
- crée les namespaces `argocd` et `dev` ;
- installe Argo CD ;
- applique l'`Application` Argo CD qui synchronise `p3/manifests/`
  (déploiement de `wil42/playground:v1`, port 8888) vers le namespace
  `dev` ;
- affiche le mot de passe admin initial d'Argo CD.

**Vérifications :**

```bash
kubectl get ns
kubectl get pods -n dev
curl http://localhost:8888/
# {"status":"ok", "message":"v1"}
```

UI Argo CD : `kubectl -n argocd port-forward svc/argocd-server 8080:443`
puis ouvrez `https://localhost:8080` (login `admin` / mot de passe
affiché par `setup.sh`).

### 4. Changer de version (v1 → v2)

```bash
sed -i 's/playground:v1/playground:v2/' p3/manifests/deployment.yaml
git add -A && git commit -m "bump to v2" && git push
```

Argo CD (sync automatique) redéploie tout seul. Vérifiez :

```bash
curl http://localhost:8888/
# {"status":"ok", "message":"v2"}
```

---

## À réviser avant la soutenance

D'après la grille de correction (`ng_inception-of-things.pdf`), il faut
être capable d'expliquer simplement :
- le fonctionnement de base de **K3s** (control-plane / agent, flannel, Traefik) ;
- le fonctionnement de base de **Vagrant** (Vagrantfile, provisioning, réseau privé) ;
- le fonctionnement de base de **K3d** (K3s dans des conteneurs Docker) ;
- ce qu'est l'**intégration continue / Argo CD** (GitOps : Git comme
  source de vérité, sync automatique) ;
- la différence entre un **namespace** et un **pod** ;
- comment fonctionne l'**Ingress** de la partie 2 (commande volontairement
  non fournie par le sujet).
