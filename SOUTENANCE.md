# Guide de soutenance — Inception-of-Things

Ce document vous sert de fil conducteur pendant la soutenance : quoi
taper, dans quel ordre, ce que vous devez voir à l'écran, et ce qu'il
faut savoir expliquer à l'évaluateur à chaque étape.

> 💡 Avant de commencer : ouvrez un terminal dans `~/Desktop/IOT_new`
> (ou l'emplacement de votre dépôt cloné) et gardez ce fichier ouvert
> à côté.

---

## 0. Avant que l'évaluateur arrive

- [ ] Vérifiez l'espace disque : `df -h /` → il faut plusieurs Go
      libres (K3d/Docker et les VM Vagrant en consomment beaucoup).
      Si c'est juste, voir la section [Dépannage](#dépannage).
- [ ] Vérifiez la RAM disponible : `free -h`.
- [ ] Repérez le nom exact de votre login dans les noms de machines :
      `amatteiS` (serveur) / `amatteiSW` (worker).
- [ ] Relisez la partie [Ce qu'il faut savoir expliquer](#ce-quil-faut-savoir-expliquer)
      une dernière fois.

---

## Partie 1 — K3s + Vagrant (2 VMs)

### Lancer

```bash
cd p1
vagrant up
```

⏱️ Sous cet environnement (émulation logicielle QEMU/TCG, voir
[HOST-SETUP.md](HOST-SETUP.md)), ça prend **10 à 15 minutes**. Lancez
cette commande **en tout premier**, avant même que l'évaluateur
s'installe, pour ne pas attendre à vide devant lui. Si vous avez déjà
un cluster qui tourne d'une session précédente, `vagrant up` est
idempotent et ne fera que vérifier l'état (quelques secondes).

### Ce que l'évaluateur va vous demander de montrer

**1. Le Vagrantfile et sa cohérence avec le sujet**

```bash
cat Vagrantfile
```

Pointez : les 2 machines (`amatteiS`/`amatteiSW`), leurs IP fixes
(`192.168.56.110`/`.111`), la box Debian utilisée.

**2. Connexion SSH sans mot de passe sur les deux machines**

```bash
vagrant ssh amatteiS   # puis Ctrl+D pour sortir
vagrant ssh amatteiSW  # puis Ctrl+D pour sortir
```

Aucun mot de passe demandé = clé SSH générée automatiquement par
Vagrant (voir `config.ssh.insert_key = true` dans le Vagrantfile).

**3. L'interface réseau et l'IP fixe (depuis chaque VM)**

```bash
vagrant ssh amatteiS -c "hostname && ip a show eth1"
vagrant ssh amatteiSW -c "hostname && ip a show eth1"
```

Vous devez voir `amatteiS`/`192.168.56.110` et
`amatteiSW`/`192.168.56.111`.

**4. Le cluster K3s à 2 nœuds**

```bash
vagrant ssh amatteiS -c "sudo k3s kubectl get nodes -o wide"
```

Résultat attendu (les deux `STATUS` à `Ready`) :

```
NAME        STATUS   ROLES           AGE   VERSION        INTERNAL-IP
amatteis    Ready    control-plane   ...   v1.36.3+k3s1   192.168.56.110
amatteisw   Ready    <none>          ...   v1.36.3+k3s1   192.168.56.111
```

> ⚠️ **Le sujet précise que vous devez expliquer cet output** — voir
> la section dédiée plus bas.

---

## Partie 2 — K3s + 3 applications + Ingress

### Lancer

```bash
cd ../p2
vagrant up
```

⏱️ Une seule VM cette fois, comptez **8-12 minutes**.

### Ce que l'évaluateur va vous demander de montrer

**1. Les mêmes vérifications que pour p1** (Vagrantfile, SSH, hostname,
IP fixe `192.168.56.110`, `k3s kubectl get nodes -o wide`).

**2. Toutes les ressources créées**

```bash
vagrant ssh amatteiS -c "sudo k3s kubectl get all"
```

Vérifiez que vous voyez : `deployment.apps/app1` (1 réplica),
`deployment.apps/app2` (**3 réplicas**), `deployment.apps/app3` (1
réplica), et leurs services.

**3. Le routage par Host header (le vrai test du sujet)**

```bash
vagrant ssh amatteiS -c 'curl -s -H "Host: app1.com" http://localhost'
vagrant ssh amatteiS -c 'curl -s -H "Host: app2.com" http://localhost'
vagrant ssh amatteiS -c 'curl -s http://localhost'          # sans Host -> app3
```

Résultat attendu : trois réponses HTML différentes
(*"Hello from app1."* / *"Hello from app2."* / *"Hello from app3
(default application)."*).

Vous pouvez aussi le faire **depuis votre navigateur hôte** si le
réseau `192.168.56.0/24` est accessible depuis l'extérieur de la VM :
ouvrez `http://192.168.56.110` avec une extension qui force le header
`Host`, ou utilisez `curl` depuis le terminal hôte.

**4. L'Ingress lui-même (volontairement pas montré dans le sujet —
préparez-le)**

```bash
vagrant ssh amatteiS -c "sudo k3s kubectl get ingress"
vagrant ssh amatteiS -c "sudo k3s kubectl describe ingress apps-ingress"
```

Expliquez les 3 règles : `app1.com` → service `app1`, `app2.com` →
service `app2`, et une règle **sans `host`** qui sert de route par
défaut vers `app3` (voir l'encart [Pourquoi une règle sans host ?](#pourquoi-une-règle-sans-host)).

---

## Partie 3 — K3d + Argo CD

### Lancer (si le cluster n'existe pas déjà)

```bash
cd ../p3
docker ps                        # Docker doit tourner
k3d cluster list                 # si "iot-cluster" n'apparaît pas :
bash scripts/setup.sh            # crée le cluster + installe Argo CD
```

⏱️ Nettement plus rapide que p1/p2 (Docker, pas de VM imbriquée) :
**2-4 minutes**. Notez le mot de passe admin Argo CD affiché à la fin.

Si le cluster tourne déjà (relancé plus tôt) :

```bash
k3d cluster list
kubectl get pods -n argocd
```

### Ce que l'évaluateur va vous demander de montrer

**1. La différence K3s / K3d** (voir section dédiée plus bas).

**2. Les deux namespaces et le pod dans `dev`**

```bash
kubectl get ns
kubectl get pods -n dev
```

**3. Argo CD dans le navigateur**

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Ouvrez `https://localhost:8080` (certificat auto-signé, acceptez
l'avertissement). Login `admin`, mot de passe :

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Montrez l'application `playground` : **Synced** / **Healthy**, et le
schéma de synchronisation (Application → Deployment → Pod).

**4. L'application accessible et sa version actuelle**

```bash
curl http://localhost:8888/
```

**5. Le changement de version en direct (LE moment important de p3)**

```bash
cd ~/Desktop/IOT_new
sed -i 's/playground:v1/playground:v2/' p3/manifests/deployment.yaml
# ou l'inverse si vous êtes déjà en v2 : s/playground:v2/playground:v1/
git add p3/manifests/deployment.yaml
git commit -m "bump version"
git push
```

Argo CD resynchronise automatiquement au bout de quelques minutes
(polling périodique). Pour ne pas attendre devant l'évaluateur, forcez
un refresh immédiat :

```bash
kubectl -n argocd annotate application playground \
  argocd.argoproj.io/refresh=hard --overwrite
```

Puis vérifiez :

```bash
kubectl get pods -n dev            # un nouveau pod doit apparaître
curl http://localhost:8888/        # le "message" doit avoir changé
```

Montrez aussi le changement dans l'interface web Argo CD (historique
de synchronisation, image utilisée).

---

## Ce qu'il faut savoir expliquer

Le sujet et la grille de correction insistent : **l'évaluateur ne se
contente pas de voir que ça marche, il demande d'expliquer**.
Préparez des réponses simples (2-3 phrases) à chacun de ces points.

### K3s (basique)

K3s est une distribution légère de Kubernetes. Un nœud **server**
(control-plane) héberge l'API Kubernetes, `etcd` (la base d'état du
cluster) et l'ordonnanceur ; un nœud **agent** (worker) ne fait
qu'exécuter les conteneurs (via `containerd`) et reçoit ses ordres du
server. Les deux communiquent sur le port `6443`. Le réseau entre pods
est géré par **flannel**, et l'**Ingress** entrant par **Traefik**
(les deux sont installés par défaut avec K3s).

### Vagrant (basique)

Vagrant décrit une ou plusieurs VM de façon déclarative dans un
`Vagrantfile` (box de base, réseau, ressources) et automatise leur
cycle de vie : `vagrant up` crée/démarre, `vagrant provision` exécute
les scripts de configuration (installation de K3s ici), `vagrant ssh`
s'y connecte, `vagrant destroy` les supprime. Un **provider**
(VirtualBox, libvirt/QEMU...) est le moteur de virtualisation réel
derrière Vagrant.

### K3d (basique)

K3d fait tourner K3s **dans des conteneurs Docker** plutôt que dans de
vraies VM : chaque "nœud" du cluster est un simple conteneur Docker.
C'est beaucoup plus léger et rapide à démarrer qu'une VM complète,
mais ça demande Docker en fonctionnement sur la machine hôte.

### Intégration continue / Argo CD (GitOps)

Argo CD est un outil de **déploiement continu (CD)** basé sur le
principe **GitOps** : le dépôt Git est la **source de vérité** — l'état
désiré du cluster est décrit par des fichiers YAML versionnés dans
Git, pas par des commandes `kubectl apply` manuelles. Argo CD compare
en permanence l'état réel du cluster à l'état décrit dans Git, et
resynchronise automatiquement (`syncPolicy.automated`) dès qu'une
différence apparaît — par exemple quand on change un tag d'image et
qu'on pousse le commit. C'est ce qui permet de mettre à jour
l'application juste en poussant sur Git, sans toucher au cluster
directement.

### Namespace vs Pod

Un **namespace** est un espace de nommage logique qui partitionne les
ressources d'un même cluster (`argocd`, `dev`, `kube-system`, ...) —
utile pour isoler des projets ou des environnements. Un **pod** est la
plus petite unité déployable dans Kubernetes : une ou plusieurs
conteneurs qui partagent le même réseau et le même stockage,
concrètement l'instance qui fait vraiment tourner votre application.
Un namespace peut contenir des dizaines de pods ; un pod appartient à
un seul namespace.

### Ingress

Une ressource `Ingress` décrit des règles de routage HTTP(S) vers des
`Service` internes du cluster (par nom de domaine et/ou chemin), mais
elle ne fait rien seule : il faut un **Ingress Controller** (ici
**Traefik**, fourni par K3s) qui lit ces règles et route réellement le
trafic entrant.

### Pourquoi une règle sans `host` ?

Le champ standard `spec.defaultBackend` d'un Ingress (censé gérer
« tout le reste ») n'est pas fiable avec le Traefik intégré à K3s. On
utilise à la place une règle de routage **sans `host`**, qui matche
n'importe quelle requête et sert donc de route par défaut — mais avec
une priorité plus basse que les règles `app1.com`/`app2.com`, qui sont
donc toujours prioritaires quand elles correspondent.

---

## Dépannage

### `df -h /` montre moins de 3 Go libres

K3d/Docker et les VM Vagrant remplissent vite le disque. Nettoyez les
VM déjà validées que vous n'utilisez pas en ce moment :

```bash
cd p1 && vagrant halt   # ou: vagrant destroy -f si vous voulez tout repartir de zéro
cd ../p2 && vagrant halt
docker system prune -f
```

### Un pod K3d reste `Pending` avec un événement `disk-pressure`

Le kubelet du nœud K3d a détecté un disque plein et pose un *taint*
qui bloque le scheduling. Après avoir libéré de l'espace :

```bash
docker restart k3d-iot-cluster-server-0
```

### `vagrant up` semble figé sur une VM

Sous QEMU/TCG (émulation logicielle), le CPU du process peut sembler
actif sans avancer. Vérifiez sur deux mesures espacées de 20-30s si le
temps CPU progresse :

```bash
PID=$(ps aux | grep "guest=<nom_vm>" | grep -v grep | awk '{print $2}')
ps -o pid,time -p "$PID"; sleep 25; ps -o pid,time -p "$PID"
```

Si le temps CPU n'a **pas du tout** bougé, la VM est probablement
bloquée par manque de RAM :

```bash
free -h   # si swap presque plein et RAM dispo proche de 0
```

Dans ce cas, arrêtez la VM concernée et relancez avec plus de RAM
disponible sur l'hôte (voir [HOST-SETUP.md](HOST-SETUP.md)).

### `vagrant up` échoue avec une erreur réseau ("collides with...")

Un réseau `libvirt` résiduel entre en collision avec le réseau attendu
par Vagrant :

```bash
virsh -c qemu:///system net-list --all
virsh -c qemu:///system net-destroy <nom>
virsh -c qemu:///system net-undefine <nom>
```

---

## Récapitulatif express (aide-mémoire dernière minute)

```bash
# p1
cd p1 && vagrant up
vagrant ssh amatteiS -c "sudo k3s kubectl get nodes -o wide"

# p2
cd ../p2 && vagrant up
vagrant ssh amatteiS -c 'curl -s -H "Host: app1.com" http://localhost'

# p3
cd ../p3
kubectl get pods -n dev
curl http://localhost:8888/
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```
