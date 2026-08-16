# Préparation de la VM hôte

Ce projet doit tourner dans une VM (elle héberge elle-même les VM K3s
de p1/p2 via Vagrant). Toutes les commandes ci-dessous s'exécutent
**sur la machine hôte physique**, VM éteinte, sauf mention contraire.

## 1. Provider Vagrant utilisé : libvirt/QEMU (émulation logicielle)

p1 et p2 utilisent le provider `libvirt` avec `driver = "qemu"`
(émulation logicielle pure, sans accélération matérielle). C'est un
choix délibéré : sur un hôte déjà virtualisé, toute virtualisation
**matérielle imbriquée** (VirtualBox nested-hw-virt, KVM) s'est révélée
instable ici (jusqu'au plantage complet de la VM hôte). L'émulation
logicielle est plus lente mais fiable.

**Conséquence pratique : pas besoin d'activer la virtualisation
imbriquée sur l'hôte.** Seuls la RAM et le disque comptent.

## 2. Éteindre la VM proprement

Depuis un terminal dans la VM :

```bash
sudo poweroff
```

## 3. Allouer assez de RAM et de CPU

Sur l'hôte (VM éteinte) :

```bash
VBoxManage list vms                          # repérer le nom exact de la VM
VBoxManage modifyvm "<NOM_VM>" --memory 8192  # 8 Go recommandé (6 Go mini)
VBoxManage modifyvm "<NOM_VM>" --cpus 4       # 4 CPU recommandé (2 mini)
```

Chaque VM K3s (p1 : 2 VM, p2 : 1 VM) est configurée avec 2048 Mo de
RAM dans les Vagrantfile — l'émulation logicielle laisse moins de
marge à K3s qu'une VM accélérée, d'où cette allocation plus généreuse
que le minimum suggéré par le sujet (512-1024 Mo).

## 4. Agrandir le disque virtuel (.vdi)

Sur l'hôte :

```bash
VBoxManage list hdds                              # repérer "Location:" du .vdi de la VM
VBoxManage modifymedium disk "/chemin/exact/vers/le/disque.vdi" --resize 40960
```

`40960` = taille cible en **Mo** (ici 40 Go). Ne fonctionne que sur un
disque au format VDI en allocation dynamique.

## 5. Étendre la partition et le système de fichiers (dans la VM)

Une fois la VM redémarrée avec le disque agrandi, la partition et le
système de fichiers ne grandissent pas automatiquement. Layout GPT
type :

```
/dev/sda1  bios_grub
/dev/sda2  EFI System Partition (/boot/efi)
/dev/sda3  ext4, racine (/)          <- partition à étendre
```

```bash
sudo apt-get install -y cloud-guest-utils   # fournit growpart
sudo growpart /dev/sda 3
sudo resize2fs /dev/sda3
df -h /
```

## 6. Installer les outils (dans la VM)

```bash
# Vagrant
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y vagrant

# libvirt / QEMU + plugin Vagrant
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst libvirt-dev build-essential pkg-config ruby-dev
sudo usermod -aG libvirt,kvm "$USER"
sudo systemctl enable --now libvirtd
vagrant plugin install vagrant-libvirt
```

Après le `usermod`, une nouvelle session (reconnexion) est nécessaire
pour que l'appartenance aux groupes `libvirt`/`kvm` prenne effet — ou
utilisez `sg libvirt -c "<commande>"` en attendant.

## 7. Vérifier que tout est prêt

```bash
free -h                              # RAM disponible (8 Go visés)
df -h /                              # espace disque disponible (40 Go visés)
vagrant plugin list | grep libvirt   # plugin installé
virsh -c qemu:///system list --all   # accès libvirt fonctionnel
```
