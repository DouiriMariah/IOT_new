# Soutenance — Théorie et explications

Ce que l'évaluateur attend que vous sachiez **expliquer**, pas juste
montrer. Pour les commandes, voir
[SOUTENANCE-COMMANDES.md](SOUTENANCE-COMMANDES.md).

---

## K3s

Distribution légère de Kubernetes.

- Un nœud **server** (control-plane) héberge l'API Kubernetes,
  **etcd** (base de données qui stocke l'état du cluster) et
  l'ordonnanceur (qui décide où placer les pods).
- Un nœud **agent** (worker) exécute les conteneurs via
  **containerd**, sous les ordres du server.
- Les deux communiquent sur le port **6443**.
- Le réseau entre pods est géré par **flannel**.
- Le trafic entrant (Ingress) est géré par **Traefik** (voir plus
  bas) — les deux sont installés par défaut avec K3s.

**Output de `kubectl get nodes -o wide` à savoir commenter** : le rôle
(`control-plane` vs vide = worker), le statut `Ready`, l'IP interne,
la version, l'OS, le runtime de conteneurs (`containerd`).

---

## Vagrant

Décrit une ou plusieurs VM de façon **déclarative** dans un
`Vagrantfile` (box de base, réseau, ressources) et automatise leur
cycle de vie :
- `vagrant up` : crée/démarre les VM et lance les **provisioners**
  (les scripts qui installent et configurent K3s).
- `vagrant ssh <nom>` : s'y connecte (sans mot de passe — clé SSH
  générée automatiquement, voir `config.ssh.insert_key`).
- `vagrant halt` / `vagrant destroy` : arrête / supprime la VM.

Un **provider** (VirtualBox, libvirt/QEMU...) est le moteur de
virtualisation réel derrière Vagrant — celui utilisé ici est
libvirt/QEMU, en émulation logicielle (voir
[HOST-SETUP.md](HOST-SETUP.md) pour le pourquoi).

**Deux VM (p1) doivent se transmettre une information** : le token
K3s qui permet au worker de rejoindre le server. Comme il n'y a pas de
dossier partagé automatique avec ce provider, ça passe par le canal
SSH que Vagrant gère déjà : un `trigger` récupère le token depuis
`amatteiS` juste après son démarrage, et un provisioner `file` le
dépose sur `amatteiSW` avant qu'elle ne s'installe.

---

## K3d

Fait tourner K3s **dans des conteneurs Docker** plutôt que dans de
vraies VM : chaque « nœud » du cluster est un simple conteneur Docker.
Plus léger et plus rapide à démarrer qu'une VM complète (pas de boot
d'OS, pas d'émulation matérielle), mais demande Docker en
fonctionnement sur la machine hôte.

**Différence K3s / K3d à savoir expliquer** : K3s est la distribution
Kubernetes elle-même ; K3d est un outil qui fait tourner cette même
distribution K3s à l'intérieur de conteneurs Docker au lieu de VM.

---

## Intégration continue / Argo CD (GitOps)

Argo CD est un outil de **déploiement continu (CD)** basé sur le
principe **GitOps** :

- Le **dépôt Git est la source de vérité** — l'état désiré du cluster
  est décrit par des fichiers YAML versionnés dans Git, pas appliqué à
  la main avec `kubectl apply`.
- Argo CD **compare en permanence** l'état réel du cluster à l'état
  décrit dans Git.
- Dès qu'une différence apparaît (ex : on change le tag d'image et on
  pousse le commit), Argo CD **resynchronise automatiquement**
  (`syncPolicy.automated`) — c'est ce qui permet de mettre à jour
  l'application juste en poussant sur Git, sans toucher au cluster.

**États à savoir lire** : `SYNC STATUS` (Synced = cluster conforme à
Git) et `HEALTH STATUS` (Healthy = les ressources tournent
correctement) sont deux notions différentes.

---

## Namespace vs Pod

- **Namespace** : espace de nommage logique qui partitionne les
  ressources d'un même cluster (`argocd`, `dev`, `kube-system`...) —
  utile pour isoler des projets ou environnements.
- **Pod** : plus petite unité déployable de Kubernetes — un ou
  plusieurs conteneurs qui partagent réseau et stockage. C'est
  l'instance qui fait vraiment tourner l'application.

Un namespace peut contenir des dizaines de pods ; un pod appartient à
un seul namespace.

---

## Ingress et Traefik

Une ressource **Ingress** décrit des **règles de routage HTTP(S)**
vers des `Service` internes (par nom de domaine et/ou chemin) — mais
ce n'est qu'un fichier de configuration, il ne route rien tout seul.

Il faut un **Ingress Controller** qui lit ces règles et applique
réellement le routage au trafic entrant : c'est **Traefik**, installé
**automatiquement par défaut avec K3s** (visible via les jobs
`helm-install-traefik*`). C'est pour ça qu'il n'apparaît dans aucun de
vos fichiers `confs/` alors qu'il fait tout le travail.

**Pourquoi une règle sans `host` dans `ingress.yaml` ?** Le champ
standard `spec.defaultBackend` (censé gérer « tout le reste ») n'est
pas fiable avec le Traefik intégré à K3s. On utilise à la place une
règle de routage **sans `host`**, qui matche n'importe quelle requête
et sert de route par défaut — avec une priorité plus basse que les
règles `app1.com`/`app2.com`, qui restent donc prioritaires.

---

## Pourquoi le provider est libvirt/QEMU et pas VirtualBox

Cet environnement de développement est lui-même une VM. Toute
virtualisation **matérielle imbriquée** (VirtualBox avec
nested-hw-virt, ou KVM) s'y est révélée instable, jusqu'au plantage
complet de la VM hôte. L'émulation **logicielle pure** (QEMU/TCG) est
plus lente mais fiable — c'est un compromis technique assumé, pas une
exigence du sujet (qui autorise explicitement « any provider used in
Vagrant »).

Détail technique si demandé : `vagrant-libvirt` amène les machines en
**parallèle** par défaut, ce qui casserait le transfert du token
K3s entre les deux VM de p1 ; le Vagrantfile force donc un
`ENV["VAGRANT_NO_PARALLEL"]` pour garantir un démarrage séquentiel
quelle que soit la commande tapée.
